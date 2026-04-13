# AWS Deployment Plan A — EC2 + Docker Compose + S3 + CloudFront

**Audience**: First-time AWS deployer  
**Goal**: Get smart-invest running on a public HTTPS URL with automated CI/CD  
**Estimated cost**: ~$9/month (EC2 t3.micro ~$8 + S3/CloudFront ~$1)  
**$200 credit runway**: ~22 months

---

## Architecture Overview

```
Developer (git push)
        │
        ▼
  GitHub Actions
        ├── Frontend job ──────────────────────────────────────┐
        │   npm build → aws s3 sync → CF invalidation          │
        └── Backend job ──────────────────────────┐            │
            mvn package → docker build            │            │
            → ECR push → SSH to EC2               │            │
            → docker-compose up                   │            │
                                                  ▼            ▼
                                            EC2 t3.micro    S3 Bucket
                                            ┌────────────┐  (frontend)
                                            │ Spring Boot│       │
                                            │ :8080      │       │
                                            │            │       │
                                            │ PostgreSQL │       │
                                            │ :5432      │       │
                                            └────────────┘       │
                                                  │              │
                                            ┌─────▼──────────────▼──────┐
                                            │       CloudFront          │
                                            │   https://xxxx.cf.net     │
                                            │                           │
                                            │  /api/* → EC2:8080        │
                                            │  /*     → S3              │
                                            └───────────────────────────┘
                                                        │
                                                   用户浏览器
```

**辅助 AWS 服务**（已在代码中集成）：

- **AWS Secrets Manager**：存储 JWT secret 和数据库密码
- **AWS SES**：发送邮件通知

---

## 第一步：AWS 账号基础设置

### 1.1 创建 IAM 用户（不要用 root 账号操作）

1. 登录 AWS Console → 搜索 **IAM** → Users → Create user
2. 用户名：`smart-invest-deploy-user`
3. 勾选 **Provide user access to the AWS Management Console**（可选）
4. Permissions：选 **Add user to group**，选择 Create group 以创建用户组。
5. User group name 填 smart-invest-deploy-group，
   Permissions policies (6/1145) 中，按照以下Policy name 搜索并勾选对应 policy:
   添加以下托管策略：
   - `AmazonEC2FullAccess`
   - `AmazonS3FullAccess`
   - `CloudFrontFullAccess`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `SecretsManagerReadWrite`
   - `AmazonSESFullAccess`
     最后点击 Create user group
6. 回到create user界面，在user groups中勾选刚才创建的 smart-investment-deploy-group, 
   将 smart-invest-deploy-user 添加入 smart-investment-deploy-group 这个用户组，点击 Next
7. 创建完成后点击 Return tousers list, 回到 IAM > Users 页面
8. 点击刚才创建的 smart-invest-deploy-user 用户，进入用户详情页→ **Create access key**
9. 选 **Application running outside AWS** → 点击 Create access Key,下载 CSV（只有这一次机会！）

> **重要**：把 Access Key ID 和 Secret Access Key 保存好，后面 GitHub Actions 要用。

### 1.2 安装并配置 AWS CLI（本地电脑）

```bash
# macOS
brew install awscli

# 配置（用上面下载的 CSV 里的 Key）
aws configure
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: xxxx
# Default region name: ap-southeast-1
# Default output format: json

# 验证
aws sts get-caller-identity
```

---

## 第二步：创建 ECR（Elastic Container Registry） 仓库（存 Docker 镜像）

```bash
# 在本机的 terminal 中 用以下命令在 AWS 上创建仓库
aws ecr create-repository \
  --repository-name smart-invest \
  --region ap-southeast-1

 ## 删除仓库（慎用，会删除所有镜像！）
  #aws ecr delete-repository \
   # --repository-name smart-invest \
   # --region ap-southeast-1 \
   # --force

# 记下输出中的 repositoryUri，格式类似：
# "repositoryUri": <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/smart-invest  # <YOUR_AWS_ACCOUNT_ID> 是你的 AWS Account ID（12位数字，例：123456789012），见 AWS console 右上角
```

{
  "repository": {
    "repositoryArn": "arn:aws:ecr:ap-southeast-1:<YOUR_AWS_ACCOUNT_ID>:repository/smart-invest",  // 例：arn:aws:ecr:ap-southeast-1:123456789012:repository/smart-invest
    "registryId": "<YOUR_AWS_ACCOUNT_ID>",  // 例：123456789012
    "repositoryName": "smart-invest",
    "repositoryUri": "<YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/smart-invest",  // 例：123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/smart-invest
    "createdAt": "2026-04-09T19:15:35.510000+08:00",
    "imageTagMutability": "MUTABLE",
    "imageScanningConfiguration": {
        "scanOnPush": false
    },
    "encryptionConfiguration": {
        "encryptionType": "AES256"
    }
  }
}

