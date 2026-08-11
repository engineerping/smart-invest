# Smart Invest — 实际部署过程记录

> 记录日期：2026-08-11
> 环境：AWS EC2（新加坡 ap-southeast-1）+ K3S 单节点
> 镜像构建机：Ubuntu 22.04（华硕内网 x86_64，IP 192.168.31.192）

---

## 架构总览

```
Mac (arm64, 开发 + Terraform)  →  Terraform 管理 AWS
Ubuntu (x86_64, 内网)          →  Docker 构建镜像
AWS EC2 (x86_64, t3.medium)     →  K3S 运行所有服务 + Postgres + RabbitMQ
AWS CloudFront + S3             →  前端 CDN
```

---

## 第一步：Terraform 管理 EC2

### 1.1 项目结构

```
infrastructure/terraform/
├── live/prod/           # 环境实例（只有 prod 一个环境）
│   ├── main.tf          # Provider + 远程 backend
│   ├── root.tf          # 根模块（调用 modules）
│   ├── variables.tf     # 变量声明
│   ├── outputs.tf       # 输出（EC2 IP、CloudFront 域名）
│   ├── terraform.tfvars # 实际配置值
│   └── backend.tf       # S3 + DynamoDB 状态后端
└── modules/             # 可复用模块
    ├── networking/      # VPC、子网、安全组
    ├── compute/         # EC2 实例 + SSH Key
    ├── iam/             # IAM Role + CloudWatch Agent 权限
    └── cdn/             # S3 + CloudFront + WAF
```

### 1.2 初始化

```bash
cd infrastructure/terraform/live/prod

# 复制变量文件
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars，填入你的 AWS 账户信息

# 初始化（会自动创建 S3 bucket + DynamoDB 表用于远程状态）
terraform init
```

### 1.3 导入已有资源 + 调整规格

实际环境中 EC2 是早期手动在 AWS Console 创建的，需要先导入到 Terraform 状态中，之后才能由 Terraform 统一管理。

```bash
# 查看现有 EC2
aws ec2 describe-instances \
  --query "Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# 导入到 Terraform 状态（只做一次）
terraform import aws_instance.k3s_server i-024897e5a18af2a8c

# 修改 terraform.tfvars 中的规格：
# instance_type   = "t3.medium"   # 2vCPU, 4GB RAM
# ebs_volume_size = 30            # 30GB 磁盘

# 预览变更
terraform plan

# 执行（改规格会重启 EC2，约 1-2 分钟）
terraform apply
```

### 1.4 terraform.tfvars 关键配置

```hcl
# AWS 区域
aws_region = "ap-southeast-1"

# EC2 规格
instance_type   = "t3.medium"   # 2vCPU, 4GB RAM
ebs_volume_size = 30            # 30GB 磁盘（GP3）

# 域名（前端通过 CloudFront 对外）
domain_name = "d2hoqnqufe8qq0.cloudfront.net"

# SSH Key（AWS Console 先创建的 Key Pair 名）
key_name = "smart-invest-ec2-keypair"
```

### 1.5 最终输出

```
ec2_public_ip         = 46.137.250.243
ec2_ssh_command       = ssh ec2-user@46.137.250.243
cloudfront_domain     = d2hoqnqufe8qq0.cloudfront.net
s3_bucket_name        = smart-invest-frontend-service-prod-bucket-name
```

### 1.6 遇到的坑

| 问题 | 原因 | 解决 |
|------|------|------|
| `terraform init` 报 Permission Denied | 旧 S3 bucket 名被占用 | 改名后重建 |
| `terraform import` 失败 | 资源路径在 module 里，语法不同 | 用 `module.compute.aws_instance.k3s_server` 格式 |
| 安全组改端口后 K3S 连不上 | 6443 端口没开 | 在安全组加 6443 入站规则 |

---

## 第二步：安装 K3S

SSH 到 EC2 执行：

```bash
# 安装 K3S（一条命令，自动装好 containerd + kubectl + traefik + coredns）
curl -sfL https://get.k3s.io | sh -

# 验证
sudo kubectl get nodes
# NAME                   STATUS   ROLES           AGE   VERSION
# ip-172-31-35-177...    Ready    control-plane   10s   v1.36.3+k3s1

# 查看 kubeconfig（如果需要从本地 kubectl 连）
sudo cat /etc/rancher/k3s/k3s.yaml
```

实际环境信息：

