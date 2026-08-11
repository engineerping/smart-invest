# Smart Invest — 基础设施（Infrastructure as Code + Helm Charts）

这个目录包含本项目的所有基础设施即代码（IaC）资源配置：

- 📁 **terraform/** — Terraform 代码（AWS 云资源：EC2、VPC、S3、CloudFront、WAF）
- 📁 **helm/** — Helm Charts（K3S 上部署微服务全家桶 + 有状态中间件）
- 📁 **aws-infra-reflect/** — 现网配置备份（`terraform import` 前的参照）
- 📁 **scripts/** — 运维脚本（部署、构建、监控等）

---

## 架构概览

### 单 EC2 + K3S 自托管架构（不依赖 AWS 托管服务）

```
用户浏览器
    │
    ▼
CloudFront CDN ─── WAF（Web 防火墙）
    │
    ├── /api/* ──→ EC2 (t3.medium, 4GB RAM, 20GB 磁盘)
    │               │
    │               ├── K3S (轻量 Kubernetes)
    │               │   ├── api-gateway (Spring Cloud Gateway)
    │               │   ├── user-service    (用户微服务)
    │               │   ├── fund-service    (基金微服务)
    │               │   ├── order-service   (订单微服务)
    │               │   ├── notification-worker (通知消费者)
    │               │   ├── frontend        (前端 SPA)
    │               │   │
    │               │   ├── 🗄️  postgresql-0  (StatefulSet + PVC → 替代 RDS)
    │               │   ├── 🐰 rabbitmq       (Deployment + PVC → 替代 Amazon MQ)
    │               │   └── 📦 redis          (Deployment + PVC → 替代 ElastiCache，可选)
    │               │
    │               └── Traefik Ingress (K3S 自带)
    │
    └── SPA 路由 → S3 (前端静态文件)
```

> **成本**: 所有有状态服务（数据库、消息队列、缓存）以 StatefulSet/Deployment + PVC 方式
> 跑在 K3S 上，利用 K3S 自带的 local-path-provisioner 持久化到 EC2 本地磁盘。
> **不需要购买 AWS RDS / ElastiCache / Amazon MQ，成本为零。**

---

## 目录结构

```
infrastructure/
├── terraform/                                    # Terraform IaC
│   ├── live/                                     # 「环境实例」目录
│   │   └── prod/                                 # 生产环境
│   │       ├── main.tf                           # Terraform + Provider 配置
│   │       ├── root.tf                           # 根模块（调用子模块）★ 入口
│   │       ├── variables.tf                      # 变量声明
│   │       ├── outputs.tf                        # 输出值（部署后打印的信息）
│   │       ├── terraform.tfvars.example          # 示例变量文件（Git 跟踪）
│   │       ├── terraform.tfvars                  # 真实变量文件（Git 忽略）
│   │       ├── backend.tf                        # 远程状态后端（S3+DynamoDB）
│   │       └── import.sh                         # 导入已有 AWS 资源的脚本
│   └── modules/                                  # 可复用 Terraform 模块
│       ├── networking/                           # VPC + 安全组
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── compute/                              # EC2 实例
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── iam/                                  # IAM 角色与权限
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── cdn/                                  # CloudFront + S3 + WAF
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── helm/                                         # Helm Charts
│   ├── charts/                                   # 各微服务子 Chart
│   │   ├── api-gateway/
│   │   ├── frontend/
│   │   ├── fund-service/
│   │   ├── notification-worker/
│   │   ├── order-service/
│   │   ├── user-service/
│   │   │   ├── Chart.yaml                        # Chart 身份文件
│   │   │   ├── values.yaml                       # 默认配置
│   │   │   └── templates/
│   │   │       ├── _helpers.tpl                  # 模板函数（命名、标签）
│   │   │       ├── deployment.yaml               # Deployment 定义
│   │   │       └── service.yaml                  # Service 定义
│   │   ├── rabbitmq/                             # RabbitMQ（Deployment + PVC）
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │       ├── _helpers.tpl
│   │   │       ├── deployment.yaml
│   │   │       ├── service.yaml
│   │   │       └── pvc.yaml                      # 持久化存储
│   │   ├── postgresql/                           # 🆕 PostgreSQL（StatefulSet + PVC 替代 RDS）
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │       ├── _helpers.tpl
│   │   │       ├── statefulset.yaml               # StatefulSet（不是 Deployment！）
│   │   │       └── service.yaml                   # Headless + ClusterIP 双 Service
│   │   └── redis/                                # 🆕 Redis（Deployment + PVC 替代 ElastiCache）
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── deployment.yaml
│   │           ├── service.yaml
│   │           └── pvc.yaml
│   └── umbrella/                                 # 聚合 Chart（一键部署全家桶）
│       ├── Chart.yaml                            # 聚合 Chart 身份 + 依赖声明
│       ├── Chart.lock                            # 依赖版本锁定文件
│       ├── values.yaml                           # 默认配置（所有子 Chart + 中间件）
│       ├── values-prod.yaml                      # 生产环境覆盖配置
│       └── templates/
│           ├── ingress.yaml                      # Ingress 路由（Traefik）
│           ├── secret.yaml                       # K8S Secret（敏感信息）
│           └── rabbitmq-ready-hook.yaml          # Helm Hook（前置检查）
├── aws-infra-reflect/                            # 现网配置备份（terraform import 前的原始 tf）
├── scripts/                                      # 运维脚本
└── README.md                                     # 本文件
```

---

## 快速开始

完整部署流程（按顺序执行）：

### 第一步：准备 AWS EC2（推荐用 Terraform，不需要登 AWS Console）

**方式 A：用 Terraform 一键调整（推荐）**

```bash
cd infrastructure/terraform/live/prod

# 1. 先查你的 EC2 实例 ID
aws ec2 describe-instances \
  --query "Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# 2. 导入现网 EC2 到 Terraform 状态（只做一次）
terraform import aws_instance.k3s_server i-xxxxxxxxxxxx

# 3. 确认 terraform.tfvars 中已配置
# instance_type   = "t3.medium"   # 4 GB 内存
# ebs_volume_size = 20            # 20 GB 磁盘

# 4. 预览变更
terraform plan

# 5. 执行变更
#    instance_type 改变 → EC2 会重启（约 1-2 分钟中断）
#    volume_size 增大  → 在线扩容，不中断
terraform apply
```

**方式 B：手动在 AWS Console 操作**

1. 登录 AWS Console → EC2 → 调整实例类型到 t3.medium（4GB 内存）
2. 调整 EBS 磁盘到 20GB
3. 重启 EC2
4. SSH 到 EC2

### 第二步：安装 K3S（在 EC2 上）

```bash
curl -sfL https://get.k3s.io | sh -
sudo kubectl get nodes  # 确认 K3S 运行
sudo cat /etc/rancher/k3s/k3s.yaml  # 查看 kubeconfig
```

### 第三步：用 Terraform 管理 AWS 资源

```bash
cd infrastructure/terraform/live/prod
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars，填入你的值
terraform init
terraform import <资源> <ID>  # 如果 AWS 上已有手动创建的资源，先 import 到 Terraform 状态中
terraform plan                 # 预览变更（确认与已导入资源无冲突后）
terraform apply                # 执行变更
```

### 第四步：用 Helm 部署微服务 + 有状态中间件到 K3S

```bash
# 构建所有服务的 Docker 镜像（在本地开发机）
cd ../../..
./scripts/build-images.sh

# 推送镜像到 Docker Hub
docker push gongchengship/smart-invest-user-service:1.0.0
# ... 其他服务同理

# 在 EC2 上拉取镜像（或从快网机 crane pull → scp → ctr import）
# 参考：k3s-image-import-workflow 文档

# ========== 数据迁移（如果 EC2 上已有 docker-compose 的 Postgres）==========
# SSH 到 EC2，备份旧数据
ssh ec2-user@<IP>
docker exec smart-invest-db pg_dump -U smartadmin smartinvest | gzip > ~/db-backup.sql.gz
exit

# 部署（含 PostgreSQL + RabbitMQ + 所有微服务）
cd infrastructure/helm/umbrella
helm dependency update   # 下载子 Chart 依赖（含 postgresql/redis）
helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --atomic --timeout 600s

# 恢复数据库
kubectl exec -i -n smart-invest postgresql-0 -- \
  psql -U smartadmin smartinvest < ~/db-backup.sql.gz

# 验证
kubectl get all -n smart-invest
kubectl get pvc -n smart-invest    # 看 PVC 是否都 Bound
helm list -n smart-invest
```

### 第五步：部署前端（S3 + CloudFront）

```bash
# 构建前端
cd ../../frontend
npm run build

# 上传到 S3
aws s3 sync dist/ s3://<bucket-name>/ --delete

# 刷新 CloudFront 缓存
aws cloudfront create-invalidation --distribution-id <DISTRIBUTION_ID> --paths "/*"
```

### 第六步：验证

```bash
terraform output        # 查看 AWS 资源信息
terraform output website_url  # 获取网站 URL
curl https://d123456.cloudfront.net/api/actuator/health  # 检查后端健康
```

---

## 有状态服务处理方案

### 不买 AWS 托管服务的替代策略

| AWS 托管服务 | 替代方案 | 工作负载类型 | 持久化方式 |
|-------------|---------|-------------|-----------|
| AWS RDS (PostgreSQL) | K3S StatefulSet + PVC | StatefulSet | `volumeClaimTemplates` → EC2 本地磁盘 |
| AWS ElastiCache (Redis) | K3S Deployment + PVC | Deployment | 独立 PVC → EC2 本地磁盘 |
| AWS Amazon MQ (RabbitMQ) | K3S Deployment + PVC | Deployment | 独立 PVC → EC2 本地磁盘 |

### 核心概念：PV/PVC 工作流

```
你声明 PVC                K3S 自动创建 PV           Pod 挂载使用
（我要 5GB 磁盘）    →   （这里有个 5GB 磁盘）  →   （把磁盘插到这个路径）
```

K3S 自带 **local-path-provisioner**（开箱即用），不需要手动创建 PV。
只要写一个 PVC，K3S 自动在节点的 `/var/lib/rancher/k3s/storage/` 下创建对应目录。

### StatefulSet vs Deployment（有状态服务选型）

| 特性 | Deployment | StatefulSet |
|------|-----------|-------------|
| Pod 命名 | user-abc123 (随机) | postgresql-0, -1 (有序) |
| Pod DNS 名 | 不可预测 | postgresql-0.svc.ns.svc.cluster.local |
| PVC 管理 | 所有 Pod 共享一个 PVC | 每个 Pod 独享一个 PVC |
| 启停顺序 | 并行（同时启动） | 有序（0 → 1 → 2） |
| 适用场景 | 无状态应用、缓存（Redis） | 数据库（PostgreSQL） |

- **PostgreSQL** 用 StatefulSet —— 数据必须一对一绑定磁盘，Pod 重启不能换盘
- **Redis** 用 Deployment —— 缓存丢失可以从数据库重建，不需要 StatefulSet 的有序特性
- **RabbitMQ** 用 Deployment —— 已有 PVC 绑定，消息队列本身有持久化机制

### 数据备份（当前 project 是 demo project 不做数据备份,这一步可以忽略）

由于 PVC 存在 EC2 本地磁盘上，EC2 被销毁 = 数据永久丢失。
必须定期备份到 S3：

```bash
# PostgreSQL 备份
kubectl exec -n smart-invest postgresql-0 -- \
  pg_dump -U smartadmin smartinvest | gzip > backup-$(date +%Y%m%d).sql.gz

# 上传到 S3（异地备份）
aws s3 cp backup-*.sql.gz s3://your-backup-bucket/

# 恢复
kubectl exec -i -n smart-invest postgresql-0 -- \
  psql -U smartadmin smartinvest < backup-20260811.sql.gz
```

建议：用 K8S CronJob 或外部定时任务自动执行备份。
生产环境还应定期打 EBS 快照（`aws ec2 create-snapshot`）。

---

## 监控方案（CloudWatch 三层架构）

```
第 3 层：告警（Alert）         SNS + CloudWatch Alarm → 邮件/短信通知
    ▲
第 2 层：应用/容器监控          Prometheus + Grafana（K3S 上跑）
    ▲
第 1 层：基础设施监控           CloudWatch Agent（EC2 CPU/内存/磁盘）
```

### 当前状态

| 层面 | 有什么 | 缺什么 |
|------|--------|--------|
| **EC2 指标** | IAM Role 已绑定 `CloudWatchAgentServerPolicy`，EC2 基础指标（CPU/磁盘/网络）自动上报 | 内存指标需要装 CloudWatch Agent（DaemonSet） |
| **告警** | 旧 shell 脚本 `scripts/cloudwatch-setup.sh` | 未集成到 Terraform，无 SNS 通知配置 |
| **应用日志** | 无 | Spring Boot 日志未送 CloudWatch Logs |
| **K3S/Pod 监控** | 无 | 没有 Prometheus + Grafana |

### 后续计划

- 第 1 层：写 Terraform 模块管理 CloudWatch Agent 配置 + SSM Parameter Store
- 第 2 层：用 Helm 部署 Prometheus + Grafana 到 K3S
- 第 3 层：写 Terraform 模块管理 CloudWatch Alarm + SNS Topic + Email 订阅

---

## DevOps 核心学习路径

建议按以下顺序学习（每个主题都配套了详细注释的代码）：

1. **Terraform 基础** → `infrastructure/terraform/live/prod/main.tf`（Provider、变量、输出、backend）
2. **Terraform 模块化** → `infrastructure/terraform/modules/`（如何拆分可复用模块、模块间依赖）
3. **Helm Chart 结构** → `infrastructure/helm/charts/user-service/`（Chart.yaml、values.yaml、templates/）
4. **Helm Umbrella 模式** → `infrastructure/helm/umbrella/`（依赖管理、多环境覆盖、Hook、Ingress）
5. **有状态服务 (PVC/StatefulSet)** → `infrastructure/helm/charts/postgresql/`（StatefulSet vs Deployment、Headless Service、volumeClaimTemplates）
6. **K3S 运维** → `doc-K8S/` + `scripts/`（镜像管理、部署、监控）
7. **监控与告警** → CloudWatch Agent → Prometheus + Grafana → CloudWatch Alarm（后续补充）

### 额外学习资源

- `doc-manually/DevOps/Terraform_Complete_Guide.md`
- `doc-manually/DevOps/Helm_Complete_Guide.md`
- `doc-manually/DevOps/Kubernetes_Core_Principles_Guide.md`
- `doc-manually/DevOps/Most-Common-Kubernetes-Helm-AWS-Issues-Troubleshooting.md`
- `aws-infra-reflect/_Useage.md` — Terraform 入门指南（Terraform vs AWS CLI、凭证管理、工作流、常见操作）