```
---

## 第三步：创建 EC2 实例

### 3.1 创建 Key Pair（SSH 密钥）

AWS Console → EC2 → Key Pairs → Create key pair

- Name: `smart-invest-ec2-keypair`
- Type: RSA
- Format: `.pem`
- 下载后保存到 `~/.ssh/smart-invest-ec2-keypair.pem`
- 设置权限（Mac/Linux）：
```bash
chmod 400 ~/.ssh/smart-invest-ec2-keypair.pem
```

### 3.2 创建 Security Group (Security Group 页面解释:安全组充当实例的虚拟防火墙，用于控制入站和出站流量)

AWS Console → EC2 → Security Groups → Create security group

- Name: `smart-invest-security-group`
- Description: Smart Invest backend security group 
- Inbound rules（入站规则）：

| Type       | Protocol | Port | Source    | 说明                                                                             |
| ---------- | -------- | ---- | --------- | ------------------------------------------------------------------------------ |
| SSH        | TCP      | 22   | My IP     | 只允许你的 IP SSH，（如果本地开了 VPN，则 SSH 连不上，需要将 安全组中 SSH 的Source 临时改为 0.0.0.0/0允许任何 IP） |
| Custom TCP | TCP      | 8080 | 0.0.0.0/0 | CloudFront 转发后端请求                                                              |

> 安全建议：8080 理想情况只对 CloudFront IP 开放，但入门阶段先开 0.0.0.0/0 更简单。
> 最后点击右下角 Create security group 创建完成。

### 3.3 启动 EC2 实例

AWS Console → EC2 → Launch Instance

- **Name**: smart-invest-server
- **AMI**: Amazon Linux 2023（免费套餐可用）
- **Instance type**: t3.micro
- **Key pair**: 选刚才创建的 `smart-invest-ec2-keypair`
- **Network settings > Security group**: 选刚才创建的 `smart-invest-security-group`
- **Storage**: 默认 8GB 即可
- 点击 **Launch instance**
- （可选）为避免账单超额，
  - 建议设置 Billing and Cost Management 计费与成本管理
  - 建议设置自动停止：
    - 选中新实例 → Actions → Instance state → **Create stop schedule**
    - Schedule type: One time schedule
    - Date & time: 24小时后（比如明天同一时间）
    - Action: Stop
    - Create schedule
- 最后点击右下角的 View all instances.
- 点击 instance ID 进入实例详情页，等待状态变为 Running 后，
  启动后记下 **Public IPv4 address**（如 `<YOUR_EC2_PUBLIC_IP>`，例：`13.229.181.210`）

### 3.4 在 EC2 上安装 Docker

```bash
# SSH 进入服务器 （如果本地开了 VPN，则 SSH 连不上，需要将 安全组中 SSH 的Source 临时改为 0.0.0.0/0允许任何 IP）
ssh -i ~/.ssh/smart-invest-ec2-keypair.pem ec2-user@<YOUR_EC2_PUBLIC_IP>  # 例：13.229.181.210

# 安装 Docker
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# 安装 docker compose plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 安装 AWS CLI（EC2 上也需要，用于拉取 ECR 镜像）
#sudo yum install -y awscli #这样安装的讲师 aws-cli v1，我们需要的是V2，所以下面是安装 AWS CLI v2 的命令
  ### 1. 下载安装包
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  ### 2. 解压
  unzip awscliv2.zip
  ### 3. 安装
  sudo ./aws/install
  ### 4. 验证
  aws --version

  ### 5. 如果没有 unzip，先安装：
  sudo yum install -y unzip

  正常输出类似：aws-cli/2.x.x Python/3.x.x Linux/...

# 退出并重新登录（使 docker 用户组生效）
exit
ssh -i ~/.ssh/smart-invest-ec2-keypair.pem ec2-user@<YOUR_EC2_PUBLIC_IP>  # 例：13.229.181.210
docker --version   # 验证
```

### 3.5 给 EC2 赋予 ECR 和 Secrets Manager 权限

> **注意**：从 EC2 的 "Modify IAM role" 页点 "Create new IAM role" 会打开一个简化弹窗，该弹窗每次只能附加一个策略，不适合我们需要附加多个策略的场景。请按以下步骤走完整的 IAM 控制台流程。

**第一部分：在 IAM 控制台创建 Role**

1. 新开标签页 → 搜索 **IAM** → 左侧菜单 **Roles** → **Create role**
2. **Trusted entity type**：选 **AWS service**
3. **Use case**：下拉选 **EC2** → 点 **Next**
4. **Add permissions** 页：依次搜索并勾选以下 3 个策略：
   - `AmazonEC2ContainerRegistryFullAccess`
   - `SecretsManagerReadWrite`
   - `AmazonSESFullAccess`
5. 点 **Next**
6. **Role name**：填 `smart-invest-ec2-role` → 点 **Create role**

**第二部分：将 Role 绑定到 EC2 实例**

1. 回到 **EC2 Console** → 选中 `smart-invest-server` 实例
2. **Actions → Security → Modify IAM role**
3. 下拉选择刚才创建的 `smart-invest-ec2-role`
4. 点 **Update IAM role**

---

## 第四步：在本地执行 aws 命令，将密码 等存入 AWS 上的 Secrets Manager 中（EC2 上也可以执行，但需要先 上在 EC2安装 AWS CLI）

因为本地为 aws-cli 配置了登录 AWS 的凭据（~/.aws/credentials），所以可以在本地直接执行 aws 命令来操作 AWS 资源（比如 Secrets Manager），不需要 SSH 进入 EC2 后再执行。

```bash
# 在本地执行（不是 EC2 上）

