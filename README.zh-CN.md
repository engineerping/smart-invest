# 🚀 Smart Invest — 基于 AWS + K3S 的全栈投资平台

> **DevOps 技术实力展示：Terraform 管理 AWS 基础设施 + Helm 部署微服务到 K3S**

[![Java](https://img.shields.io/badge/Java-21-orange)](https://openjdk.org/projects/jdk/21/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.3-brightgreen)](https://spring.io/projects/spring-boot)
[![React](https://img.shields.io/badge/React-18-61DAFB)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6)](https://www.typescriptlang.org/)
[![K3S](https://img.shields.io/badge/K3S-v1.36-FFC107)](https://k3s.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.9+-844FBA)](https://www.terraform.io/)
[![Helm](https://img.shields.io/badge/Helm-3.x-0F1689)](https://helm.sh/)
[![AWS](https://img.shields.io/badge/AWS-ap--southeast--1-FF9900)](https://aws.amazon.com/)

---

## 📋 目录

- [部署架构](#-部署架构)
- [使用的 AWS 服务](#-使用的-aws-服务)
- [基础设施即代码 (Terraform)](#-基础设施即代码-terraform)
- [应用部署 (Helm)](#-应用部署-helm)
- [技术栈](#-技术栈)
- [项目结构](#-项目结构)
- [微服务概览](#-微服务概览)
- [部署流程](#-部署流程)
- [本地开发](#-本地开发)
- [演示账号](#-演示账号)

---

## 🏗 部署架构

Smart Invest 部署在 **AWS EC2 单节点上运行 K3S**（轻量级 Kubernetes），前端通过 **CloudFront CDN + S3** 实现全球加速访问。所有有状态中间件（PostgreSQL、RabbitMQ）均以 K3S 工作负载方式运行——**零依赖 AWS 托管服务**（不购买 RDS、Amazon MQ、ElastiCache），将成本控制在最低水平。

```
                              ┌─────────────────────────────────────────────────────┐
                              │                    AWS Cloud                         │
                              │                                                     │
  🌍 全球用户                  │  ┌──────────────────────────────────────────────┐   │
      │                       │  │             CloudFront CDN                    │   │
      ▼                       │  │  ┌─────────────────────────────────────────┐ │   │
┌──────────┐                  │  │  │          WAF (Web ACL)                   │ │   │
│  HTTPS   │                  │  │  │    SQL 注入 / XSS / 频率限制             │ │   │
└────┬─────┘                  │  │  └────────────┬────────────────────────────┘ │   │
     │                        │  │               │                               │   │
     │                        │  └───────────────┼───────────────────────────────┘   │
     │                        │                  │                                   │
     │         ┌──────────────┼──────────────────┼──────────────────┐               │
     │         │              │                  │                  │               │
     │         ▼              │                  ▼                  │               │
     │   ┌──────────┐         │  ┌──────────────────────────────┐  │               │
     │   │   S3     │         │  │      EC2 (t3.medium)         │  │               │
     │   │  静态资源 │         │  │    ap-southeast-1 (新加坡)   │  │               │
     │   │  存储    │         │  │  ┌────────────────────────┐  │  │               │
     │   └──────────┘         │  │  │   K3S (Kubernetes)     │  │  │               │
     │                        │  │  │                        │  │  │               │
     │   /assets/* → S3       │  │  │  ┌──────────────────┐  │  │  │               │
     │   /*        → S3       │  │  │  │ Traefik Ingress  │  │  │  │               │
     │                        │  │  │  │  (K3S 内置)      │  │  │  │               │
     │                        │  │  │  └────────┬─────────┘  │  │  │               │
     │                        │  │  │           │             │  │  │               │
     │                        │  │  │  ┌────────┴─────────┐  │  │  │               │
     │   /api/* ──────────────┼──┼──┼─→│  API Gateway     │  │  │  │               │
     │                        │  │  │  │  (Spring Cloud)  │  │  │  │               │
     │                        │  │  │  │  端口 8080       │  │  │  │               │
     │                        │  │  │  └──┬──┬──┬──┬─────┘  │  │  │               │
     │                        │  │  │     │  │  │  │         │  │  │               │
     │                        │  │  │  ┌──┘  │  │  └─────────┐  │  │               │
     │                        │  │  │  │     │  │            │  │  │               │
     │                        │  │  │  ▼     ▼  ▼            ▼  │  │               │
     │                        │  │  │ ┌────┐┌────┐┌────┐┌────┐│  │               │
     │                        │  │  │ │用户││基金││订单││通知││  │               │
     │                        │  │  │ │服务││服务││服务││Worker││  │               │
     │                        │  │  │ │8081││8082││8083││8084││  │               │
     │                        │  │  │ └────┘└──┬─┘└──┬─┘└────┘│  │               │
     │                        │  │  │         │     │         │  │               │
     │                        │  │  │         ▼     ▼         │  │               │
     │                        │  │  │  ┌────────┐ ┌────────┐  │  │               │
     │                        │  │  │  │PostgreSQL│RabbitMQ │  │  │               │
     │                        │  │  │  │(Stateful│(Deploy  │  │  │               │
     │                        │  │  │  │ Set+PVC)│ +PVC)   │  │  │               │
     │                        │  │  │  └────────┘ └────────┘  │  │               │
     │                        │  │  │                        │  │  │               │
     │                        │  │  └────────────────────────┘  │  │               │
     │                        │  │                             │  │               │
     │                        │  │  ┌──────────────────────┐   │  │               │
     │                        │  │  │ IAM Role             │   │  │               │
     │                        │  │  │ ├─ SES (邮件发送)    │   │  │               │
     │                        │  │  │ ├─ ECR (镜像仓库)    │   │  │               │
     │                        │  │  │ └─ Secrets Manager   │   │  │               │
     │                        │  │  └──────────────────────┘   │  │               │
     │                        │  └──────────────────────────────┘  │               │
     │                        │                                     │               │
     │                        └─────────────────────────────────────┘               │
     └─────────────────────────────────────────────────────────────────────────────┘
```

### 数据流

| 路径匹配 | 路由 | 说明 |
|-------------|-------|------|
| `/assets/*`, `/`, `*.html` | **S3** | 前端静态资源（React SPA），通过 CloudFront CDN 分发 |
| `/api/*` | **EC2 → Traefik → API Gateway** | 所有后端 API 请求，经 K3S Ingress 代理到 API 网关 |

### 关键架构决策

| 决策 | 理由 |
|----------|-----------|
| **单 EC2 + K3S** vs EKS | 成本优化（~$35/月 vs EKS 控制面单独 $73+/月）；K3S 是生产级轻量 Kubernetes |
| **自托管 DB/MQ** vs RDS/AmazonMQ | 所有中间件以 K3S 工作负载 + PVC 持久化运行——零托管服务成本 |
| **CloudFront + S3** 托管前端 | 全球边缘缓存（450+ 节点），免费套餐包含 1TB/月传输，天然支持 SPA 路由 |
| **Umbrella Helm Chart** | 一条命令部署 9 个组件；每个子 Chart 独立版本管理和升级 |
| **IAM Role** 而非 Access Key | EC2 通过 Instance Profile 获取临时凭证——代码中无密钥，自动轮换 |

---

## ☁️ 使用的 AWS 服务

| 服务 | 用途 | 选型理由 |
|---------|---------|------------------|
| **EC2** (t3.medium) | K3S 计算节点——运行所有微服务+中间件 | 可突发实例，2vCPU/4GB 内存，适合中等负载 |
| **Elastic IP** | EC2 固定公网 IPv4 地址 | IP 重启不变——对 CloudFront 回源和 DNS 配置至关重要 |
| **S3** | 前端静态资源存储 | 高持久性、弹性扩展、免费套餐 5GB，与 CloudFront 原生集成 |
| **CloudFront** | 全球 CDN + HTTPS 终结 | 边缘缓存（450+ 节点），免费套餐 1TB/月，SPA 自定义错误页面 |
| **WAF** (Web ACL) | Web 应用防火墙 | SQL 注入防护、XSS 防护、频率限制——附加到 CloudFront，无额外费用 |
| **IAM** (Role + Policies) | EC2 身份与权限管理 | Instance Profile 授予 EC2 访问 SES、ECR、Secrets Manager 的权限——无硬编码密钥 |
| **Security Groups** | EC2 有状态防火墙 | 限制入站规则：HTTP(80)、SSH(22)、K3S API(6443) |
| **CloudWatch** | 基础设施指标（CPU、磁盘、网络） | EC2 内置指标，5 分钟粒度——无需安装 Agent |
| **SES** | 邮件通知（预留） | IAM 策略已绑定——需要时即可发送事务邮件 |
| **Secrets Manager** | 密钥存储（预留） | IAM 策略已绑定——用于数据库密码、API Key 轮换 |

---

## 🏗 基础设施即代码 (Terraform)

所有 AWS 资源均由 Terraform 声明式管理和编排。配置遵循 **live/modules** 模式——`live/` 中的环境实例调用 `modules/` 中的可复用模块。

### Terraform 管理的云资源

| 模块 | 资源 | 关键配置 |
|--------|-----------|-------------------|
| **networking** | `aws_security_group`, `aws_vpc` (data), `aws_subnet` (data) | 入站规则 HTTP:80、SSH:22、K3S API:6443 |
| **compute** | `aws_instance`, `aws_eip` | t3.medium，30GB gp3 EBS，Amazon Linux 2023，绑定 EIP |
| **iam** | `aws_iam_role`, `aws_iam_instance_profile`, `aws_iam_role_policy_attachment` × 3 | SES 完全访问、ECR 完全访问、SecretsManager 读写 |
| **cdn** | `aws_s3_bucket`, `aws_cloudfront_distribution`, `aws_cloudfront_origin_access_control`, `aws_s3_bucket_policy` | OAC 鉴权（S3 不公开），双源站（S3 + EC2），SPA 容错路由，WAF 关联 |

### Terraform 项目结构

```
infrastructure/terraform/
├── live/prod/                  # 生产环境
│   ├── main.tf                 # Terraform 核心 + AWS Provider（ap-southeast-1 + us-east-1）
│   ├── root.tf                 # 根模块——编排所有子模块（DAG 依赖图）
│   ├── variables.tf            # 输入变量（含默认值）
│   ├── outputs.tf              # 输出值（EC2 IP、CloudFront 域名、S3 桶名）
│   └── terraform.tfvars        # 实际配置值
└── modules/                    # 可复用 Terraform 模块
    ├── networking/             # 安全组、VPC/子网查询
    ├── compute/                # EC2 实例 + 弹性 IP
    ├── iam/                    # IAM 角色、策略、Instance Profile
    └── cdn/                    # S3 存储桶、CloudFront 分发、WAF
```

### Terraform 输出（部署后）

| 输出变量 | 示例值 |
|--------|--------------|
| `ec2_public_ip` | `46.137.250.243` |
| `ec2_ssh_command` | `ssh ec2-user@46.137.250.243` |
| `cloudfront_domain` | `d2hoqnqufe8qq0.cloudfront.net` |
| `s3_bucket_name` | `smart-invest-frontend-service-prod-bucket-name` |
| `website_url` | `https://d2hoqnqufe8qq0.cloudfront.net` |

---

## ⎈ 应用部署 (Helm)

所有应用工作负载通过**单个 Umbrella Helm Chart** 一键部署到 K3S——一条命令拉起整个系统。

### Helm 部署的服务（Umbrella Chart）

| Chart | 类型 | 工作负载 | 端口 | 镜像 |
|-------|------|----------|------|-------|
| **api-gateway** | 微服务（自写） | Deployment（2 副本） | 8080 | `gongchengship/smart-invest-api-gateway` |
| **user-service** | 微服务（自写） | Deployment（2 副本） | 8081 | `gongchengship/smart-invest-user-service` |
| **fund-service** | 微服务（自写） | Deployment（2 副本） | 8082 | `gongchengship/smart-invest-fund-service` |
| **order-service** | 微服务（自写） | Deployment（2 副本） | 8083 | `gongchengship/smart-invest-order-service` |
| **notification-worker** | 后台 Worker（自写） | Deployment（2 副本） | 8084 | `gongchengship/smart-invest-notification-worker` |
| **frontend** | SPA（自写） | Deployment（2 副本） | 80 | `gongchengship/smart-invest-frontend` |
| **postgresql** | 数据库（自写） | StatefulSet（1 副本） | 5432 | `postgres:16-alpine` |
| **rabbitmq** | 消息队列（自写） | Deployment（1 副本） | 5672/15672 | `rabbitmq:3.13-management-alpine` |
| **redis** | 缓存（Bitnami） | Deployment — _默认关闭_ | 6379 | `bitnami/redis` |

### Helm 项目结构

```
infrastructure/helm/
├── charts/                          # 9 个子 Chart（均可独立部署）
│   ├── api-gateway/                 # Spring Cloud Gateway
│   ├── user-service/                # 认证 + 用户管理
│   ├── fund-service/                # 基金数据 + 投资组合
│   ├── order-service/               # 订单 + 结算
│   ├── notification-worker/         # 异步通知消费者
│   ├── frontend/                    # React SPA (nginx)
│   ├── postgresql/                  # StatefulSet + Headless Service + PVC
│   ├── rabbitmq/                    # Deployment + PVC + ClusterIP
│   └── redis/                       # Deployment + PVC（可选，Bitnami）
└── umbrella/                        # 聚合 Chart（一键部署全家桶）
    ├── Chart.yaml                   # 声明 9 个依赖
    ├── values.yaml                  # 默认配置
    ├── values-prod.yaml             # 生产环境覆盖配置（2 副本、1.1.0 镜像标签）
    └── templates/
        ├── ingress.yaml             # Traefik 路由（/ → 前端，/api → 网关）
        ├── secret.yaml              # K8S Secret（数据库密码、JWT 密钥、RabbitMQ 密码）
        └── rabbitmq-ready-hook.yaml # 预安装 Hook：等待 RabbitMQ 就绪
```

### K3S 内部服务发现

| 服务 | 集群 DNS |
|---------|------------|
| PostgreSQL | `postgresql.smart-invest.svc.cluster.local:5432` |
| RabbitMQ | `rabbitmq.smart-invest.svc.cluster.local:5672` |
| API Gateway | `api-gateway.smart-invest.svc.cluster.local:8080` |
| User Service | `user-service.smart-invest.svc.cluster.local:8081` |
| Fund Service | `fund-service.smart-invest.svc.cluster.local:8082` |
| Order Service | `order-service.smart-invest.svc.cluster.local:8083` |

---

## 💻 技术栈

### 后端（微服务）

| 技术 | 版本 | 用途 |
|-----------|---------|---------|
| **Java** | 21 | 运行时——虚拟线程、模式匹配、密封类 |
| **Spring Boot** | 3.3 | 应用框架——自动配置、Actuator、Validation |
| **Spring Cloud Gateway** | 2023.x | API 网关——路由转发、JWT 认证、限流 |
| **Spring Data JPA** | 3.3 | ORM——实体映射、Repository 模式、懒加载 |
| **Spring AMQP** | 3.3 | RabbitMQ 集成——服务间异步消息 |
| **Flyway** | 10.x | 数据库迁移——17 个版本化 SQL 迁移脚本 + 种子数据 |
| **PostgreSQL** | 16 | 关系数据库——ACID 事务、JSONB、全文搜索 |
| **RabbitMQ** | 3.13 | 消息代理——订单事件、结算通知 |
| **JWT (RS256)** | — | 认证——非对称签名、无状态会话 |
| **JUnit 5 + Mockito** | 5.x | 测试——单元测试、集成测试、Mock Bean |

### 前端（SPA）

| 技术 | 版本 | 用途 |
|-----------|---------|---------|
| **React** | 18 | UI 库——并发特性、Hooks、Suspense |
| **TypeScript** | 5.x | 类型安全——接口、泛型、严格模式 |
| **Vite** | 5.x | 构建工具——即时 HMR、ESBuild、Rollup |
| **Tailwind CSS** | 3.x | 原子化 CSS——响应式移动端优先设计 |
| **React Router** | 6.x | 客户端路由——懒加载、路由守卫 |
| **TanStack Query** | 5.x | 服务端状态——缓存、重取、乐观更新 |
| **Axios** | 1.x | HTTP 客户端——拦截器、请求/响应转换 |
| **i18next** | 24.x | 国际化——支持 en-US、zh-CN |

### DevOps & 基础设施

| 技术 | 版本 | 用途 |
|-----------|---------|---------|
| **Terraform** | 1.9+ | 基础设施即代码——声明式管理 AWS 资源 |
| **Helm** | 3.x | Kubernetes 包管理器——模板化部署、Umbrella Chart |
| **K3S** | v1.36 | 轻量级 Kubernetes——单二进制，内置 Traefik + CoreDNS |
| **Docker** | 29.x | 容器运行时——多阶段构建、基于 Alpine 的精简镜像 |
| **containerd** | 2.3 | K3S 容器运行时——ctr/crictl 镜像管理 |
| **GitHub Actions** | — | CI/CD——构建、测试、部署流水线（计划中） |
| **AWS CloudWatch** | — | 监控——EC2 指标、日志、告警 |

---

## 📁 项目结构

```
smart-invest/
├── backend/                              # Java 微服务（Maven 多模块）
│   ├── pom.xml                           # 父 POM（Spring Boot 3.3, Java 21）
│   ├── common/                           # 共享库（DTO、事件、JWT、安全）
│   ├── api-gateway/                      # Spring Cloud Gateway（端口 8080）
│   ├── user-service/                     # 用户 + 认证服务（端口 8081）
│   ├── fund-service/                     # 基金 + 组合服务（端口 8082）
│   ├── order-service/                    # 订单 + 结算服务（端口 8083）
│   └── notification-worker/              # 异步通知消费者（端口 8084）
│
├── frontend/                             # React SPA（TypeScript + Vite）
│   ├── src/pages/                        # 路由页面（认证、基金、持仓、组合、计划）
│   ├── src/components/                   # 可复用 UI 组件
│   ├── Dockerfile                        # 多阶段构建（nginx + dist）
│   └── nginx.conf                        # SPA 友好 nginx 配置
│
├── infrastructure/                       # 🔧 DevOps 核心——IaC + Helm
│   ├── terraform/                        # Terraform IaC
│   │   ├── live/prod/                    # 生产环境实例
│   │   └── modules/                      # 可复用模块（networking, compute, iam, cdn）
│   └── helm/                             # Helm Charts
│       ├── charts/                       # 9 个子 Chart（6 个微服务 + 3 个中间件）
│       └── umbrella/                     # 聚合 Chart（一键部署）
│
├── scripts/                              # 运维脚本
│   ├── deploy.sh                         # 完整部署编排
│   ├── deploy-k3s.sh                     # K3S 安装
│   ├── build-images.sh                   # Docker 镜像构建
│   ├── build-amd64.sh                    # 跨架构构建（arm64 → amd64）
│   ├── deploy-monitoring.sh              # Prometheus + Grafana 部署
│   ├── deploy-rabbitmq.sh                # RabbitMQ 独立部署
│   ├── cloudwatch-setup.sh               # CloudWatch Agent + 告警
│   └── k3s-dashboard-token.sh            # K3S Dashboard 访问 Token
│
├── docs/                                 # 架构与设计文档
│   ├── what was build.md                 # 项目功能文档
│   └── superpowers/specs/                # 架构规格与计划
│
├── doc-K8S/                              # Kubernetes 学习笔记
├── doc-design/                           # 产品设计与分析文档
└── doc-manually/                         # 手动操作指南
```

---

## 🔬 微服务概览

### 服务间通信

```
                    ┌─────────────┐
                    │  Frontend   │  React SPA（浏览器）
                    │  (nginx)    │
                    └──────┬──────┘
                           │ HTTP /api/*
                           ▼
                    ┌─────────────┐
                    │ API Gateway │  Spring Cloud Gateway
                    │  端口 8080  │  ├─ JWT 认证
                    └──┬──┬──┬───┘  ├─ 路由转发
                       │  │  │      └─ 限流
          ┌────────────┘  │  └────────────┐
          ▼               ▼               ▼
   ┌──────────┐   ┌──────────────┐   ┌──────────┐
   │  用户    │   │  基金        │   │  订单    │
   │  服务    │   │  服务        │   │  服务    │
   │  :8081   │   │  :8082       │   │  :8083   │
   └────┬─────┘   └──────┬───────┘   └────┬─────┘
        │                │                │
        │         ┌──────┘       ┌────────┘
        │         │              │
        ▼         ▼              ▼         RabbitMQ (AMQP)
   ┌────────┐         ┌─────────────┐         │
   │PostgreSQL│       │  RabbitMQ   │◄────────┘
   │  :5432  │       │  :5672      │
   └────────┘         └──────┬──────┘
                                    │ 消费
                                    ▼
                            ┌──────────────┐
                            │  通知 Worker │  异步消费者
                            │  端口 8084   │  邮件通知
                            └──────────────┘
```

### 服务边界

| 服务 | 职责 | 核心依赖 |
|---------|-----------------|------------------|
| **API Gateway** | 请求路由、JWT 校验、限流 | 所有下游服务 |
| **User Service** | 注册、登录、JWT 签发、风险评估 | PostgreSQL |
| **Fund Service** | 基金 CRUD、净值历史、投资组合、定投计划 | PostgreSQL、Order Service (REST) |
| **Order Service** | 申购/赎回订单、T+2 结算调度 | PostgreSQL、RabbitMQ（发布） |
| **Notification Worker** | 消费订单事件、发送邮件通知 | RabbitMQ（消费）、SES |
| **PostgreSQL** | 关系数据——15 张表、17 个 Flyway 迁移脚本 | PVC（持久化存储） |
| **RabbitMQ** | 异步消息——订单创建、结算完成 | PVC（持久化存储） |

---

## 🚀 部署流程

### 三机三角色架构

```
┌─────────────────┐      ┌──────────────────────┐      ┌──────────────────────┐
│  Mac (arm64)    │      │  Ubuntu (x86_64)      │      │  AWS EC2 (x86_64)    │
│  开发机          │      │  镜像构建机            │      │  K3S 运行时          │
│                 │      │                       │      │                      │
│  • Terraform    │      │  • Docker build       │      │  • K3S (containerd)  │
│  • Helm (CLI)   │ rsync│  • docker save        │ scp  │  • ctr image import  │
│  • Maven (jar)  │─────►│    (amd64 镜像)       │─────►│  • Helm install       │
│  • npm (dist)   │ scp  │                       │      │  • PostgreSQL/RabbitMQ│
│  • git          │      │                       │      │  • Traefik Ingress   │
└─────────────────┘      └──────────────────────┘      └──────────────────────┘
```

### 完整部署步骤

```bash
# 1. Terraform：管理 AWS 基础设施
cd infrastructure/terraform/live/prod
terraform init && terraform plan && terraform apply

# 2. 构建：编译 Java + 前端（Mac）
cd backend && mvn -q -pl common,user-service,fund-service,order-service,notification-worker,api-gateway -am package -DskipTests
cd frontend && npm run build

# 3. 同步：传输到 x86_64 构建机
rsync -avz --exclude 'node_modules' --exclude 'target' --exclude '.terraform' \
  ~/coding/smart-invest/ builder@192.168.x.x:~/coding/smart-invest/

# 4. 打包：构建 Docker 镜像（Ubuntu x86_64）
for svc in user-service fund-service order-service notification-worker api-gateway frontend; do
  docker build --platform linux/amd64 -t gongchengship/smart-invest-$svc:1.0.0 .
done

# 5. 传输：SCP 镜像到 EC2
docker save gongchengship/smart-invest-* -o /tmp/images.tar
scp -i key.pem /tmp/images.tar ec2-user@<EC2_IP>:/tmp/
ssh ec2-user@<EC2_IP> "sudo k3s ctr image import /tmp/images.tar"

# 6. 部署：Helm 部署到 K3S
cd infrastructure/helm/umbrella
helm dependency update
helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --atomic --timeout 600s

# 7. 发布：前端上传 S3 + 刷新 CloudFront
aws s3 sync frontend/dist/ s3://<bucket>/ --delete
aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"

# 8. 验证
curl https://d2hoqnqufe8qq0.cloudfront.net/api/actuator/health
```

---

## 🛠 本地开发

### 环境要求

- Java 21 + Maven 3.9+
- Node.js 20 + npm 10+
- Docker（运行 PostgreSQL + RabbitMQ）
- Terraform 1.9+
- Helm 3.x
- kubectl（指向 K3S 集群配置）

### 快速启动（后端 + 前端）

```bash
# 终端 1：启动基础设施（Docker）
docker run -d --name postgres -p 5432:5432 \
  -e POSTGRES_DB=smartinvest -e POSTGRES_USER=smartadmin -e POSTGRES_PASSWORD=localdev_only \
  postgres:16-alpine

# 终端 2：启动后端
cd backend
mvn -pl app spring-boot:run
# 应用运行在 http://localhost:8080

# 终端 3：启动前端
cd frontend
npm install && npm run dev
# 开发服务器运行在 http://localhost:5173
```

---

## 🔑 演示账号

| 字段 | 值 |
|-------|-------|
| **URL** | `https://d2hoqnqufe8qq0.cloudfront.net` |
| **邮箱** | `demo@smartinvest.com` |
| **密码** | `Demo1234!` |


