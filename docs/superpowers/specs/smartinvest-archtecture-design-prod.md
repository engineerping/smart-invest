# Smart Invest — 生产环境架构设计文档

**版本**: 1.0
**日期**: 2026-04-08
**阶段**: 生产环境（Enterprise Production）
**设计原则**: 金融级安全 > 服务弹性 > 合规可审计 > 成本优化
**目标认证对齐**: AWS Certified Solutions Architect – Professional (SAP-C02)
**参考文档**: SmartInvest_ProjectRoadmap_v3.md · 2026-04-08-aws-deployment-plan-d.md

---

## 一、4C 架构模型（4C Models）

4C 架构模型从概念（Concept）、内容（Contents）、上下文（Context）和连接（Connections）四个维度描述系统。本生产环境设计以金融级安全、合规可审计、弹性伸缩为核心目标，全面遵循 AWS Well-Architected Framework 五大支柱及金融行业监管要求。

### 1.1 Concept（概念）— 系统愿景与目标

**产品定位**

Smart Invest 是一款面向个人投资者的基金投资平台（Mobile Web），在生产环境中承载真实金融交易数据，需满足香港证券及期货事务监察委员会（SFC）对零售基金投资平台的数据安全、交易可追溯和系统可用性要求。

**核心价值主张（生产环境维度）**

- **合规交易保障**：所有订单实时记录，审计日志不可篡改，满足 SFC 对电子交易平台的要求
- **资金安全**：Aurora PostgreSQL 金融级数据持久化，多可用区（Multi-AZ）保障 RPO = 0
- **系统弹性**：EKS 自动伸缩应对市场波动（交易时段高峰），夜间低谷自动缩容降低成本
- **全链路可观测**：Prometheus + Grafana + X-Ray 实现 RED Metrics 全覆盖，告警即时触达

**目标干系人**

| 干系人 | 关注点 |
|--------|--------|
| 终端用户 | 交易流畅性、持仓数据准确性、订单状态实时性 |
| 平台运营方 | 系统可用性、合规审计、安全事件响应 |
| 金融监管机构（SFC） | 交易记录完整性、数据保留7年、抗篡改性 |
| 安全团队 | 纵深防御、零信任网络、威胁检测与响应 |
| 平台开发团队 | GitOps 自动化、零停机部署、快速问题定位 |

**RTO / RPO 目标**

| 故障级别 | RTO | RPO | 策略 |
|---------|-----|-----|------|
| Pod 故障 | < 30 秒 | 0 | Kubernetes 自动重启 |
| AZ 可用区故障 | < 5 分钟 | 0 | Pod topologySpreadConstraints 跨 AZ |
| Region 灾难 | < 15 分钟 | < 5 分钟 | Aurora Global Database 跨区域切换 |
| 数据误删/损坏 | < 30 分钟 | < 5 分钟 | Aurora PITR + AWS Backup 合规保留 |

### 1.2 Contents（内容）— 系统构成要素

**业务实体（同原型阶段）**

原型阶段所有业务实体保持不变，包括 User、Fund、FundNavHistory、Holding、Order、InvestmentPlan、RiskAssessment 等，在生产环境中通过 Aurora PostgreSQL Global Database 进行分布式存储，满足金融级持久化要求。

**技术组件（生产环境）**

| 组件 | 技术选型 | 规格/配置 | 作用 |
|------|---------|-----------|------|
| 容器编排 | Amazon EKS 1.30 | 私有 API Server，3 AZ 部署 | 容器化应用编排，支持 GitOps |
| 计算节点 | Managed Node Group | system-ng (t3.medium) + app-ng (m5.large) + spot-ng (Spot m5/c5) | 分离系统组件与应用负载 |
| 容器镜像仓库 | Amazon ECR | 镜像扫描（Amazon Inspector），标签签名 | 安全容器供应链 |
| 数据库 | Aurora PostgreSQL 16 | Global Database（主: us-east-1，备: us-west-2） | 金融级持久化，跨区域 DR |
| 数据库连接池 | Amazon RDS Proxy | max connections = 1000，密码自动轮换 | 减少数据库连接压力 |
| 缓存 | Amazon ElastiCache Redis 7 | Multi-AZ，集群模式 | 会话缓存，NAV 查询加速 |
| 前端托管 | S3 + CloudFront | OAC 访问，HTTPS，WAF 防护 | 静态 SPA 全球分发 |
| 负载均衡 | ALB（Application Load Balancer） | 跨 3 AZ，SSL 终止，WAF 集成 | HTTPS 终止，流量分发 |
| DNS | Amazon Route 53 | DNSSEC，Latency-based routing | 域名解析，高可用路由 |
| 密钥管理 | AWS Secrets Manager + KMS CMK | 每 30 天自动轮换 | 集中密钥管理 |
| 邮件服务 | Amazon SES | DKIM/SPF 验证 | 交易通知、告警邮件 |
| 监控 | Prometheus + Grafana（托管） | 指标采集、可视化仪表盘 | 全链路可观测 |
| 日志 | Fluent Bit → CloudWatch Logs | 90 天热存储，S3 + Glacier 7 年归档 | 结构化日志，集中分析 |
| 追踪 | AWS X-Ray + OpenTelemetry | 分布式请求追踪 | 请求链路可视化 |
| 告警 | CloudWatch Alarms → SNS → PagerDuty | P1/P2 分级告警 | 故障即时响应 |
| CI/CD | GitHub Actions → ECR → ArgoCD | SAST + 镜像扫描 + GitOps | 零停机自动化部署 |
| 容器安全 | Kyverno（Policy as Code） | 镜像签名验证，安全上下文 | Pod 运行时安全 |
| IaC | Terraform + Helm + Kustomize | S3 + DynamoDB 状态锁定 | 基础设施声明式管理 |