# ⚠️ 注意：当前工程实际上不从 Secrets Manager 中读取 DB_PASSWORD 和 JWT_SECRET。
# 核心原因：为节省成本，数据库采用自建 PostgreSQL 容器而非 AWS RDS。
# PostgreSQL 容器启动时需要 DB_PASSWORD，但容器本身无法调用 Secrets Manager API，
# 只能从 docker-compose 环境变量（即 EC2 的 ~/.env 文件）读取。
# 为避免同一份密码在两处维护（.env 一份、Secrets Manager 一份），
# 决定让 Spring Boot 和 PostgreSQL 容器统一从 EC2 的 ~/.env 文件取值。
# Secrets Manager 在此架构下仅作为安全保险箱——存一份备份，忘记密码时可随时手动取回。
# 若未来升级为 AWS RDS，则可让 Spring Boot 直接从 Secrets Manager 取值，.env 中不再存明文密码。

# AWS Secrets Manager存储：
# 在本机终端向 AWS Secrets Manager 中存储数据库密码
aws secretsmanager create-secret \
  --name "smart-invest/prod/db-password" \
  --secret-string "<YOUR_DB_PASSWORD>" \  # 例：MyStr0ngPassw0rd!
  --region ap-southeast-1

# 在本机终端向 AWS Secrets Manager 中存储 JWT Secret（生成一个随机强密码）
aws secretsmanager create-secret \
  --name "smart-invest/prod/jwt-secret" \
  --secret-string "$(openssl rand -hex 32)" \
  --region ap-southeast-1
```

> 记下你设置的数据库密码 和 JWT_SECRET，下面第五步要用。

# AWS Secrets Manager读取：

# 在本机终端执读取 AWS Secrets Manager 中的 JWT_SECRET 的值：

```bash
aws secretsmanager get-secret-value \
  --secret-id smart-invest/prod/db-password \
  --region ap-southeast-1 \
  --query SecretString \
  --output text
```

# 在本机终端执读取 AWS Secrets Manager 中的 JWT_SECRET 的值：

```bash
aws secretsmanager get-secret-value \
  --secret-id smart-invest/prod/jwt-secret \
  --region ap-southeast-1 \
  --query SecretString \
  --output text
```

---

## 第五步：在 EC2 上配置 docker-compose

```bash
# SSH 进入 EC2
ssh -i ~/.ssh/smart-invest-ec2-keypair.pem ec2-user@<YOUR_EC2_PUBLIC_IP>  # 例：13.229.181.210

# 创建项目目录
mkdir ~/smart-invest && cd ~/smart-invest

# 创建 .env 文件（存运行时环境变量）
cat > .env << 'EOF'
DB_PASSWORD="<YOUR_DB_PASSWORD>" # 例：MyStr0ngPassw0rd!，可以去 Secrets Manager 取之前存的密码
JWT_SECRET= "<YOUR_JWT_SECRET>" # 例：从 Secrets Manager 取的 JWT_SECRET，格式是一个随机的长字符串，如 "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
AWS_REGION=ap-southeast-1
ECR_REGISTRY=<YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com  # 例：123456789012
IMAGE_TAG=latest
EOF
chmod 600 .env

# 创建 docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.9'
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: smartinvest
      POSTGRES_USER: smartadmin
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U smartadmin -d smartinvest"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: ${ECR_REGISTRY}/smart-invest:${IMAGE_TAG}
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: prod
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/smartinvest
      SPRING_DATASOURCE_USERNAME: smartadmin
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      AWS_REGION: ${AWS_REGION}
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  postgres_data:
EOF
```

---

## 第六步：创建 Dockerfile

在项目根目录创建 `Dockerfile`：

```dockerfile
# backend/Dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY app/target/app-*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**作用**：GitHub Actions 的 CD 流程第一步就是用这个 Dockerfile 把编译好的 JAR 打包成 Docker 镜像，然后推送到 ECR。EC2 上不需要安装 Java，所有运行时都封装在镜像内。

```bash
# 本地验证文件存在
ls backend/Dockerfile
```

---

## 第七步：创建 S3 Bucket（托管前端）

```bash
# 创建 bucket（名字全球唯一，换一个自己的名字）
aws s3api create-bucket \
  --bucket smart-invest-frontend-service-prod-bucket-name \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# 关闭公开访问（通过 CloudFront 访问，不需要直接公开）
aws s3api put-public-access-block \
  --bucket smart-invest-frontend-service-prod-bucket-name \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region ap-southeast-1
```

---

## 第八步：创建 CloudFront 分发