| 项目 | 值 |
|------|-----|
| OS | Amazon Linux 2023 |
| 架构 | x86_64 (t3.medium) |
| K3S 版本 | v1.36.3+k3s1 |
| Runtime | containerd 2.3.2 |
| 内存 | 3.7 GB 可用 |
| 磁盘 | 30GB（使用 6.1GB） |
| Ingress | Traefik（K3S 自带） |
| Storage | local-path-provisioner（K3S 自带） |

K3S 自带的核心组件：
- **Traefik** — Ingress Controller，负责 HTTP 路由
- **CoreDNS** — 集群内 DNS（Service 名 → IP）
- **local-path-provisioner** — 动态创建 PVC/PV（自动在节点磁盘创建目录）
- **containerd** — 容器运行时（替代 Docker，k3s ctr 管理镜像）

---

## 第三步：Docker 镜像构建（核心环节）

### 3.1 关键问题：架构不匹配

```
Mac (Apple Silicon, arm64) ──×──→ EC2 (t3.medium, x86_64)
```

Docker 镜像和 CPU 架构强绑定。arm64 镜像在 x86_64 机器上运行会报：
```
exec format error
```

**解决方案：Ubuntu 内网构建机**

```
Mac (arm64)                 →  Terraform + git push
Ubuntu (x86_64, 192.168.31.192)  →  Docker build
Ubuntu → SCP → EC2          →  k3s ctr image import
```

| 构建机 | 架构 | 内存 | Docker | 用途 |
|--------|------|------|--------|------|
| Mac | arm64 | — | — | 写代码、编译 jar、rsync 到 Ubuntu |
| Ubuntu | x86_64 | 7.7 GB | 29.7.1 | 打 Docker 镜像 |
| EC2 | x86_64 | 3.7 GB | — | K3S 运行镜像 |

### 3.2 镜像清单

| 镜像 | Dockerfile 路径 | 端口 | 大小 |
|------|----------------|------|------|
| `smart-invest-user-service:1.0.0` | `backend/user-service/Dockerfile` | 8081 | 135MB |
| `smart-invest-fund-service:1.0.0` | `backend/fund-service/Dockerfile` | 8082 | 133MB |
| `smart-invest-order-service:1.0.0` | `backend/order-service/Dockerfile` | 8083 | 133MB |
| `smart-invest-notification-worker:1.0.0` | `backend/notification-worker/Dockerfile` | 8084 | 133MB |
| `smart-invest-api-gateway:1.0.0` | `backend/api-gateway/Dockerfile` | 8080 | 109MB |
| `smart-invest-frontend:1.0.0` | `frontend/Dockerfile` | 80 | 21MB |

**基础镜像：** `eclipse-temurin:21-jre-alpine`（5 个 Java 服务）+ `nginx:1.27-alpine`（前端）

### 3.3 构建流程（实际执行的步骤）

#### Step 1: 在 Mac 上编译 jar

```bash
# 本地 Maven 编译（arm64 原生，快）
cd backend
mvn -q -pl common,user-service,fund-service,order-service,notification-worker,api-gateway \
  -am package -DskipTests

# 前端构建
cd frontend && npm run build
```

#### Step 2: 同步代码和 jar 到 Ubuntu

```bash
# 首次：全量 rsync（跳过大型不必要目录）
rsync -avz \
  --exclude 'node_modules' --exclude 'target' --exclude 'dist' \
  --exclude '.terraform' --exclude '.git' \
  ~/coding/smart-invest/ george@192.168.31.192:~/coding/smart-invest/

# 之后每次变更只同步有改动的文件，rsync 增量同步很快

# jar 文件较大（~300MB 总量），用 scp
scp backend/*/target/*-1.0.0-SNAPSHOT.jar george@192.168.31.192:~/coding/smart-invest/
scp -r frontend/dist george@192.168.31.192:~/coding/smart-invest/frontend/
```

#### Step 3: 在 Ubuntu 上打 Docker 镜像

> **重要：** 不能用 Dockerfile 里的多阶段构建（Maven from source），因为：
> 1. 父 pom.xml 声明了 6 个子模块，单个 Dockerfile 只拷了自己目录，Maven 找不到其他模块就报错
> 2. 在 Docker 里重新下载 Maven 依赖 + 编译太慢（每个服务 ~5 分钟）
>
> **策略：** 用简单 Dockerfile（只拷预编译的 jar），Mac 上 mvn 编译完直接传过去。

