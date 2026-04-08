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
2. 用户名：`smart-invest-deploy`
3. 勾选 **Provide user access to the AWS Management Console**（可选）
4. Permissions：选 **Attach policies directly**，添加以下托管策略：
   - `AmazonEC2FullAccess`
   - `AmazonS3FullAccess`
   - `CloudFrontFullAccess`
   - `AmazonECR_FullAccess`（ECR = Elastic Container Registry）
   - `SecretsManagerReadWrite`
   - `AmazonSESFullAccess`
5. 创建完成后进入用户 → **Security credentials** → **Create access key**
6. 选 **Application running outside AWS** → 下载 CSV（只有这一次机会！）

> **重要**：把 Access Key ID 和 Secret Access Key 保存好，后面 GitHub Actions 要用。

### 1.2 安装并配置 AWS CLI（本地电脑）

```bash
# macOS
brew install awscli

# 配置（用上面下载的 CSV 里的 Key）
aws configure
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: xxxx
# Default region name: us-east-1
# Default output format: json

# 验证
aws sts get-caller-identity
```

---

## 第二步：创建 ECR 仓库（存 Docker 镜像）

```bash
# 创建仓库
aws ecr create-repository \
  --repository-name smart-invest \
  --region us-east-1

# 记下输出中的 repositoryUri，格式类似：
# 123456789.dkr.ecr.us-east-1.amazonaws.com/smart-invest
```

---

## 第三步：创建 EC2 实例

### 3.1 创建 Key Pair（SSH 密钥）

AWS Console → EC2 → Key Pairs → Create key pair

- Name: `smart-invest-key`
- Type: RSA
- Format: `.pem`
- 下载后保存到 `~/.ssh/smart-invest-key.pem`

```bash
chmod 400 ~/.ssh/smart-invest-key.pem
```

### 3.2 创建 Security Group

AWS Console → EC2 → Security Groups → Create security group

- Name: `smart-invest-sg`
- Description: Smart Invest backend
- Inbound rules（入站规则）：

| Type  | Protocol | Port | Source    | 说明           |
|-------|----------|------|-----------|----------------|
| SSH   | TCP      | 22   | My IP     | 只允许你的 IP SSH |
| Custom TCP | TCP | 8080 | 0.0.0.0/0 | CloudFront 转发后端请求 |

> 安全建议：8080 理想情况只对 CloudFront IP 开放，但入门阶段先开 0.0.0.0/0 更简单。

### 3.3 启动 EC2 实例

AWS Console → EC2 → Launch Instance

- **Name**: smart-invest-server
- **AMI**: Amazon Linux 2023（免费套餐可用）
- **Instance type**: t3.micro
- **Key pair**: 选刚才创建的 `smart-invest-key`
- **Security group**: 选 `smart-invest-sg`
- **Storage**: 默认 8GB 即可
- 点 **Launch instance**

启动后记下 **Public IPv4 address**（如 `54.12.34.56`）

### 3.4 在 EC2 上安装 Docker

```bash
# SSH 进入服务器
ssh -i ~/.ssh/smart-invest-key.pem ec2-user@54.12.34.56

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
sudo yum install -y awscli

# 退出并重新登录（使 docker 用户组生效）
exit
ssh -i ~/.ssh/smart-invest-key.pem ec2-user@54.12.34.56
docker --version   # 验证
```

### 3.5 给 EC2 赋予 ECR 和 Secrets Manager 权限

1. AWS Console → EC2 → 选中你的实例 → Actions → Security → **Modify IAM role**
2. 点 **Create new IAM role**
   - Trusted entity: EC2
   - 添加权限：`AmazonECR_FullAccess`、`SecretsManagerReadOnly`、`AmazonSESFullAccess`
   - Role name: `smart-invest-ec2-role`
3. 回到 Modify IAM role 页，选择 `smart-invest-ec2-role`，Save

---

## 第四步：AWS Secrets Manager 存储密钥

```bash
# 在本地执行（不是 EC2 上）

# 存储数据库密码
aws secretsmanager create-secret \
  --name "smart-invest/prod/db-password" \
  --secret-string "your-strong-db-password-here" \
  --region us-east-1

# 存储 JWT Secret（生成一个随机强密码）
aws secretsmanager create-secret \
  --name "smart-invest/prod/jwt-secret" \
  --secret-string "$(openssl rand -base64 64)" \
  --region us-east-1
```

> 记下你设置的数据库密码，第五步要用。

---

## 第五步：在 EC2 上配置 docker-compose