### 1.3 Context（上下文）— 系统边界与外部交互

**生产环境系统上下文**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         External Systems & Users                            │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │ HTTPS/TLS 1.2+
                         Internet │
                                 ▼
                    ┌────────────────────────┐
                    │   Amazon Route 53      │
                    │   DNSSEC enabled       │
                    │   Latency Routing      │
                    └───────────┬────────────┘
                                │ HTTPS
                                ▼
                    ┌────────────────────────┐
                    │   Amazon CloudFront    │
                    │   ├── WAF v2 (SQLi/XSS/Rate)│
                    │   ├── Shield Standard  │
                    │   ├── ACM Cert (HTTPS) │
                    │   └── /* → S3 OAC      │
                    │   └── /api/* → ALB    │
                    └───────────┬────────────┘
                                │ HTTPS
                                ▼
                    ┌────────────────────────┐
                    │   ALB (3 AZ)          │
                    │   SSL Termination      │
                    │   WAF Integration      │
                    └───────────┬────────────┘
                                │ TLS (cert-manager)
                                ▼
                    ┌────────────────────────┐
                    │   EKS Cluster          │
                    │   Namespace: smart-invest│
                    │                        │
                    │  ┌──────────────────┐  │
                    │  │ Ingress (ALB LBC)│  │
                    │  │ /api/v1/auth/*   │  │
                    │  │ /api/v1/funds/*  │  │
                    │  │ /api/v1/orders/* │  │
                    │  │ /api/v1/portfolio/*│ │
                    │  │ /api/v1/plans/*  │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  ┌────────▼─────────┐  │
                    │  │ user-svc Pods    │  │
                    │  │ fund-svc Pods    │  │
                    │  │ order-svc Pods   │  │
                    │  │ portfolio-svc Pods│ │
                    │  │ plan-svc Pods    │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  IRSA ───▼── SecretsMgr│
                    │           │            │
                    │  X-Ray ──▼── Sidecar  │
                    │           │            │
                    │  Fluent Bit ↓ Logs     │
                    └───────────┼────────────┘
                                │ VPC Private Subnet
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
    ┌─────────────────┐ ┌──────────────┐ ┌───────────────┐
    │ Aurora PG (Writer)│ │Aurora PG (Reader)│ │ ElastiCache │
    │ AZ-a             │ │ AZ-b          │ │ Redis (Multi-AZ)│
    └─────────────────┘ └──────────────┘ └───────────────┘
              │                 │                 │
              ▼                 ▼                 ▼
    ┌─────────────────────────────────────────────────────┐
    │              VPC Private Subnet (Data Tier)           │
    │  S3 Gateway Endpoint │ SecretsMgr Endpoint │ SSM Endpoint│
    └─────────────────────────────────────────────────────┘

Cross-Account / Cross-Region:
    us-east-1 (Primary) ←── Aurora Global DB ──→ us-west-2 (DR Secondary)
```

**外部依赖接口规范**

| 外部系统 | 协议 | 认证 | SLA |
|---------|------|------|-----|
| Fund NAV 数据源 | REST/HTTPS | API Key | < 100ms |
| AWS SES | AWS SDK v2 | IRSA (最小权限) | < 2s |
| AWS Secrets Manager | AWS SDK v2 | IRSA + VPC Endpoint | < 50ms |
| AWS S3 | AWS SDK v2 | IRSA + VPC Endpoint | < 100ms |
| 监控/日志系统 | OpenTelemetry/HTTPS | IRSA | < 500ms |

**金融合规边界（不在生产系统内）**

- 真实清算机构对接（原型阶段跳过）
- SFC 电子交易报告系统（原型阶段跳过）
- 外部支付网关（原型阶段跳过）

### 1.4 Connections（连接）— 服务边界与通信模式

**微服务拆分策略**

从模块化单体拆分为独立微服务（每个对应一个 Kubernetes Deployment），以获得独立扩缩容和故障隔离能力：

```
smart-invest Kubernetes Namespace
│
├── user-svc（用户与认证服务）
│       REST API: /api/v1/auth/**, /api/v1/users/**, /api/v1/risk/**
│       扩缩策略: HPA（CPU > 60% 或内存 > 70%）
│       副本范围: 2–20
│       服务发现: Kubernetes DNS（user-svc:8080）
│
├── fund-svc（基金目录服务）
│       REST API: /api/v1/funds/**, /api/v1/nav/**
│       数据源: Aurora Reader（只读副本）
│       扩缩策略: HPA + KEDA（基于日间流量峰值）
│
├── order-svc（订单与交易服务）  ★ 金融核心，最严格安全要求
│       REST API: /api/v1/orders/**
│       数据库: Aurora Writer（强一致性写）
│       事件发布: Amazon EventBridge（订单创建事件）
│       补偿事务: Saga Pattern（超时取消逻辑）
│       扩缩策略: HPA（CPU > 50%，预留安全余量）
│
├── portfolio-svc（持仓与盈亏计算服务）
│       REST API: /api/v1/portfolio/**
│       缓存策略: ElastiCache Redis（NAV 数据缓存 5 分钟 TTL）
│       扩缩策略: HPA（内存 > 70%，避免 OOM）
│
├── plan-svc（定投计划服务）
│       REST API: /api/v1/plans/**
│       定时触发: Kubernetes CronJob（每分钟调度，限流）
│
└── notification-svc（通知服务）
        触发方式: EventBridge 事件驱动（异步）
        发送渠道: SES（邮件）
```

**服务间通信协议**

| 调用方 | 被调用方 | 协议 | 认证 | 超时 |
|--------|---------|------|------|------|
| 前端（ALB） | user-svc | HTTPS REST | JWT（RS256） | 5s |
| 前端（ALB） | fund-svc | HTTPS REST | JWT | 3s |
| 前端（ALB） | order-svc | HTTPS REST | JWT | 10s |
| order-svc | user-svc | HTTPS REST（内部） | Service Account Token | 2s |
| order-svc | fund-svc | HTTPS REST（内部） | Service Account Token | 2s |
| order-svc | portfolio-svc | HTTPS REST（内部） | Service Account Token | 2s |
| plan-svc | order-svc | EventBridge（事件） | IAM Role | N/A |
| notification-svc | SES | AWS SDK | IRSA | 5s |

**Kubernetes Network Policy（服务间访问控制）**

```
Default Policy: DENY ALL ingress + egress（Calico enforcement）

允许规则示例（order-svc 只允许来自 ALB 和 scheduler 命名空间的流量）：
  - order-svc:      ingress from alb-sg → port 8080
  - user-svc:       ingress from [order-svc, portfolio-svc, plan-svc] → port 8080
  - fund-svc:       ingress from [order-svc, portfolio-svc, plan-svc] → port 8080
  - portfolio-svc:  ingress from [order-svc] → port 8080
```

---

## 二、架构五视图（5-View Architecture）

### 2.1 逻辑视图（Logical View）— 功能分解与领域模型

**服务边界与职责**

```
Smart Invest Platform（生产级微服务架构）
│
├─ User & Auth Service（user-svc）
│    职责: 用户注册/登录、JWT 签发与验证、风险评估、用户画像
│    领域模型: User, RiskAssessment, RiskAnswer
│    聚合根: User（处理风险评估更新、密码变更）
│    外部接口: SES（发送注册确认邮件）
│    内部接口: 被 order-svc、plan-svc 调用（验证用户状态）
│
├─ Fund Catalog Service（fund-svc）
│    职责: 基金目录管理、NAV 历史、资产配置查询
│    领域模型: Fund, FundNavHistory, FundAssetAllocation
│    聚合根: Fund（管理 NAV 更新、持仓信息）
│    缓存策略: Redis 缓存 NAV（TTL=5min，减少 Aurora Reader 压力）
│    数据源: Aurora Read Replica（只读）
│
├─ Order & Trading Service（order-svc）★★★ 金融核心 ★★★
│    职责: 订单创建、订单取消、订单状态流转、交易结算
│    领域模型: Order（聚合根），OrderLineItem, OrderStatus（状态机）
│    状态机:
│      PENDING → PROCESSING → COMPLETED
│                 ↘ CANCELLED
│                 ↘ FAILED
│    补偿事务: 订单超时未完成 → Saga compensating transaction → 恢复持仓
│    幂等性: 业务参考号（reference_number）作为幂等键，防重复下单
│    审计: 所有状态变更写入 audit_log 表（pgaudit）
│    事件发布: EventBridge（OrderCreated, OrderCompleted, OrderCancelled）
│
├─ Portfolio Service（portfolio-svc）
│    职责: 持仓查询、实时市值计算、未实现盈亏计算
│    领域模型: Holding（聚合根）
│    关键计算:
│      market_value = SUM(units_i × latest_nav_i)
│      unrealised_pnl = SUM((latest_nav_i - avg_cost_nav_i) × units_i)
│    缓存: Redis 缓存 Holdings（TTL=30s，避免频繁 DB 查询）
│    读取: ElastiCache Redis（NAV） → Aurora Reader（Holdings）
│
├─ Investment Plan Service（plan-svc）
│    职责: 定投计划创建/终止、到期调度（通过 CronJob）
│    领域模型: InvestmentPlan（聚合根），PlanStatus
│    状态机:
│      ACTIVE → PAUSED → TERMINATED
│              ↓（到期自动触发）
│           EXECUTING
│    调度: K8s CronJob，每分钟检查到期计划，限流（max 10/分钟）
│    事件: PlanExecuted → EventBridge → notification-svc
│
└─ Notification Service（notification-svc）
     职责: 异步事件驱动的邮件通知
     触发: EventBridge 事件规则（订单创建/完成/取消/计划到期）
     邮件模板: SES 模板（HTML + 纯文本双版本）
```

**全局数据流**

```
用户下单（示例）:
  User(Browser) → ALB → order-svc
    → order-svc 调用 user-svc（验证用户状态，风险等级）
    → order-svc 调用 fund-svc（验证基金可交易状态，获取当前 NAV）
    → order-svc 写 Aurora Writer（创建 Order 记录，事务保证 ACID）
    → order-svc 发布 OrderCreated 事件 → EventBridge
        → notification-svc（发送确认邮件）
        → portfolio-svc（更新 Holdings，异步）
    → order-svc 返回订单确认给用户

持仓查询:
  User → ALB → portfolio-svc
    → portfolio-svc 从 Redis 获取最新 NAV（如缓存未命中 → fund-svc → Aurora Reader）
    → portfolio-svc 从 Aurora Reader 获取 Holdings
    → 计算市值与盈亏 → 返回
```

### 2.2 开发视图（Development View）— 代码组织与依赖

**GitOps 目录结构（IaC + 应用配置）**

```
smart-invest/
│
├── backend/                          ← Spring Boot 应用源码
│   ├── user-svc/                     ← 独立 Maven module
│   ├── fund-svc/                     ← 独立 Maven module
│   ├── order-svc/                    ← 独立 Maven module
│   ├── portfolio-svc/                ← 独立 Maven module
│   ├── plan-svc/                     ← 独立 Maven module
│   ├── notification-svc/             ← 独立 Maven module
│   └── pom.xml                       ← 父 POM，统一版本管理
│
├── frontend/                         ← React + TypeScript 源码
│
├── infra/                            ← 基础设施即代码
│   ├── terraform/
│   │   ├── modules/
│   │   │   ├── vpc/                 ← VPC（3 AZ，Public/Private 分层）
│   │   │   ├── eks/                  ← EKS 集群、Node Group、Addon
│   │   │   ├── aurora/               ← Aurora Global Database
│   │   │   ├── elasticache/          ← ElastiCache Redis
│   │   │   ├── alb/                  ← ALB + Target Group
│   │   │   ├── cloudfront/            ← CloudFront Distribution + WAF
│   │   │   ├── secrets-manager/      ← KMS CMK + Secrets
│   │   │   └── iam/                  ← IRSA Role definitions
│   │   └── environments/
│   │       ├── prod/
│   │       │   ├── main.tf
│   │       │   └── terraform.tfvars
│   │       └── staging/
│   │
│   ├── helm/                         ← Helm Charts（EKS Add-ons）
│   │   ├── argocd/                   ← ArgoCD 安装配置
│   │   ├── prometheus/              ← kube-prometheus-stack
│   │   ├── aws-lbc/                  ← AWS Load Balancer Controller
│   │   └── secrets-csi/             ← Secrets Store CSI Driver
│   │
│   └── k8s/                         ← Kubernetes Manifests（Kustomize）
│       ├── base/                     ← 共享资源（Namespace, NetworkPolicy, IRSA）
│       │   ├── namespace.yaml
│       │   ├── networkpolicy.yaml
│       │   └── irsa-roles/           ← 每个服务的 IAM Role
│       ├── services/
│       │   ├── user-svc/
│       │   │   ├── deployment.yaml
│       │   │   ├── service.yaml
│       │   │   ├── hpa.yaml
│       │   │   └── pdb.yaml
│       │   ├── fund-svc/
│       │   ├── order-svc/
│       │   ├── portfolio-svc/
│       │   ├── plan-svc/
│       │   └── notification-svc/
│       └── overlays/
│           ├── staging/
│           │   └── kustomization.yaml
│           └── prod/
│               ├── kustomization.yaml
│               └── configmap.yaml    ← 环境特定配置
│
└── .github/workflows/               ← GitHub Actions CI/CD
    ├── ci.yml                       ← PR: 测试 + SAST + 镜像扫描
    ├── deploy-staging.yml           ← 合入 main → 部署 staging
    └── deploy-prod.yml              ← Tag → 部署 prod（含审批门）
```

**依赖版本管理（Maven BOM）**

| 依赖 | 版本 | 说明 |
|------|------|------|
| Java | 21（Amazon Corretto 21） | EKS 容器镜像基础 |
| Spring Boot | 3.3.2 | 框架 |
| Spring Cloud Kubernetes | 3.x | K8s 服务发现、ConfigMap 集成 |
| Springdoc OpenAPI | 2.6.0 | API 文档（staging/prod 各一套） |
| JJWT | 0.12.6 | JWT（RS256，密钥存 Secrets Manager） |
| AWS SDK v2 | 2.26.0（BOM） | SES、Secrets Manager |
| Resilience4j | 2.x | 熔断、限流、重试 |
| Micrometer | 1.x | Prometheus 指标导出 |
| OpenTelemetry | 1.x | 分布式追踪 |

### 2.3 进程视图（Process View）— 运行时行为与并发

**EKS Pod 运行时架构（以 order-svc 为例）**

```
Pod: order-svc-7d9f8b6-x2pqr（副本数: 2）
┌─────────────────────────────────────────────────────┐
│  Kubernetes Pod                                     │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  Init Container: aws-otel-collector            │  │
│  │    - 等待 IRSA Role 注入完成                   │  │
│  │    - 启动 X-Ray Daemon 进程                    │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  Main Container: spring-boot-app               │  │
│  │    Port: 8080                                   │  │
│  │    User: 1000 (runAsNonRoot)                   │  │
│  │    SecurityContext:                            │  │
│  │      allowPrivilegeEscalation: false          │  │
│  │      readOnlyRootFilesystem: true              │  │
│  │      capabilities.drop: [ALL]                  │  │
│  │                                                   │  │
│  │    Volume Mounts:                              │  │
│  │      /mnt/secrets → CSI Secrets Store          │  │
│  │        (DB password, JWT secret, SES creds)    │  │
│  │      /tmp → emptyDir (readOnlyRootFS needs)   │  │
│  │      /var/log → fluent-bit downwardAPI         │  │
│  │                                                   │  │
│  │    Readiness Probe: GET /actuator/health       │  │
│  │      initialDelay: 30s                         │  │
│  │      period: 10s                               │  │
│  │      failureThreshold: 3                        │  │
│  │                                                   │  │
│  │    Liveness Probe: GET /actuator/health/liveness│  │
│  │      initialDelay: 60s                          │  │
│  │      period: 15s                                │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

Sidecar Pattern:
  X-Ray Daemon（同一 Pod 内，共享 Process Namespace）
  Fluent Bit（DaemonSet，但按 namespace 过滤）
```

**Horizontal Pod Autoscaler（HPA）配置**

```
order-svc HPA:
  minReplicas: 2
  maxReplicas: 20
  指标:
    CPU 利用率 > 60% → 扩容
    内存利用率 > 70% → 扩容
  缩容保护:
    stabilizationWindowSeconds: 300（5 分钟，防止频繁抖动）
  扩容策略:
    scaleUp: 100% 增长（15 秒内最大翻倍）
    scaleDown: 10% 缩减（60 秒内最多缩 10%）

fund-svc HPA（特殊）:
  基于 CronJob 定时扩缩（交易时段 9:30-16:00 HKT 扩容）
  夜间低谷缩容至最小副本

spot-ng 扩缩:
  Cluster Autoscaler 配合 Spot Instance（成本优化）
  spot ng: 0-20 副本（非关键批次任务）
  app ng（On-Demand）: 2-10 副本（核心服务）
```

**Spring Boot 应用线程模型**

```
Tomcat 默认线程池:
  max-threads: 200
  min-spare: 10
  accept-count: 100（请求队列）

连接管理:
  HikariCP → RDS Proxy → Aurora PostgreSQL
  max pool size: 50（每 Pod）× N Pods = 总连接数控制
  RDS Proxy 全局上限: 1000

 Resilience4j 熔断器配置（order-svc 调用 fund-svc/user-svc）:
   熔断器:
     failureRateThreshold: 50%
     waitDurationInOpenState: 60s
     slidingWindowType: COUNT_BASED
     minimumNumberOfCalls: 10
   限流:
     rateLimiter: 100 req/s per service
   重试:
     maxAttempts: 3
     waitDuration: 500ms
     enableExponentialBackoff: true
```

**定时任务（Plan Execution CronJob）**

```
K8s CronJob: plan-executor（每分钟执行）
  concurrencyPolicy: Forbid（禁止并发运行）
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 3
  restartPolicy: OnFailure

  Job 执行逻辑:
    1. 查询所有 ACTIVE 且 next_contribution_date ≤ now 的 Plan
    2. 分批处理（每批 10 个），限流避免数据库峰值
    3. 每处理一个 Plan:
        a. 调用 order-svc REST API（带幂等键）
        b. 更新 Plan.next_contribution_date
        c. 发布 PlanExecutedEvent
    4. 记录执行结果（Kubernetes Job 日志）
```

### 2.4 物理视图（Physical View）— 基础设施拓扑

**AWS 多账号结构（AWS Organizations）**

```
AWS Organizations Root
│
├── Management Account（主账号，仅账单和 SCP）
│
├── Security Tools Account（Shared Services OU）
│   ├── Security Hub（聚合所有账号发现）
│   ├── GuardDuty（威胁检测）
│   ├── CloudTrail（组织级审计 trail）
│   └── AWS Config（合规检查）
│
└── Production Account（Workloads OU）
    │
    ├── VPC 10.0.0.0/16（us-east-1）
    │   │
    │   ├── Public Subnet AZ-a（10.0.1.0/24）
    │   ├── Public Subnet AZ-b（10.0.2.0/24）
    │   ├── Public Subnet AZ-c（10.0.3.0/24）
    │   │       NAT Gateway × 3（一对一 AZ 映射）
    │   │       VPC Endpoints（Interface 类型）
    │   │
    │   ├── Private Subnet — App（10.0.16.0/20，3 AZ）
    │   │       EKS Worker Nodes（app-ng, spot-ng）
    │   │       ALB Nodes（ENI 挂在 Public Subnet，流量转发至此）
    │   │
    │   ├── Private Subnet — Data（10.0.32.0/20，3 AZ）
    │   │       Aurora PostgreSQL Cluster（Writer AZ-a，Readers AZ-b/c）
    │   │       ElastiCache Redis Cluster（3 Shards × 2 Replicas）
    │   │       EFS（共享存储，日志归档）
    │   │
    │   └── VPC Endpoints（Gateway: S3, DynamoDB；Interface: SecretsMgr, ECR, SSM, CloudWatch）
    │
    ├── EKS Cluster: smart-invest-prod（私有 API Server）
    │
    ├── RDS: Aurora PostgreSQL Global
    │   Primary: us-east-1（Writer AZ-a + Reader AZ-b + Reader AZ-c）
    │   Secondary: us-west-2（Reader AZ-a，DR 用）
    │
    ├── ElastiCache: Redis 7 Cluster Mode
    │   3 Shards × 2 Replicas（每 Shard 1 主 2 副本）
    │
    ├── S3: 前端静态资源（KMS 加密，版本控制开启）
    │
    ├── CloudFront: CDN + WAF + Shield
    │   WAF Rules:
    │     - AWS Managed: CommonRuleSet, SQLiRuleSet, XSSRuleSet
    │     - Rate limit: 2000 req/5min per IP
    │     - Custom: JWT 有效性校验（CloudFront Function）
    │
    └── Route 53: DNSSEC + Alias Record → CloudFront
```

**Aurora PostgreSQL Global Database 拓扑**

```
Aurora Global Cluster: smart-invest-global

Primary Region (us-east-1):
  ┌──────────────────────────────────────────────┐
  │  Aurora DB Cluster (smart-invest-db)         │
  │                                               │
  │  ┌────────────────┐   ┌────────────────┐   │
  │  │ Writer Instance │   │ Reader Instance │   │
  │  │ db.r6g.large   │◄──│ db.r6g.large   │   │
  │  │ AZ-a            │   │ AZ-b            │   │
  │  │                 │   └───────┬────────┘   │
  │  │ storage: 128TB  │           │            │
  │  │ KMS CMK 加密     │           │            │
  │  │ IAM Auth 启用    │           │            │
  │  │ pgaudit: 写+DDL │           │            │
  │  └────────┬─────────┘           ▼            │
  │           │        ┌────────────────┐       │
  │           └───────►│ Reader Instance │       │
  │                    │ db.r6g.large    │       │
  │                    │ AZ-c            │       │
  │                    └─────────────────┘       │
  └──────────────────────────────────────────────┘

Secondary Region (us-west-2) [DR]:
  ┌──────────────────────────────────────────────┐
  │  Aurora Secondary（用于跨区域灾备）              │
  │  可在 < 1 分钟内提升为 Global Primary           │
  └──────────────────────────────────────────────┘

RDS Proxy:
  ├─ Proxy Endpoints: 1（应用连接）
  ├─ IAM Auth: enabled
  └─ Secrets Manager 自动轮换: enabled
```

**EKS Node Group 详细配置**

| Node Group | Instance Type | Min/Max/Desire | 部署位置 | 特点 |
|-----------|--------------|----------------|---------|------|
| system-ng | t3.medium | 2/4/2 | 3 AZ 各 1 | 核心 K8s 系统组件（CoreDNS, Metrics Server） |
| app-ng | m5.large | 2/10/4 | 3 AZ | 核心微服务（user/fund/order/portfolio/plan/notification） |
| spot-ng | m5.large, m5.xlarge, c5.large | 0/20/0 | 3 AZ | 非关键任务、批量计算（Spot 实例，节省 60-80%） |

**成本治理策略**

| 策略 | 实施方式 | 预期节省 |
|------|---------|---------|
| Spot Instance | spot-ng 使用 Spot（无持久化状态的工作负载） | 60-80% vs On-Demand |
| ARM 迁移 | Graviton3（m6g/c6g）替代 x86 | 10-20% vs 同规格 x86 |
| Karpenter | 按需精准供给 Node，避免固定 Node 浪费 | 取决于利用率 |
| S3 智能分层 | `Intelligent-Tiering` 自动冷热分层 | 视数据访问模式 |
| Savings Plans | app-ng 购买 1 年 Savings Plans | 约 40% vs On-Demand |
| Aurora Serverless v2 | 可选：fund-svc 读取场景用 Serverless | 按实际使用付费 |

### 2.5 场景视图（Scenario View）— 关键用例时序与故障恢复

**场景 1：用户完成 Pathway A 订单（微服务版）**

```
Actor: 用户（Mobile Web）  System: Smart Invest Platform（EKS 环境）

1. [用户] POST /api/v1/orders
   → ALB → order-svc Pod（JWT 验证通过）

2. [order-svc] 幂等性检查
   → 检查 reference_number 是否已处理（Redis lookup, TTL=24h）
   → 已存在 → 返回原结果（防重复下单）

3. [order-svc] 异步并行调用：
   a. GET /internal/users/{userId}/status → user-svc
      → 验证: 用户状态 ACTIVE，风险等级 >= 基金要求
   b. GET /internal/funds/{fundCode}/price → fund-svc
      → 获取最新 NAV

4. [order-svc] 创建 Order（事务）
   → Aurora Writer（ACID 事务）
   → 状态: PENDING
   → pgaudit 记录 INSERT

5. [order-svc] 状态更新（PROCESSING → COMPLETED）
   → 写入 audit_log（金额变更，须审计）
   → 更新 Holding（UPSERT）
   → 发布 OrderCompleted 事件 → EventBridge

6. [EventBridge] 路由事件：
   → notification-svc（异步）→ SES → 发送订单确认邮件
   → portfolio-svc（异步）→ 更新缓存

7. [order-svc] 返回 OrderResponse（ref: P-123456，status: COMPLETED）

8. [Prometheus] 指标采集：
   - order_completed_total（Counter，按 fund_type 分维）
   - order_processing_duration_seconds（Histogram）
```

**场景 2：Aurora 可用区故障自动恢复**

```
故障发生: us-east-1 AZ-a 完全不可用

1. [Aurora 检测] Writer 实例无响应（约 30 秒检测）
2. [Aurora 提升] AZ-b Reader 自动提升为 Writer
   → DNS 更新：cluster endpoint 指向新 Writer（< 30 秒）
3. [RDS Proxy 感知] Proxy 自动重路由至新 Writer
4. [HikariCP] 连接池重建，应用短暂重试（指数退避）
5. [order-svc] 业务层 Resilience4j 熔断器触发
   → 10 秒内自动恢复对外服务
   → P99 延迟可能短暂上升至 5-10 秒
6. [Alertmanager] 告警触发 → PagerDuty → on-call 工程师
7. [事后] SRE 执行 Post-mortem，分析根因（Fix 未通过可用区亲和性）
```

**场景 3：Kubernetes Pod 被驱逐后的自动恢复**

```
触发: EKS 节点 scale-in（Spot 中断通知或手动 drain）

1. [K8s Controller] 检测 Pod 状态异常（NotReady > 5min）
2. [K8s Scheduler] 在其他可用节点重新调度 Pod
   → Pod 满足 topologySpreadConstraints（跨 AZ 分布）
   → 满足 PodDisruptionBudget（minAvailable: 1）
3. [Init Container] CSI Secrets Store 注入 DB 密码、JWT 密钥
4. [Main Container] Spring Boot 启动
   → Readiness Probe 失败 3 次 → Service 移除 Endpoints
   → Readiness Probe 通过 → Service 重新加入 Endpoints
5. [ALB Target Group] 健康检查通过 → 恢复流量分发
6. [Prometheus] Pod 重启次数告警（如果 > 3 次/小时 → P2）
```

**场景 4：市场高峰时段的弹性扩缩**

```
时间线（交易时段）:
  09:00 HKT  ── 前盘准备 ──→ fund-svc HPA 扩容 2→6
  09:30 HKT  ── 开市高峰 ──→ order-svc HPA 扩容 2→8
  10:00 HKT  ── 高峰持续 ──→ ALB 开始排队监控
  12:00 HKT  ── 午间低谷 ──→ 自动缩容开始
  13:00 HKT  ── 下午开盘 ──→ 再次扩容
  16:00 HKT  ── 收盘 ─────→ 缩容至最小 2 副本
  22:00 HKT  ── 非交易时段 ─→ spot-ng 缩至 0（无批处理任务）

KEDA（Event-driven Autoscaling，可选增强）:
  基于 EventBridge 订单量指标触发 fund-svc 扩缩
  基于 Redis 连接数触发 portfolio-svc 扩缩
```

**场景 5：跨区域灾难恢复演练**

```
演练目标: 验证 us-west-2 Region 能在 15 分钟内接管业务

1. [演练触发] SRE 手动执行 DR Runbook
2. [Aurora Global] 执行跨区域切换：
   aws rds failover-global-cluster \
     --global-cluster-identifier smart-invest-global \
     --target-db-cluster-identifier arn:aws:rds:us-west-2:...
3. [DNS 切换] Route 53 Health Check 检测 us-east-1 ALB 不可达
   → 自动切换 Latency alias → us-west-2 ALB
4. [EKS 备集群] us-west-2 EKS Cluster 预置（冷备，1/3 规格）
   → 紧急扩容 app-ng（spot 实例）
5. [数据验证] 对比 Aurora 快照时间戳，确认 RPO < 5 分钟
6. [业务验证] 冒烟测试：注册 → 下单 → 持仓查询
7. [演练结束] 切回 us-east-1，分析 RTO/RPO 数据
```

---

## 三、全链路可观测性设计

### 3.1 三大支柱

| 支柱 | 工具 | 采集内容 | 保留期 |
|------|------|---------|--------|
| Metrics | Prometheus + Grafana（托管） | RED Metrics、基础设施指标 | 90 天热存储 |
| Logs | Fluent Bit → CloudWatch Logs | JSON 结构化日志，按 service/pod/namespace 区分 | 90 天热 + S3 7 年归档 |
| Traces | AWS X-Ray + OpenTelemetry | 端到端请求链路，含 DB 查询耗时 | 30 天 |

### 3.2 核心仪表盘

- **SLO Dashboard**: API 可用性（99.9%）、P99 延迟、错误率
- **RED Metrics（per service）**: Rate（QPS）、Errors（4xx/5xx 率）、Duration（P50/P95/P99）
- **JVM Dashboard**: Heap 使用率、GC 频率与时长、线程数、类加载数
- **Aurora Dashboard**: 连接数、复制延迟、慢查询、存储使用
- **Business Metrics**: 每日订单量、活跃用户数、定投计划执行成功率

---

## 四、安全架构（纵深防御）

| 层次 | 控制措施 | 实施技术 |
|------|---------|---------|
| 边界 | WAF（OWASP Top 10）、DDoS 防护 | CloudFront + WAF v2 + Shield Standard |
| 网络 | 零信任网络、VPC 隔离 | Security Group 白名单、NetworkPolicy Deny-All |
| 应用 | JWT（RS256）、API 鉴权、输入验证 | Spring Security、速率限制 |
| 容器 | 非 root 运行、只读根文件系统、能力降权 | SecurityContext、PSP/Kyverno |
| 密钥 | 不存储明文密钥、IRSA 最小权限 | Secrets Store CSI Driver + KMS CMK |
| 审计 | 操作日志不可篡改 | CloudTrail（Org Trail）、pgaudit（RDS） |
| 威胁检测 | 异常行为检测 | GuardDuty（EC2/RDS/IAM 威胁） |
| 合规 | 配置持续审计 | AWS Config + Security Hub |
| 镜像安全 | 漏洞扫描、签名验证 | Inspector + Kyverno ImageSigning Policy |

---

## 五、关键设计决策（SAP-C02 级别）

| 决策 | 选择 | 权衡分析 |
|------|------|---------|
| 容器编排 | EKS（非 ECS Fargate） | 金融场景需要 NetworkPolicy（Calico）、PodDisruptionBudget、多租户隔离 |
| 数据库 | Aurora PostgreSQL Global（非单 Region RDS） | Global Database 实现 < 1 分钟 RTO 跨区域 DR；写入时复制延迟 < 1 秒 |
| 连接池 | RDS Proxy（非应用内 HikariCP 直连） | 密码自动轮换无需重启应用；Aurora Failover 透明切换；减少连接数压力 |
| GitOps | ArgoCD（非 kubectl apply） | 自动漂移检测；历史审计；幂等性保证；支持 Canary 策略 |
| 密钥注入 | Secrets Store CSI Driver（非 K8s Secret） | K8s Secret 明文存储 etcd（需额外加密）；CSI 直接挂载，无中间存储 |
| 镜像安全 | ECR + Inspector + Kyverno | push 时自动 CVE 扫描；运行时只允许已签名镜像 |
| 可观测性 | Prometheus + X-Ray（非闭源自建） | 云原生集成，运维成本低；托管版（AMP/AMG）无 Server 运维 |
| 部署策略 | ArgoCD Rollouts Canary（非全量蓝绿） | 灰度发布降低风险；自动化分析 metric 决定是否继续 |
| IaC | Terraform + Helm + Kustomize（非 CDK） | Terraform 成熟度高，模块市场丰富；Helm 管理复杂 Add-on；Kustomize 分环境差异化 |
| 成本控制 | Spot + Savings Plans + Karpenter | Spot 覆盖非关键负载；Savings Plans 锁定核心服务成本；Karpenter 精准按需供给 |

---

## 六、合规与治理框架对齐

| 框架 | 对应措施 |
|------|---------|
| AWS Well-Architected Framework（5 pillars） | 操作卓越（ArgoCD）、安全（纵深防御）、可靠性（Multi-AZ + Global DB）、性能效率（HPA + Spot）、成本优化（Spot + Karpenter） |
| CIS Amazon EKS Benchmark | Pod Security Standards、RBAC 最小权限、网络Policy |
| PCI-DSS v4.0 | TLS 传输加密、KMS 静态加密、审计日志、访问控制 |
| SOC 2 Type II | CloudTrail + CloudWatch + GuardDuty + Config 持续监控 |
| NIST CSF | Identify（IAM）、Protect（WAF/Encryption）、Detect（GuardDuty）、Respond（EventBridge + PagerDuty）、Recover（Global DB） |
| SFC 电子交易平台指引 | 操作日志 7 年保留、订单不可篡改、灾难恢复计划 |
