# AWS Deployment Plan C — ECS Fargate + RDS + Custom Domain (Startup Prototype)

**Audience**: 创业产品原型，具备一定 AWS 经验后使用  
**Goal**: 前后端数据库完全分离，有自定义域名和 HTTPS，架构可扩展  
**Estimated cost**: ~$50-70/month（视 Fargate 规格和流量）

---

## Architecture Overview

```
Developer (git push master)
        │
        ▼
  GitHub Actions
        ├── Frontend: build → S3 → CloudFront invalidation
        └── Backend: build JAR → docker build
                    → ECR push → ECS service update (force new deployment)

Internet
  └── Route 53 (smartinvest.com)
        ├── app.smartinvest.com  ──→ CloudFront (HTTPS, ACM cert)
        │                               ├── /*      → S3 (React 静态文件)
        │                               └── /api/*  → ALB (Application Load Balancer)
        │                                               └── ECS Fargate Service
        │                                                   (Spring Boot 容器)
        │
        └── (数据库不对外暴露，仅 Fargate 内网访问)

VPC (私有网络)
  ├── Public Subnet  (ALB, NAT Gateway)
  └── Private Subnet (ECS Fargate Task, RDS PostgreSQL)

辅助服务:
  AWS Secrets Manager  ← Fargate 容器启动时读取
  AWS SES              ← 邮件通知
  AWS ECR              ← Docker 镜像仓库
  AWS ACM              ← SSL/TLS 证书（免费）
```

---

## 与方案 A 的关键差异

| 维度 | 方案 A | 方案 C |
|------|--------|--------|
| 数据库 | PostgreSQL 容器（和应用同机） | RDS PostgreSQL（独立托管） |
| 后端运行 | EC2 上 docker-compose | ECS Fargate（无服务器容器） |
| 扩容方式 | 手动改机型 | ECS Service Auto Scaling |
| 数据库备份 | 手动 | RDS 自动快照 |
| 域名 | CloudFront 默认域名 | 自定义域名（需购买） |
| HTTPS | CloudFront 默认证书 | ACM 托管证书（免费） |
| 网络隔离 | 无（所有组件在同一机器） | VPC 私有子网隔离 |

---

## 第一步：购买域名

### 选项 1：通过 Route 53 购买（推荐，集成最简单）
AWS Console → Route 53 → Registered domains → Register domain

- 搜索你想要的域名（如 `smartinvest.io`）
- `.com` 约 $12/年，`.io` 约 $40/年，`.app` 约 $14/年
- 完成购买后 Route 53 自动创建 Hosted Zone

### 选项 2：第三方购买（Namecheap、GoDaddy 等）后转入
- 购买后在第三方管理后台将 Nameservers 改为 Route 53 提供的 NS 记录

---

## 第二步：申请 SSL/TLS 证书（ACM）

**重要**：CloudFront 只能使用 `us-east-1` 区域的 ACM 证书，必须在 us-east-1 申请。

```bash
# 在 us-east-1 申请证书
aws acm request-certificate \
  --domain-name "smartinvest.io" \
  --subject-alternative-names "*.smartinvest.io" \
  --validation-method DNS \
  --region us-east-1
```

验证步骤：
1. ACM Console → 找到刚申请的证书 → 展开域名 → 点 **Create records in Route 53**
2. 等待约 5 分钟证书状态变为 **Issued**
3. 记下证书 ARN（后面 CloudFront 要用）

---

## 第三步：创建 VPC 网络

使用 VPC Console 向导，最简单：

AWS Console → VPC → Create VPC → 选 **VPC and more**

- Name: `smart-invest-vpc`
- IPv4 CIDR: `10.0.0.0/16`
- Availability Zones: **2**（两个 AZ，高可用）
- Public subnets: 2
- Private subnets: 2
- NAT Gateway: **1 per AZ** → 改为 **In 1 AZ**（节省成本）
- VPC endpoints: None

记下：
- VPC ID
- Public Subnet IDs（2 个）
- Private Subnet IDs（2 个）

---

## 第四步：创建 RDS PostgreSQL

### 4.1 创建 DB Subnet Group

RDS Console → Subnet groups → Create DB subnet group

- Name: `smart-invest-db-subnet`
- VPC: 选你的 VPC
- Subnets: 选两个 **Private** subnet