```bash
# SSH 进入 EC2
ssh -i ~/.ssh/smart-invest-key.pem ec2-user@54.12.34.56

# 创建项目目录
mkdir ~/smart-invest && cd ~/smart-invest

# 创建 .env 文件（存运行时环境变量）
cat > .env << 'EOF'
DB_PASSWORD=your-strong-db-password-here
JWT_SECRET=从Secrets Manager复制过来
AWS_REGION=us-east-1
ECR_REGISTRY=123456789.dkr.ecr.us-east-1.amazonaws.com
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
# backend/Dockerfile（放在 backend/ 目录下）
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY app/target/app-*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 第七步：创建 S3 Bucket（托管前端）

```bash
# 创建 bucket（名字全球唯一，换一个自己的名字）
aws s3api create-bucket \
  --bucket smart-invest-frontend-prod \
  --region us-east-1

# 关闭公开访问（通过 CloudFront 访问，不需要直接公开）
aws s3api put-public-access-block \
  --bucket smart-invest-frontend-prod \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

---

## 第八步：创建 CloudFront 分发

这一步在 AWS Console 操作更直观：

1. AWS Console → **CloudFront** → Create distribution

### 8.1 配置 S3 Origin（前端）

- **Origin domain**: 选择你的 S3 bucket
- **Origin access**: 选 **Origin access control settings (recommended)**
- 点 **Create new OAC**，默认设置即可 → Create
- 会提示你更新 S3 bucket policy，点 **Copy policy**，待会粘贴

**去 S3 更新 Bucket Policy**：
S3 → 你的 bucket → Permissions → Bucket policy → 粘贴刚才复制的 policy → Save

### 8.2 配置默认行为（前端）

- **Viewer protocol policy**: Redirect HTTP to HTTPS
- **Cache policy**: CachingOptimized

### 8.3 添加 EC2 Origin（后端）

创建完 distribution 后：Distribution → Origins → Create origin

- **Origin domain**: 输入你的 EC2 公网 IP（如 `54.12.34.56`）
- **Protocol**: HTTP only
- **HTTP port**: 8080

### 8.4 添加 /api/* 行为（路由到后端）

Distribution → Behaviors → Create behavior

- **Path pattern**: `/api/*`
- **Origin**: 选 EC2 origin
- **Viewer protocol policy**: HTTPS only
- **Cache policy**: CachingDisabled（API 不缓存！）
- **Origin request policy**: AllViewer

### 8.5 配置 SPA 路由（前端）

Distribution → Error pages → Create custom error response

- HTTP error code: 403 → Response page path: `/index.html` → HTTP response code: 200
- HTTP error code: 404 → Response page path: `/index.html` → HTTP response code: 200

> 这是因为 React Router 的前端路由（如 `/holdings`）直接访问会被 S3 返回 403/404，需要重定向到 `index.html`

### 8.6 记录 CloudFront 信息

- **Distribution domain name**（如 `d1abc123xyz.cloudfront.net`）：这就是你的公网 HTTPS 地址
- **Distribution ID**：后面 GitHub Actions 刷新缓存要用

---

## 第九步：配置前端 API 地址

在 `frontend/` 目录创建 `.env.production`：

```bash
VITE_API_BASE_URL=https://d1abc123xyz.cloudfront.net
```

（把域名换成你实际的 CloudFront 域名）

---

## 第十步：GitHub Actions CI/CD

在项目根目录创建以下文件：

### 10.1 配置 GitHub Secrets

GitHub 仓库 → Settings → Secrets and variables → Actions → New repository secret

| Secret 名称 | 值 |
|------------|-----|
| `AWS_ACCESS_KEY_ID` | IAM 用户的 Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | IAM 用户的 Secret Access Key |
| `AWS_REGION` | `us-east-1` |
| `ECR_REGISTRY` | `123456789.dkr.ecr.us-east-1.amazonaws.com` |
| `S3_BUCKET` | `smart-invest-frontend-prod` |
| `CF_DISTRIBUTION_ID` | CloudFront Distribution ID |
| `EC2_HOST` | EC2 公网 IP（如 `54.12.34.56`） |
| `EC2_SSH_KEY` | `smart-invest-key.pem` 的完整内容（cat 出来复制） |
| `DB_PASSWORD` | 你设置的数据库密码 |
| `JWT_SECRET` | 你设置的 JWT 密钥 |

### 10.2 前端 CI/CD

创建 `.github/workflows/deploy-frontend.yml`：

```yaml
name: Deploy Frontend

on:
  push:
    branches: [master]
    paths:
      - 'frontend/**'
      - '.github/workflows/deploy-frontend.yml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Build frontend
        working-directory: frontend
        run: |
          npm ci
          npm run build
        env:
          VITE_API_BASE_URL: https://${{ secrets.CF_DISTRIBUTION_DOMAIN }}

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Upload to S3
        run: aws s3 sync frontend/dist s3://${{ secrets.S3_BUCKET }} --delete

      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CF_DISTRIBUTION_ID }} \
            --paths "/*"
```