## CloudFront配置前的相关说明：HTTPS 传输链路详解

### 用户访问的是 HTTP 还是 HTTPS？

**用户侧全程 HTTPS**。浏览器地址栏显示 `https://` 和绿色锁头，与正规商业网站体验一致。

### 完整请求链路

```
浏览器（用户）
    │
    │  ① HTTPS（TLS 1.2/1.3）
    │     CloudFront 自动提供 SSL/TLS 证书（ACM 托管）
    │     证书域名：*.cloudfront.net
    ▼
CloudFront 边缘节点（全球 CDN）
    │
    ├── 路径匹配 /*（前端静态资源）
    │       │  ② HTTPS → S3
    │       │     CloudFront 与 S3 之间走 AWS 内部加密通道
    │       │     通过 OAC（Origin Access Control）鉴权
    │       ▼
    │     S3 Bucket（私有，仅 CloudFront 可读）
    │
    └── 路径匹配 /api/*（后端 API）
            │  ③ HTTP:8080 → EC2
            │     CloudFront 与 EC2 之间走 AWS 数据中心内部网络
            │     （与公网物理隔离，非公网明文传输）
            ▼
          EC2（Spring Boot :8080）
                │
                │  ④ TCP（容器内部网络）
                ▼
          PostgreSQL（:5432，仅容器内网可访问）
```

### 各段链路安全性分析

| 链路段              | 协议    | 加密方式           | 说明                                               |
| ---------------- | ----- | -------------- | ------------------------------------------------ |
| 浏览器 → CloudFront | HTTPS | TLS 1.2/1.3    | CloudFront 自动签发并续期证书，无需手动管理                      |
| CloudFront → S3  | HTTPS | AWS 内部加密       | S3 bucket 设为私有，仅通过 OAC 允许 CloudFront 访问，外部无法直接访问 |
| CloudFront → EC2 | HTTP  | 无（AWS 内部网络）    | 走 AWS 数据中心内部网络，与公网物理隔离；EC2 无需安装 SSL 证书           |
| EC2 → PostgreSQL | TCP   | 无（Docker 内部网络） | 数据库端口 5432 未对外暴露，仅容器间通信                          |

### 为什么 CloudFront → EC2 用 HTTP 是可接受的？

这是一个常见的架构模式，原因如下：

1. **物理隔离**：CloudFront 到 EC2 的流量走 AWS 内部骨干网络（不经过公网），不存在公网中间人攻击风险
2. **边界加密**：安全边界在 CloudFront 处终止，用户侧始终是 HTTPS，满足绝大多数合规要求
3. **成本与复杂度**：在 EC2 上配置 SSL 证书需要域名绑定和证书管理，入门阶段引入不必要的复杂度
4. **行业实践**：AWS ELB（负载均衡器）+ EC2 的标准架构同样采用此模式（HTTPS 在 ELB 终止，ELB 到 EC2 用 HTTP）

### 如果未来需要更高安全等级

可在以下方向升级：

- **绑定自定义域名 + ACM 证书**：将 `xxxx.cloudfront.net` 替换为自己的域名（如 `app.smart-invest.com`），在 AWS Certificate Manager 申请免费证书绑定到 CloudFront
- **CloudFront → EC2 改用 HTTPS**：在 EC2 上安装证书（如 Let's Encrypt），Security Group 开放 443 端口，CloudFront Origin Protocol 改为 HTTPS only
- **EC2 改为内网 IP + ALB**：EC2 放入私有子网，前面加 Application Load Balancer（ALB）处理 HTTPS 终止，EC2 不暴露公网 IP

---

开始配置：
**CloudFront 的作用**：它是整个架构的统一入口。用户只访问一个 HTTPS 域名（`xxxx.cloudfront.net`），CloudFront 根据路径自动决定：请求 `/api/*` 转发给 EC2 后端，其余请求（`/*`）从 S3 获取前端静态文件。这样做的好处是：

- 前后端使用同一个域名，彻底避免跨域（CORS）问题

- CloudFront 自动提供 HTTPS，无需自己申请 SSL 证书

- 前端静态资源在 CloudFront 全球节点缓存，访问更快
1. AWS Console → **CloudFront** → Create distribution

### 8.1 配置 S3 Origin（前端）

**作用**：告诉 CloudFront 去哪里取前端文件。S3 存储的是 React 打包后的静态文件（HTML/JS/CSS），CloudFront 作为 CDN 代理对外暴露，用户无法直接访问 S3，安全性更高。

新版 AWS CloudFront 控制台采用分步向导，流程如下：

**Step 2 - Get started（选择套餐）**

- 选择免费套餐即可（Billing 显示 Free $0/month）

**Step 3 - Specify origin（配置来源）**