### 4.2 创建 Security Group（RDS 专用）

EC2 Console → Security Groups → Create

- Name: `smart-invest-rds-sg`
- Inbound rule: PostgreSQL (5432) from `smart-invest-ecs-sg`（先创建 ECS SG 再回来填，或暂时填 VPC CIDR `10.0.0.0/16`）

### 4.3 创建 RDS 实例

RDS Console → Create database

- **Engine**: PostgreSQL 16
- **Template**: Free tier（如有积分）或 Dev/Test
- **DB instance identifier**: `smart-invest-db`
- **Master username**: `smartadmin`
- **Master password**: 生成强密码，存入 Secrets Manager
- **Instance type**: db.t3.micro
- **Storage**: 20 GB gp3
- **VPC**: 选你的 VPC
- **DB Subnet group**: `smart-invest-db-subnet`
- **Public access**: **No**（重要：数据库不对外暴露）
- **VPC security group**: `smart-invest-rds-sg`
- **Database name**: `smartinvest`

> 创建需要 5-10 分钟，记下 Endpoint（如 `smart-invest-db.xxx.us-east-1.rds.amazonaws.com`）

### 4.4 存储 RDS 密码到 Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "smart-invest/prod/db-password" \
  --secret-string "你设置的RDS密码" \
  --region us-east-1

aws secretsmanager create-secret \
  --name "smart-invest/prod/jwt-secret" \
  --secret-string "$(openssl rand -base64 64)" \
  --region us-east-1
```

---

## 第五步：创建 ECR 仓库

```bash
aws ecr create-repository \
  --repository-name smart-invest \
  --region us-east-1
```

---

## 第六步：创建 ECS 集群和任务定义

### 6.1 创建 ECS Cluster

```bash
aws ecs create-cluster \
  --cluster-name smart-invest-cluster \
  --capacity-providers FARGATE \
  --region us-east-1
```

### 6.2 创建 ECS Task Execution Role（IAM）

ECS 容器需要这个 Role 才能拉取 ECR 镜像和读取 Secrets Manager：

```bash
# 创建 trust policy
cat > ecs-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ecs-tasks.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# 创建 role
aws iam create-role \
  --role-name smart-invest-ecs-task-role \
  --assume-role-policy-document file://ecs-trust-policy.json

# 附加权限
aws iam attach-role-policy \
  --role-name smart-invest-ecs-task-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy \
  --role-name smart-invest-ecs-task-role \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite

aws iam attach-role-policy \
  --role-name smart-invest-ecs-task-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess
```

### 6.3 创建 Task Definition

创建文件 `ecs-task-definition.json`（存到项目 `infra/` 目录）：

```json
{
  "family": "smart-invest-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789:role/smart-invest-ecs-task-role",
  "taskRoleArn": "arn:aws:iam::123456789:role/smart-invest-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "smart-invest-app",
      "image": "123456789.dkr.ecr.us-east-1.amazonaws.com/smart-invest:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "SPRING_PROFILES_ACTIVE", "value": "prod"},
        {"name": "AWS_REGION", "value": "us-east-1"},
        {
          "name": "SPRING_DATASOURCE_URL",
          "value": "jdbc:postgresql://smart-invest-db.xxx.us-east-1.rds.amazonaws.com:5432/smartinvest"
        },
        {"name": "SPRING_DATASOURCE_USERNAME", "value": "smartadmin"}
      ],
      "secrets": [
        {
          "name": "SPRING_DATASOURCE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:smart-invest/prod/db-password"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:smart-invest/prod/jwt-secret"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/smart-invest",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

```bash
# 注册 Task Definition
aws ecs register-task-definition \
  --cli-input-json file://infra/ecs-task-definition.json \
  --region us-east-1

# 创建 CloudWatch 日志组
aws logs create-log-group \
  --log-group-name /ecs/smart-invest \
  --region us-east-1
```

---

## 第七步：创建 ALB（应用负载均衡器）

### 7.1 创建 ALB Security Group

```
Name: smart-invest-alb-sg
Inbound: HTTP 80 from 0.0.0.0/0 (CloudFront 转发)
         HTTPS 443 from 0.0.0.0/0
```

### 7.2 创建 ECS Security Group

```
Name: smart-invest-ecs-sg
Inbound: TCP 8080 from smart-invest-alb-sg
```

（同时把这个 SG 加到 RDS Security Group 的入站规则里）

### 7.3 创建 ALB

EC2 Console → Load Balancers → Create → Application Load Balancer

- **Name**: smart-invest-alb
- **Scheme**: Internet-facing
- **VPC**: 你的 VPC
- **Subnets**: 两个 **Public** subnet
- **Security group**: `smart-invest-alb-sg`
- **Listener**: HTTP:80（先创建，后面配 HTTPS）
- **Target group**: 新建
  - Type: IP
  - Name: `smart-invest-tg`
  - Protocol: HTTP, Port: 8080
  - Health check path: `/actuator/health`

记下 ALB DNS 名称（如 `smart-invest-alb-xxx.us-east-1.elb.amazonaws.com`）

---

## 第八步：创建 ECS Service

```bash
aws ecs create-service \
  --cluster smart-invest-cluster \
  --service-name smart-invest-backend \
  --task-definition smart-invest-backend:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-private-1,subnet-private-2],
    securityGroups=[sg-ecs-id],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=smart-invest-app,containerPort=8080" \
  --region us-east-1
```

---

## 第九步：创建 S3 + CloudFront

前端 S3 配置与方案 A 相同。

CloudFront 额外配置（对比方案 A）：

- **Alternate domain names (CNAME)**: `app.smartinvest.io`
- **Custom SSL certificate**: 选择 ACM 中 Issued 的证书

---

## 第十步：Route 53 DNS 配置

Route 53 → Hosted zones → 你的域名 → Create record

```
Record 1:
  Name: app
  Type: A
  Alias: Yes → CloudFront distribution → 选你的 distribution

Record 2 (可选，后端直连调试用，生产不开):
  不需要，后端通过 CloudFront /api/* 路由访问
```

---

## 第十一步：GitHub Actions CI/CD

### 前端（与方案 A 相同，只是 VITE_API_BASE_URL 改为自定义域名）

```yaml
VITE_API_BASE_URL: https://app.smartinvest.io
```

### 后端（ECS 部署替换 SSH 部署）

```yaml
- name: Deploy to ECS
  run: |
    aws ecs update-service \
      --cluster smart-invest-cluster \
      --service smart-invest-backend \
      --task-definition smart-invest-backend \
      --force-new-deployment \
      --region us-east-1

    # 等待部署完成
    aws ecs wait services-stable \
      --cluster smart-invest-cluster \
      --services smart-invest-backend \
      --region us-east-1
```

---

## 数据库初始化（Flyway）

Spring Boot 启动时 Flyway 会自动执行 `db/migration` 下的 SQL。  
但第一次需要确保 RDS 内网可达（可通过 EC2 bastion 或 RDS Proxy 执行初始 DDL 验证）。

---

## 成本明细（月估算）

| 服务 | 规格 | 月费 |
|------|------|------|
| ECS Fargate | 0.5 vCPU / 1GB, 24h/day | ~$15 |
| RDS PostgreSQL | db.t3.micro, 20GB gp3 | ~$15 |
| ALB | 每月固定 + LCU | ~$16 |
| S3 + CloudFront | 低流量 | ~$1 |
| Route 53 | Hosted Zone + queries | ~$1 |
| NAT Gateway | 1个 | ~$4 |
| **合计** | | **~$52/month** |

---

## 架构总结

| 组件 | AWS 服务 | 作用 |
|------|---------|------|
| DNS | Route 53 | 域名解析 |
| SSL 证书 | ACM | 免费托管 HTTPS 证书 |
| CDN + 前端托管 | CloudFront + S3 | 静态文件分发 |
| 后端路由 | ALB | 负载均衡，健康检查 |
| 后端运行 | ECS Fargate | 无服务器容器，可自动扩缩 |
| 数据库 | RDS PostgreSQL | 托管数据库，自动备份 |
| 镜像仓库 | ECR | Docker 镜像存储 |
| 密钥管理 | Secrets Manager | 安全存储密钥，Fargate 启动时注入 |
| 邮件 | SES | 通知邮件 |
| 日志 | CloudWatch Logs | 容器日志集中存储 |
| 网络隔离 | VPC Private Subnet | 数据库和容器不直接对外暴露 |
| CI/CD | GitHub Actions | 自动构建和部署 |