```bash
#!/bin/bash
# 在 Ubuntu 上执行（SSH 过去）

cd ~/coding/smart-invest

# 为每个 Java 服务创建精简 Dockerfile
for svc in user-service fund-service order-service notification-worker api-gateway; do
  port=$(grep -oP 'port: \K\d+' infrastructure/helm/charts/$svc/values.yaml | head -1)

  sudo docker build --platform linux/amd64 \
    -f - \
    -t gongchengship/smart-invest-$svc:1.0.0 \
    backend/$svc/ << DOCKER
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/${svc}-1.0.0-SNAPSHOT.jar app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE ${port}
ENTRYPOINT ["java", "-jar", "app.jar"]
DOCKER
done

# 前端（用项目的多阶段 Dockerfile）
sudo docker build --platform linux/amd64 \
  -f frontend/Dockerfile \
  -t gongchengship/smart-invest-frontend:1.0.0 \
  frontend/
```

> **为什么不推 Docker Hub？**
>
> 华硕网络访问 Docker Hub 受限（`docker push` 超时 `i/o timeout`）。
> 虽然配置了 `dockerproxy.net` 镜像源可以 pull，但 push 必须连到 Docker Hub 服务器，网络不通。
>
> **替代方案：** `docker save → scp → k3s ctr image import`
> 这是纯内网传输，不经过外网，速度快（352MB tarball，内网 SCP ~30 秒）。

#### Step 4: 传输镜像到 EC2

```bash
# 1. 在 Ubuntu 上导出镜像为 tar
sudo docker save \
  gongchengship/smart-invest-user-service:1.0.0 \
  gongchengship/smart-invest-fund-service:1.0.0 \
  gongchengship/smart-invest-order-service:1.0.0 \
  gongchengship/smart-invest-notification-worker:1.0.0 \
  gongchengship/smart-invest-api-gateway:1.0.0 \
  gongchengship/smart-invest-frontend:1.0.0 \
  -o /tmp/smart-invest-images.tar
# 大小：352MB

# 2. SCP 到 EC2
# 先在 Mac 上把 EC2 SSH Key 拷到 Ubuntu：
scp ~/.ssh/smart-invest-ec2-keypair.pem george@192.168.31.192:/tmp/

# 在 Ubuntu 上执行 SCP：
scp -i /tmp/smart-invest-ec2-keypair.pem \
  /tmp/smart-invest-images.tar \
  ec2-user@46.137.250.243:/tmp/

# 3. 在 EC2 上导入到 K3S 的 containerd
sudo k3s ctr image import /tmp/smart-invest-images.tar

# 4. 验证
sudo k3s ctr image ls | grep smart-invest
sudo crictl images | grep smart-invest
```

### 3.4 镜像导入后的状态

```
EC2 containerd 镜像列表（crictl images）：

gongchengship/smart-invest-user-service           1.0.0    135MB
gongchengship/smart-invest-fund-service           1.0.0    133MB
gongchengship/smart-invest-order-service          1.0.0    133MB
gongchengship/smart-invest-notification-worker    1.0.0    133MB
gongchengship/smart-invest-api-gateway            1.0.0    109MB
gongchengship/smart-invest-frontend               1.0.0    21MB
docker.io/library/rabbitmq                        3.13-management-alpine  (Helm 部署后自动拉)
docker.io/library/postgres                        16-alpine               (Helm 部署后自动拉)
```

> K3S 的 containerd 和 Docker 是两套独立存储。`sudo docker images` 看不到 K3S 的镜像，
> 需要用 `sudo k3s ctr image ls` 或 `sudo crictl images` 查看。

### 3.5 后续更新镜像流程

每次改代码后更新流程：

```bash
# 1. Mac：编译新 jar
cd backend && mvn -q -pl ... package -DskipTests
cd frontend && npm run build

# 2. Mac → Ubuntu：只传改动的 jar
scp backend/user-service/target/user-service-1.0.0-SNAPSHOT.jar \
  george@192.168.31.192:~/coding/smart-invest/backend/user-service/target/

# 3. Ubuntu：重建镜像（利用缓存，几秒完成）
ssh george@192.168.31.192
sudo docker build --platform linux/amd64 \
  -t gongchengship/smart-invest-user-service:1.0.0 backend/user-service/

# 4. Ubuntu：导出 + 传到 EC2
sudo docker save gongchengship/smart-invest-user-service:1.0.0 -o /tmp/update.tar
scp -i /tmp/smart-invest-ec2-keypair.pem /tmp/update.tar ec2-user@46.137.250.243:/tmp/

# 5. EC2：导入 + 重启 Pod
sudo k3s ctr image import /tmp/update.tar
sudo kubectl rollout restart deployment/user-service -n smart-invest
```

---

## 第四步：Helm 部署

### 4.1 Helm Chart 结构