- **Distribution name**：填入 `smart-invest-front-distribution`
- **S3 origin**：在下拉中选择你的 S3 bucket（`smart-invest-frontend-service-prod-bucket-name`）
- **Grant CloudFront access to origin**：选 **Yes**
  - 作用：让 CloudFront 获得读取 S3 的权限，同时 S3 bucket 保持私有（不对公网开放），只有 CloudFront 能读取其中的文件
  - 新版 UI 会自动更新 S3 Bucket Policy，无需手动复制粘贴 Policy
  - 页面蓝色提示框会显示："Because you granted CloudFront access to your origin, CloudFront can write and update S3 bucket policies..."

**Step 4 - Enable security**

- 保持默认或按需配置

**Step 5 - Review and create**

- 确认配置无误后点击 **Create distribution**

> **注意**：新版 UI 已无需手动去 S3 更新 Bucket Policy，AWS 会在创建时自动完成。

### 8.2 配置默认行为（前端）

**作用**：定义 CloudFront 处理所有未匹配到其他规则的请求（即 `/*`，也就是前端页面请求）时的默认策略。

创建向导完成后，进入 Distribution 配置默认行为：

1. 进入刚创建的 Distribution → 点击 **Behaviors** 标签页
2. 选中默认行为（`Default (*)`）→ 点击 **Edit**
3. 修改以下两项：
   - **Viewer protocol policy** → 选 `Redirect HTTP to HTTPS`
     - 作用：用户输入 `http://` 时自动跳转到 `https://`，强制加密传输，防止中间人攻击
   - **Cache policy** → 选 `CachingOptimized`
     - 作用：前端静态文件（JS/CSS/图片）在 CloudFront 节点缓存，用户下次访问直接从最近的节点返回，不需要再回源 S3，速度更快、成本更低
4. 点击 **Save changes**

> 向导创建时 Cache settings 显示"will apply default cache settings"，默认值不一定是 CachingOptimized，创建后需手动确认并修改。

### 8.3 添加 EC2 Origin（后端）

**作用**：将 EC2 上运行的 Spring Boot 后端注册为 CloudFront 的第二个来源。注册后，CloudFront 才能在 8.4 中把 `/api/*` 请求转发给它。

创建完 distribution 后：Distribution → 选中你的 distribution → **Origins** 标签页 → **Create origin**

- **Origin domain**: 输入你的 EC2 **Public IPv4 DNS**（不能用裸 IP，CloudFront 不支持）
  - 在 EC2 Console → 选中实例 → 详情面板找 **Public IPv4 DNS**，格式如：`ec2-<YOUR_EC2_PUBLIC_IP_DASHES>.ap-southeast-1.compute.amazonaws.com`（例：`ec2-13-229-181-210.ap-southeast-1.compute.amazonaws.com`）
  - 作用：告诉 CloudFront 后端服务器的地址
- **Name**: 可保持自动填充，或改为 `ec2-backend`
- **Protocol**: HTTP only
  - 作用：CloudFront 到 EC2 之间的通信使用 HTTP（因为 EC2 上没有配置 SSL 证书）。用户到 CloudFront 之间仍然是 HTTPS，安全性不受影响
- **HTTP port**: 8080
  - 作用：指定 Spring Boot 监听的端口
- **Origin access**: 选 **Public**（EC2 不是 S3，没有 OAC 概念，直接公网访问即可）
- 其余保持默认

点击右下角 **Save changes**

### 8.4 添加 /api/* 行为（路由到后端）

**作用**：创建一条路由规则，让所有 `/api/` 开头的请求走 EC2 后端，而不是默认的 S3。这是前后端共用同一域名的关键配置。

> **前提**：必须先完成 8.3，确保 EC2 origin 已创建，否则下拉列表中不会出现 EC2 origin 选项。

Distribution → **Behaviors** 标签页 → **Create behavior**

- **Path pattern**: `/api/*`
  - 作用：匹配所有后端 API 请求，如 `/api/login`、`/api/holdings`
- **Origin and origin groups**: 选 EC2 origin（即 8.3 中创建的）
  - 作用：命中此规则的请求转发到 EC2，而非 S3
- **Viewer protocol policy**: HTTPS only
  - 作用：强制 API 请求必须使用 HTTPS，防止敏感数据（Token、密码等）明文传输
- **Allowed HTTP methods**: 选 `GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE`
  - 作用：API 需要支持写操作（POST/PUT/DELETE），默认的 GET, HEAD 不够用
- **Cache policy**: CachingDisabled（API 不缓存！）
  - 作用：API 返回的是实时数据，不能缓存。如果缓存了，用户看到的可能是过期的账户数据
- **Origin request policy**: AllViewer
  - 作用：将用户请求的所有 Header（包括 `Authorization: Bearer <token>`）原样转发给 EC2，否则后端收不到登录凭证，所有需要鉴权的接口都会 401

点击 **Save changes**

### 8.5 配置 SPA 路由（前端）

**作用**：解决 React Router 单页应用的直接访问问题。

当用户直接在浏览器地址栏输入 `https://d2hoqnqufe8qq0.cloudfront.net/holdings` 时：
- CloudFront 去 S3 找 `/holdings` 这个文件 → S3 不存在 → 返回 403/404
- 但实际上 `/holdings` 是 React Router 的前端路由，应该由 `index.html` 处理