> **注意**：把 `CF_DISTRIBUTION_DOMAIN` 也加到 GitHub Secrets 里（CloudFront 域名，如 `d1abc123xyz.cloudfront.net`）

### 10.3 后端 CI/CD

创建 `.github/workflows/deploy-backend.yml`：

```yaml
name: Deploy Backend

on:
  push:
    branches: [master]
    paths:
      - 'backend/**'
      - 'Dockerfile'
      - '.github/workflows/deploy-backend.yml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build JAR
        working-directory: backend
        run: mvn package -DskipTests

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ secrets.ECR_REGISTRY }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -f backend/Dockerfile -t $ECR_REGISTRY/smart-invest:$IMAGE_TAG backend/
          docker push $ECR_REGISTRY/smart-invest:$IMAGE_TAG
          # 也打一个 latest 标签
          docker tag $ECR_REGISTRY/smart-invest:$IMAGE_TAG $ECR_REGISTRY/smart-invest:latest
          docker push $ECR_REGISTRY/smart-invest:latest

      - name: Deploy to EC2
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ec2-user
          key: ${{ secrets.EC2_SSH_KEY }}
          envs: ECR_REGISTRY,IMAGE_TAG
          script: |
            # 登录 ECR（EC2 有 IAM role，直接用）
            aws ecr get-login-password --region us-east-1 \
              | docker login --username AWS --password-stdin $ECR_REGISTRY

            # 拉取新镜像
            docker pull $ECR_REGISTRY/smart-invest:$IMAGE_TAG

            # 更新 .env 里的 IMAGE_TAG
            cd ~/smart-invest
            sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$IMAGE_TAG/" .env

            # 重启 app 容器（不重启 postgres）
            docker compose up -d app

            # 清理旧镜像（节省磁盘）
            docker image prune -f
        env:
          ECR_REGISTRY: ${{ secrets.ECR_REGISTRY }}
          IMAGE_TAG: ${{ github.sha }}
```

---

## 第十一步：第一次手动部署（验证流程）

在本地先执行一次完整流程，确认配置正确：

```bash
# 1. 打包后端 JAR
cd backend && mvn package -DskipTests

# 2. 构建 Docker 镜像
cd .. # 回到项目根
docker build -f backend/Dockerfile -t smart-invest:test backend/

# 3. 登录 ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

# 4. 推送镜像
docker tag smart-invest:test 123456789.dkr.ecr.us-east-1.amazonaws.com/smart-invest:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/smart-invest:latest

# 5. SSH 到 EC2，启动服务
ssh -i ~/.ssh/smart-invest-key.pem ec2-user@54.12.34.56
cd ~/smart-invest

# 先登录 ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f app
```

后端验证：
```bash
curl http://54.12.34.56:8080/actuator/health
# 期望返回: {"status":"UP"}
```

前端部署：
```bash
# 本地执行
cd frontend
VITE_API_BASE_URL=https://d1abc123xyz.cloudfront.net npm run build
aws s3 sync dist s3://smart-invest-frontend-prod --delete
aws cloudfront create-invalidation \
  --distribution-id EXXXXXXXXXXXX \
  --paths "/*"
```

然后访问 `https://d1abc123xyz.cloudfront.net` 验证。

---

## 常见问题排查

| 问题 | 排查方法 |
|------|---------|
| 后端 500 错误 | `docker compose logs app` 看 Spring Boot 日志 |
| 数据库连接失败 | 检查 `.env` 里密码是否正确；`docker compose ps` 确认 postgres 在运行 |
| 前端白屏 | 浏览器 Console 看错误；检查 `VITE_API_BASE_URL` 是否正确 |
| CloudFront 返回 403 | 检查 S3 Bucket Policy 是否已更新为允许 OAC 访问 |
| SSH 连接拒绝 | 检查 Security Group 的 22 端口是否对你的 IP 开放 |
| GitHub Actions 失败 | 检查 Secrets 是否全部配置；查看 Actions 日志 |

---

## 成本监控（必做）

1. AWS Console → **Billing** → **Budgets** → Create budget
2. 选 **Monthly cost budget**，设置 $15/月报警
3. 邮件通知：到达 80% 时发邮件提醒

---

## 架构总结

| 组件 | AWS 服务 | 作用 |
|------|---------|------|
| 前端托管 | S3 | 存储 React 构建产物 |
| CDN + HTTPS | CloudFront | 统一入口、HTTPS 终止、缓存 |
| 后端运行时 | EC2 t3.micro | 运行 Spring Boot + PostgreSQL |
| 镜像仓库 | ECR | 存储 Docker 镜像 |
| 密钥管理 | Secrets Manager | 存储 DB密码、JWT密钥 |
| 邮件服务 | SES | 发送通知邮件 |
| CI/CD | GitHub Actions | 自动构建和部署 |