```
infrastructure/helm/
├── charts/                    # 9 个子 Chart
│   ├── user-service/          # 微服务（Deployment + Service）
│   ├── fund-service/
│   ├── order-service/
│   ├── notification-worker/
│   ├── api-gateway/
│   ├── frontend/
│   ├── postgresql/            # StatefulSet + Headless Service + PVC
│   ├── rabbitmq/              # Deployment + PVC + Service
│   └── redis/                 # Deployment + PVC（默认禁用）
└── umbrella/                  # 聚合 Chart（一键部署全家桶）
    ├── Chart.yaml             # 依赖声明（9 个子 Chart）
    ├── values.yaml            # 统一配置（含全局 Secret）
    ├── values-prod.yaml       # 生产环境覆盖配置
    └── templates/
        ├── secret.yaml        # K8S Secret（DB 密码、JWT 密钥）
        ├── ingress.yaml       # Traefik Ingress 路由
        └── rabbitmq-ready-hook.yaml  # Helm Hook：部署前检查 RabbitMQ
```

### 4.2 部署前的重要配置修改

**原配置（华硕 K3S 环境）：**
- `SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-host:5432/smartinvest`
- `hostAliases` 把 `postgres-host` 映射到宿主机 `192.168.31.192`

**改为（EC2 + K3S 环境）：**
- `SPRING_DATASOURCE_URL: jdbc:postgresql://postgresql:5432/smartinvest`
- 删除所有 `hostAliases`（PostgreSQL 通过 K8S Service DNS 直接访问）

改动涉及 8 个文件（4 个 values.yaml + 4 个 deployment.yaml），详见 git diff。

### 4.3 数据备份（从旧 docker-compose Postgres 迁移）

```bash
# EC2 上执行
# 1. 启动旧 Postgres（如果已停止）
sudo docker start smart-invest-postgres-1
sleep 3

# 2. 导出数据
sudo docker exec smart-invest-postgres-1 pg_dump -U smartadmin smartinvest | \
  gzip > /tmp/db-backup-20260811.sql.gz

# 3. 停止旧 Postgres（释放 5432 端口）
sudo docker stop smart-invest-postgres-1

# 导出结果：49KB gzip，4801 行 SQL，15 张表
```

### 4.4 Helm 部署命令

```bash
cd infrastructure/helm/umbrella

# 1. 下载子 Chart 依赖
helm dependency update

# 2. 部署（含 PostgreSQL + RabbitMQ + 所有微服务）
helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --atomic --timeout 600s

# --upgrade --install: 不存在就创建，已存在就升级
# --atomic: 失败自动 rollback
# --timeout 600s: 10 分钟超时
```

### 4.5 数据恢复

```bash
# EC2 上执行
zcat /tmp/db-backup-20260811.sql.gz | \
  kubectl exec -i -n smart-invest postgresql-0 -- \
  psql -U smartadmin smartinvest
```

### 4.6 验证

```bash
# 看所有资源
kubectl get all -n smart-invest

# 看 PVC 是否都 Bound
kubectl get pvc -n smart-invest

# 看 Helm Release
helm list -n smart-invest

# 访问 API 健康检查
curl https://d2hoqnqufe8qq0.cloudfront.net/api/actuator/health
```

### 4.7 K8S 内服务发现

部署后各服务通过 DNS 互相发现：

| 服务 | 集群内 DNS |
|------|-----------|
| PostgreSQL | `postgresql.smart-invest.svc.cluster.local:5432` |
| RabbitMQ | `rabbitmq.smart-invest.svc.cluster.local:5672` |
| API Gateway | `api-gateway.smart-invest.svc.cluster.local:8080` |
| User Service | `user-service.smart-invest.svc.cluster.local:8081` |

Spring Cloud Gateway 在 API Gateway 里通过 `http://user-service:8081` 调用后端服务。

---

## 环境差异总结

| 环境 | 华硕 K3S（旧） | AWS EC2 + K3S（新） |
|------|---------------|-------------------|
| 架构 | x86_64（Intel NUC） | x86_64（t3.medium） |
| PostgreSQL | 宿主机 Docker 直接跑 | K3S StatefulSet + PVC |
| JDBC URL | `postgres-host`（宿主 IP） | `postgresql`（K8S Service） |
| hostAliases | 需要（跨 Docker/K8S 网络） | 不需要（都在 K3S 内） |
| 镜像来源 | Docker Hub pull | Ubuntu 构建 → scp → ctr import |
| 网络 | 内网，拉 Docker Hub 受限 | 海外 EC2，可直接拉 |