配置此规则后，CloudFront 会把所有 403/404 响应替换为返回 `index.html`，React Router 再接管路由解析。

Distribution → **Error pages** 标签页 → **Create custom error response**

每条规则按以下步骤配置（403 和 404 各需创建一次）：

1. **HTTP error code**：选 `403: Forbidden`（第二次选 `404`）
2. **Error caching minimum TTL**：保持默认 `10`（或填 `0` 避免错误被缓存）
3. **Customize error response**：选 **Yes**（选 Yes 后才会出现下方两个字段）
4. **Response page path**：填 `/index.html`
5. **HTTP response code**：选 `200`
6. 点击 **Save changes**，然后重复上述步骤创建 404 规则

修改我成之后的规则如下：
| HTTP error code | Response page path | HTTP response code |
| --------------- | ------------------ | ------------------ |
| 403             | `/index.html`      | 200                |
| 404             | `/index.html`      | 200                |

### 8.6 记录 CloudFront 信息

创建完成后，在 Distribution 详情页记下以下两个值，后续步骤会用到：

- **Distribution domain name**（如 `d2hoqnqufe8qq0.cloudfront.net`）
  - 这是你的公网 HTTPS 访问地址，第九步配置前端 API 地址时要用
- **Distribution ID**（如 `EXXXXXXXXXXXX`）,在 AWS console 的 CloudFront 页面，Distribution 列表中，ID 列显示的就是 Distribution ID
   这个 ID 在 GitHub Actions 部署前端后需要用来刷新 CloudFront 缓存，否则用户看到的还是旧版本
  - GitHub Actions 部署前端后需要用它来刷新 CloudFront 缓存，否则用户看到的还是旧版本

---

## 第九步：配置前端 API 地址

在 `frontend/` 目录创建 `.env.production`：

```bash
vim .env.production &&
VITE_API_BASE_URL=https://d2hoqnqufe8qq0.cloudfront.net
```

（把域名换成你实际的 CloudFront 域名）

---

## 第十步：GitHub Actions CI/CD

在项目根目录创建以下文件：

### 10.1 配置 GitHub Secrets

GitHub 仓库 → Settings → Secrets and variables → Actions → New repository secret，
页面上两个输入框：
上面的小输入框填 Secret 名称，如 AWS_ACCESS_KEY_ID
下面的大输入框填对应的值，添加以下 Secrets： 如 abcxyz1234567890

| Secret 名称               | 值                                                                                                  |
| ----------------------- | -------------------------------------------------------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | IAM 用户的 Access Key ID                                                                              |
| `AWS_SECRET_ACCESS_KEY` | IAM 用户的 Secret Access Key                                                                          |
| `FRONTEND_BUCKET`       | `smart-invest-frontend-service-prod-bucket-name`                                                   |
| `CF_DISTRIBUTION_ID`    | CloudFront 页面 → Distributions 列表 → ID 列                                                            |
| `API_BASE_URL`          | CloudFront 域名，如 `https://d2hoqnqufe8qq0.cloudfront.net`（例：`https://d2xxxxxxxxxxxx.cloudfront.net`） |
| `EC2_HOST`              | EC2 公网 IP（如 `<YOUR_EC2_PUBLIC_IP>`，例：`13.229.181.210`）                                             |
| `EC2_SSH_KEY`           | `smart-invest-ec2-keypair.pem` 的完整内容，用以下命令直接复制到剪贴板：`cat ~/.ssh/smart-invest-ec2-keypair.pem        |

>  !!! MAC OS zsh 中直接 cat ~/.ssh/smart-invest-ec2-keypair.pem 的话，zsh会在输出字符的末尾添加一个 %表示文件末尾没有换行符，
>    所以推荐用 `cat ~/.ssh/smart-invest-ec2-keypair.pem | pbcopy` 复制到剪贴板。
> `DB_PASSWORD` 和 `JWT_SECRET` 已存在于 EC2 的 `~/smart-invest/.env` 文件中，备份在 AWS Secrets Manager  中，**不需要**加入 GitHub Secrets。
> `ECR_REGISTRY` 由 CD 流程中的 `amazon-ecr-login` Action 自动获取，**不需要**手动填写。
> `EC2_INSTANCE_ID` 是 SSM 部署方式才需要，当前采用 SSH 部署，**不需要**此 Secret。

>  EC2_HOST 是 EC2 的公网 IP 地址，在没有配置弹性IP（Elastic IP） 的情况下，EC2 重启后 IP 会变，
>  
>  所以每次重启需要改两处：

需要更新的地方	改什么值
| 配置位置                | 需要更新的值               |
|-------------------------|----------------------------|
| GitHub Secret `EC2_HOST` | 新的 Public IPv4 address   |
| CloudFront Origin Domain Name | 新的 Public IPv4 DNS |
配了 弹性 IP (Elastic IP) 之后, 弹性IP 固定不变，这两处就都不需要改了。
>  。

> **可选：每次重启 EC2 Instance,其公网 IP 都会变， 为 EC2 配置弹性 IP（Elastic IP），使公网 IP 固定不变：**
> 
> 1. 进入 AWS Console → EC2 → 左侧菜单 → **弹性 IP（Elastic IPs）**
> 2. 点击右上角 **"分配弹性 IP 地址（Allocate Elastic IP address）"** → 保持默认 → 点击 **"分配"**
> 3. 选中刚分配的弹性 IP → 点击 **"操作（Actions）→ 关联弹性 IP 地址（Associate Elastic IP address）"**
> 4. 资源类型选 **实例（Instance）**，选择你的 EC2 实例 → 点击 **"关联"**
> 5. 将新的弹性 IP 更新到 GitHub Secrets 的 `EC2_HOST` 中。例：46.137.250.243
> 6. 去 EC2 控制台找到 ELastic IPs 点进去找打46.137.250.243 对应的 Public DNS，例：ec2-46-137-250-243.ap-southeast-1.compute.amazonaws.com
     然后去 CloudFront → Distributions （点击 Distribution ID）→ Origins → (选中Origin type 为 EC2的 origin) → Edit ：`填入弹性 IP 的 Public DNS
> 7. 一旦给 EC2 的Public IPv4 address关联了弹性 IP 后，EC2 的 Public IPv4 address 就会变成这个弹性 IP，SSH 登录的时候也用这个 弹性 IP。

> 注意：AWS免费套餐每月包含750小时的公有IPv4地址使用时间，但这仅适用于附加到EC2实例的公有IP
> 其他服务（如NAT网关、负载均衡器）使用的弹性IP不在免费套餐范围内，
> 也就是说，弹性 IP 关联到**运行中**的实例是免费的；若实例停止或弹性 IP 未关联任何实例，AWS 会收取少量费用（约 $0.005/小时，即 30 天为3.6$），
> 不用时记得释放。

### 10.2 用 Github Actions 部署前的检查

1.EC2 上已经安装了 Docker 和 Docker Compose
2.EC2 上已经有 ~/smart-invest/docker-compose.yml 和 .env 文件
3.EC2 的 Security Group 已开放相应端口
4.所有 GitHub Secrets 已填写完毕

### 10.3 GIthub Action 的 CI & CD 配置文件

前后端 CI
见本工程代码  `.github/workflows/ci.yml`
前后端 CD
见本工程代码 `.github/workflows/cd.yml`：

---

## 第十一步：首次部署

说明：
GitHub Actions 会自动完成：

1. 构建 JAR → 打包 Docker 镜像 → 推送到 ECR
2. SSH 进 EC2 → 拉取新镜像 → `docker compose up -d app`
3. npm build 前端 → 同步到 S3 → 刷新 CloudFront 缓存

(!!！注：如果数据库部署失败，这个命令 docker compose down -v 可以删除容器和挂载卷卷，也就是删除数据库数据所在卷，慎用。）
在 GitHub 仓库 → **Actions** 标签页查看执行进度和日志。

### 方式一：通过 GitHub Actions 部署（推荐）

1. 手动点击 Actions 的 workflow:
   登录 github, 点击 Actions 标签页，确认 CI（ci.yml中定义的名称） 和 CD(cd.yml中定义的名称） 已经出现在左上角的菜单中，
   说明 GitHub Actions 已正确识别到 ci.yml 和 cd.yml 配置文件。ci.yml 和 cd.yml 配置文件中配置了允许手动触发。
   -> CI -> Run workflow -> Use workflow from: Branch:master -> Run workflow button -> CI 手动触发完成；
   -> CD -> Run workflow -> Use workflow from: Branch:master -> Run workflow button -> CD 手动触发完成；

一切完成后，
访问 `https://d2hoqnqufe8qq0.cloudfront.net`验证部署成功。

2. 或者遵循CI & CD最佳实践， 放开 ci.yml 和 cd.yml 中的注释，应用 github repository 的PR 或 push 等动作来自动触发
   （按照规范 CI & CD 流程的话，
   根据代码 .github/workflows/ci.yml 中的配置 提 pull request 【注意不是 push】到 代码到 `main` 分支，即可触发 CI 流程自动执行；
   根据代码 .github/workflows/cd.yml 中的配置,代码被合并到 main 后，会触发 CD 流程会自动执行，直接完成部署。
   但是 ci.yml 和 cd.yml 中的自动触发条件我临时注释掉了，避免提代码就触发重新部署。
   ）

```bash
git push origin main
```

一切完成后，
访问 `https://d2hoqnqufe8qq0.cloudfront.net`验证部署成功。

---

### 方式二：手动部署（可用于排查问题）

如果 GitHub Actions 部署失败，可本地手动执行以下命令逐步排查：

```bash
# 1. 打包后端 JAR（在项目根目录执行）
cd backend && mvn package -DskipTests && cd ..

# 2. 登录 ECR
aws ecr get-login-password --region ap-southeast-1 \
  | docker login --username AWS --password-stdin <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com  # 例：123456789012

# 3. 构建并推送 Docker 镜像
docker build -f backend/Dockerfile -t smart-invest:latest backend/
docker tag smart-invest:latest <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/smart-invest:latest  # 例：123456789012
docker push <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/smart-invest:latest  # 例：123456789012

# 4. SSH 到 EC2，拉取新镜像并启动服务
ssh -i ~/.ssh/smart-invest-ec2-keypair.pem ec2-user@<YOUR_EC2_PUBLIC_IP>  # 例：13.229.181.210

# 进入 EC2 后执行：
cd ~/smart-invest
aws ecr get-login-password --region ap-southeast-1 \
  | docker login --username AWS --password-stdin <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com  # 例：123456789012
docker compose pull app
docker compose up -d
docker compose logs -f app
```

后端验证（EC2 上或本地均可）：

```bash
curl http://<YOUR_EC2_PUBLIC_IP>:8080/actuator/health  # 例：13.229.181.210
# 期望返回: {"status":"UP"}
```

前端手动部署：

```bash
cd frontend
npm run build
aws s3 sync dist/ s3://smart-invest-frontend-service-prod-bucket-name/ --delete \
  --cache-control "public, max-age=31536000, immutable"
aws s3 cp dist/index.html s3://smart-invest-frontend-service-prod-bucket-name/index.html \
  --cache-control "no-cache"
aws cloudfront create-invalidation \
  --distribution-id <YOUR_CF_DISTRIBUTION_ID> \  # 例：EXXXXXXXXXXXX
  --paths "/*"
```

然后访问 `https://d2hoqnqufe8qq0.cloudfront.net`验证。

---

## 常见问题排查

| 问题                | 排查方法                                                  |
| ----------------- | ----------------------------------------------------- |
| 后端 500 错误         | `docker compose logs app` 看 Spring Boot 日志            |
| 数据库连接失败           | 检查 `.env` 里密码是否正确；`docker compose ps` 确认 postgres 在运行 |
| 前端白屏              | 浏览器 Console 看错误；检查 `VITE_API_BASE_URL` 是否正确           |
| CloudFront 返回 403 | 检查 S3 Bucket Policy 是否已更新为允许 OAC 访问                   |
| SSH 连接拒绝          | 检查 Security Group 的 22 端口是否对你的 IP 开放                  |
| GitHub Actions 失败 | 检查 Secrets 是否全部配置；查看 Actions 日志                       |

---

## 成本监控（必做）

1. AWS Console → **Billing** → **Budgets** → Create budget
2. 选 **Monthly cost budget**，设置 $15/月报警
3. 邮件通知：到达 80% 时发邮件提醒

---

## 如何暂停/关闭 AWS 服务以节省成本

### 推荐做法：只停止 EC2（保留数据，随时恢复）

EC2 停止后不计算实例费用（节省约 $8/月），但 EBS 磁盘仍收费（约 $0.1/月）。S3、CloudFront、ECR 费用极低（合计约 $1/月），可以不关。

```
AWS Console → EC2 → Instances
→ 选中你的实例 → Instance state → Stop instance
```

> **恢复时**：选中实例 → Instance state → Start instance
> **注意**：重启后 EC2 公网 IP 会变，需要更新 CloudFront EC2 Origin 的域名（EC2 Public IPv4 DNS）

---

### 完全删除（彻底清理，不可恢复）

按顺序操作：

| 步骤            | 操作                                       |
| ------------- | ---------------------------------------- |
| 1. EC2        | Instance state → **Terminate**（磁盘数据一并删除） |
| 2. S3         | 先 Empty（清空内容），再 Delete bucket            |
| 3. CloudFront | 先 Disable（等状态变为 Deployed），再 Delete       |
| 4. ECR        | 选中所有镜像 Delete，再删除 repository             |
| 5. IAM 用户     | IAM → Users → Delete（可选）                 |

---

### 各服务费用参考

| 服务            | 月费用      | 停止/删除方式                  |
| ------------- | -------- | ------------------------ |
| EC2 t3.micro  | ~$8      | Stop（保留）或 Terminate（删除）  |
| EBS 磁盘（随 EC2） | ~$0.8    | 随 Terminate 一起删除         |
| S3            | ~$0.02   | 清空后删除 bucket             |
| CloudFront    | ~$0.01   | Disable 后删除 distribution |
| ECR           | ~$0.1/GB | 删除镜像和 repository         |

---

## 架构总结

| 组件          | AWS 服务          | 作用                          |
| ----------- | --------------- | --------------------------- |
| 前端托管        | S3              | 存储 React 构建产物               |
| CDN + HTTPS | CloudFront      | 统一入口、HTTPS 终止、缓存            |
| 后端运行时       | EC2 t3.micro    | 运行 Spring Boot + PostgreSQL |
| 镜像仓库        | ECR             | 存储 Docker 镜像                |
| 密钥管理        | Secrets Manager | 存储 DB密码、JWT密钥               |
| 邮件服务        | SES             | 发送通知邮件                      |
| CI/CD       | GitHub Actions  | 自动构建和部署                     |
