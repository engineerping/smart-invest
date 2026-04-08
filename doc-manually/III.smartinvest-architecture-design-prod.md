# Smart Invest — 生产环境架构设计文档

**版本**: 2.0（修订）
**日期**: 2026-04-08
**阶段**: 生产环境（Enterprise Production）
**设计原则**: 金融级安全 > 服务弹性 > 合规可审计 > 成本优化（最低优先级）
**目标认证对齐**: AWS Certified Solutions Architect – Professional (SAP-C02)
**参考文档**: SmartInvest_ProjectRoadmap_v3.md · 2026-04-08-aws-deployment-plan-d.md

---

## 一、C4 架构模型（C4 Models）

---

### Level 1 — 系统上下文图（System Context）

展示 Smart Invest 作为一个整体与外部世界的交互，定位所有外部人员和系统。

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              Smart Invest — System Context                               │
│                                                                                         │
│                                                                                         │
│    ┌──────────────────────────────────────────────────────────────────────────┐        │
│    │                           金融监管机构 (SFC)                                │        │
│    │                    香港证券及期货事务监察委员会                            │        │
│    │                    数据审计要求 / 电子交易报告 / 合规检查                   │        │
│    └─────────────────────────────────┬────────────────────────────────────────┘        │
│                                      │                                                   │
│                                      │ 合规报告 / 操作日志（7年保留）                        │
│                                      ▼                                                   │
│                                                                                         │
│    ┌──────────────────┐                                                                  │
│    │   终端用户        │  Mobile Web 浏览器（HTTPS）                                     │
│    │   个人投资者      │  ┌─────────────────────────────────────────────────┐          │
│    │   25-45岁香港用户 │  │         Smart Invest Platform（金融级）          │          │
│    └────────┬─────────┘  │                                                 │          │
│             │             │  ┌─────────────────────────────────────────┐   │          │
│             │ HTTPS        │  │  前端层: React SPA + CloudFront + WAF    │   │          │
│             │             │  └───────────────┬─────────────────────────┘   │          │
│             │             │                  │                             │          │
│             │             │  ┌───────────────▼───────────────────────────┐ │          │
│             │             │  │  应用层: 6 个微服务（EKS）                  │ │          │
│             │             │  │  user / fund / order / portfolio          │ │          │
│             │             │  │  plan / notification                      │ │          │
│             │             │  └───────────────┬───────────────────────────┘ │          │
│             │             │                  │                              │          │
│             │             │  ┌───────────────▼───────────────────────────┐ │          │
│             │             │  │  数据层: Aurora PostgreSQL + Redis          │ │          │
│             │             │  │  缓存层: ElastiCache                      │ │          │
│             │             │  └─────────────────────────────────────────┘   │          │
│             │             └─────────────────────────────────────────────────┘          │
│             │                                                                       │
│             │                                                                       │
│    ┌────────▼────────────────────────────────────────────────────────────────────────┐ │
│    │                           AWS 云基础设施（生产账号）                              │ │
│    │                                                                                 │ │
│    │   Route 53 (DNSSEC)    CloudFront (WAF+Shield)   EKS 1.30 (私有 API Server)  │ │
│    │   Secrets Manager      ECR (镜像+签名)              RDS Proxy                   │ │
│    │   Aurora Global DB     ElastiCache Redis           CloudWatch                  │ │
│    │   SES (DKIM/SPF)       GuardDuty + Security Hub    X-Ray                      │ │
│    │   AWS Backup (WORM)    CloudTrail (Org Trail)      AWS Config                  │ │
│    │   AWS Inspector        Karpenter / Spot/On-Demand  ArgoCD GitOps              │ │
│    │                                                                                 │ │
│    └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

**外部系统接口规范**

| 外部系统                | 协议                  | 数据流向              | 合规要求            |
| ------------------- | ------------------- | ----------------- | --------------- |
| AWS SES             | AWS SDK v2          | 出站：注册确认、订单通知、定投到期 | DKIM/SPF 验证     |
| Fund NAV 数据源        | REST/HTTPS          | 入站：每日基金净值更新       | SLA < 100ms     |
| SFC 合规报告            | SFTP/HTTPS          | 出站：交易记录、操作日志      | 7 年保留，不可篡改      |
| AWS Secrets Manager | IRSA + VPC Endpoint | 运行时密钥注入           | CMK 加密，每 30 天轮换 |

---

### Level 2 — 容器图（Container）

描述系统内部的高层技术架构：有哪些进程/容器，各自负责什么，如何通信。

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│                            Smart Invest — Container 视图                                   │
│                                                                                            │
│  Internet                                                                                  │
│     │                                                                                      │
│     │ HTTPS (TLS 1.2+, ACM 证书)                                                           │
│     ▼                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                    Amazon Route 53 (DNSSEC, Latency Routing)                        │  │
│  └──────────────────────────────────────────────────────────┬───────────────────────────┘  │
│                                                               │                              │
│     ┌────────────────────────────────────────────────────────┼────────────────────┐         │
│     │                                                        │                    │         │
│     │ HTTPS                                                   │                    │         │
│     ▼                                                        │                    │         │
│  ┌──────────────────────────────────────────────────────┐   │                    │         │
│  │              Amazon CloudFront (WAF + Shield Standard) │   │                    │         │
│  │                                                        │   │                    │         │
│  │  WAF Rules:                                            │   │                    │         │
│  │   ├─ AWS Managed: CommonRuleSet, SQLiRuleSet, XSSRuleSet│   │                    │         │
│  │   ├─ Rate Limit: 2000 req/5min per IP                  │   │                    │         │
│  │   └─ JWT 有效性校验（CloudFront Function）              │   │                    │         │
│  │                                                        │   │                    │         │
│  │  路由:                                                  │   │                    │         │
│  │   /*       → S3（React SPA，OAC 访问）                 │   │                    │         │
│  │   /api/*   → ALB（跨 3 AZ）                           │   │                    │         │
│  └──────────────────────────────────────┬─────────────────────┘                    │         │
│                                        │                                             │         │
│                                        │ TLS（cert-manager 集群内证书）               │         │
│                                        ▼                                             │         │
│  ┌───────────────────────────────────────────────────────────────────────────────┐       │
│  │                         ALB — Application Load Balancer                          │       │
│  │                     跨 3 AZ，SSL 终止，WAF 集成，Target Group 路由              │       │
│  └────────────────────────────────────────────┬────────────────────────────────────┘       │
│                                                │                                          │
│     ┌──────────────────────────────────────────┼──────────────────────────────┐             │
│     │                                          │                              │             │
│     ▼                                          ▼                              ▼             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐  │
│  │  user-svc Pod   │    │  fund-svc Pod   │    │  order-svc Pod  │    │plan-svc Pod  │  │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │    │┌───────────┐ │  │
│  │  │ Spring Boot│  │    │  │ Spring Boot│  │    │  │ Spring Boot│  │    ││Spring Boot│ │  │
│  │  │ JAR 21     │  │    │  │ JAR 21     │  │    │  │ JAR 21     │  │    ││JAR 21     │ │  │
│  │  │ port:8080 │  │    │  │ port:8080 │  │    │  │ port:8080 │  │    ││port:8080 │ │  │
│  │  │ replicas:2│  │    │  │ replicas:2 │  │    │  │ replicas:2 │  │    ││replicas:2│ │  │
│  │  │ HPA 2-20 │  │    │  │ HPA 2-10 │  │    │  │ HPA 2-20 │  │    ││CronJob   │ │  │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │    │└───────────┘ │  │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘    └──────┬───────┘  │
│           │                     │                     │                     │           │
│  ┌────────▼────────┐    ┌────────▼────────┐    ┌──────▼──────────┐    ┌──────▼────────┐ │
│  │portfolio-svc Pod│    │notification-svc │    │  EventBridge    │    │  EKS Cluster   │ │
│  │ Spring Boot JAR │    │  Spring Boot JAR │    │  事件总线        │    │  Namespace:    │ │
│  │ replicas: 2     │    │  replicas: 1-3   │    │  order-created  │    │  smart-invest  │ │
│  │ HPA 2-20       │    │  事件驱动        │    │  plan-executed  │    │                │ │
│  └────────────────┘    └─────────────────┘    └──────────────────┘    └────────────────┘ │
│         │                                                                  │             │
│         │                    EKS Cluster (私有 API Server, 3 AZ)           │             │
│         │                    ┌─────────────────────────────────────────┐  │             │
│         │   IRSA ────────────► Secrets Manager (KMS CMK 加密)          │  │             │
│         │   X-Ray ───────────► 分布式追踪（HTTP → Service → DB → Redis）│  │             │
│         │   Fluent Bit ───────► CloudWatch Logs (90天热 + S3 7年归档)   │  │             │
│         └────────────────────┴─────────────────────────────────────────┴──┘             │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐    │
│  │                          VPC Private Subnet — Data Tier (3 AZ)                  │    │
│  │                                                                                  │    │
│  │   ┌─────────────────────────────┐    ┌─────────────────────────────────────────┐ │    │
│  │   │  Aurora PostgreSQL Global │    │    Amazon ElastiCache Redis 7           │ │    │
│  │   │  Primary: us-east-1        │    │    集群模式（3 Shards × 2 Replicas）    │ │    │
│  │   │    Writer AZ-a             │    │    Multi-AZ（自动故障转移）              │ │    │
│  │   │    Reader × 2 (AZ-b,AZ-c)  │    │    用途: NAV 缓存、Holdings 缓存、     │ │    │
│  │   │  Secondary: us-west-2      │    │         订单幂等键（TTL=24h）           │ │    │
│  │   │  DR: 可在 <1 分钟内提升     │    │    TLS in-transit 加密               │ │    │
│  │   │  KMS CMK 静态加密          │    └─────────────────────────────────────────┘ │    │
│  │   │  IAM Auth 启用             │                                                │    │
│  │   │  pgaudit: 写+DDL 审计     │                                                │    │
│  │   │  RDS Proxy（连接池）       │                                                │    │
│  │   └─────────────────────────────┘                                                │    │
│  └──────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                          │
│  S3 Bucket (smart-invest-frontend-prod)                                                  │
│  KMS CMK 加密 │ 版本控制 │ OAC 访问 │ CloudFront 作为唯一入口                             │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

**容器规格说明**

| 容器               | 副本策略 | HPA 指标              | 数据源                         | IRSA 权限                      |
| ---------------- | ---- | ------------------- | --------------------------- | ---------------------------- |
| user-svc         | 2-20 | CPU > 60%           | Aurora Writer（写）, Redis（会话） | SecretsMgr, SES              |
| fund-svc         | 2-10 | CPU > 60%, 交易时段定时扩缩 | Aurora Reader（只读）           | SecretsMgr                   |
| order-svc        | 2-20 | CPU > 50%（金融核心，余量）  | Aurora Writer（事务写）          | SecretsMgr, SES, EventBridge |
| portfolio-svc    | 2-20 | Memory > 70%        | Aurora Reader, Redis        | SecretsMgr                   |
| plan-svc         | 2-10 | CPU > 60%           | Aurora Writer               | SecretsMgr                   |
| notification-svc | 1-3  | CPU > 70%           | —                           | SES                          |

---

### Level 3 — 组件图（Component）

展示 EKS Pod 内各组件及 Kubernetes 资源的组织关系。

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                  EKS Pod — Component 视图（以 order-svc 为例，金融核心）                  │
│                                                                                         │
│  Kubernetes Pod (order-svc-7d9f8b-x2pqr, Replicas: 2)                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Security Context（Pod 级别）                                               │ │  │
│  │  │   runAsNonRoot: true  │  runAsUser: 1000  │  fsGroup: 2000                  │ │  │
│  │  │   topologySpreadConstraints: topology.kubernetes.io/zone → DoNotSchedule   │ │  │
│  │  └─────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                   │  │
│  │  ┌─────────────────────────┐  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Init Container          │  │  Main Container (Spring Boot JAR 21)        │  │  │
│  │  │ aws-otel-collector       │  │                                              │  │  │
│  │  │ 等待 IRSA Role 注入      │  │  Port: 8080                                 │  │  │
│  │  │ 启动 X-Ray Daemon       │  │                                              │  │  │
│  │  └─────────────────────────┘  │  Security Context（Container 级别）           │  │  │
│  │                                │   allowPrivilegeEscalation: false           │  │  │
│  │                                │   readOnlyRootFilesystem: true             │  │  │
│  │                                │   capabilities.drop: [ALL]                  │  │  │
│  │                                │                                              │  │  │
│  │                                │  Readiness Probe: /actuator/health          │  │  │
│  │                                │    initialDelay: 30s, period: 10s           │  │  │
│  │                                │  Liveness Probe: /actuator/health/liveness │  │  │
│  │                                │    initialDelay: 60s, period: 15s           │  │  │
│  │                                │                                              │  │  │
│  │                                │  Resources:                                 │  │  │
│  │                                │   requests: cpu 250m, memory 512Mi         │  │  │
│  │                                │   limits:   cpu 500m, memory 1Gi           │  │  │
│  │                                │                                              │  │  │
│  │                                │  ┌───────────────────────────────────────┐  │  │  │
│  │                                │  │  Spring Boot 内组件                   │  │  │  │
│  │                                │  │                                       │  │  │  │
│  │                                │  │  JwtAuthenticationFilter             │  │  │  │
│  │                                │  │       │                               │  │  │  │
│  │                                │  │  OrderController                     │  │  │  │
│  │                                │  │       │                               │  │  │  │
│  │                                │  │  OrderService（聚合根）               │  │  │  │
│  │                                │  │       │                               │  │  │  │
│  │                                │  │  OrderRepository ──► RDS Proxy      │  │  │  │
│  │                                │  │       │                               │  │  │  │
│  │                                │  │  Resilience4j CircuitBreaker         │  │  │  │
│  │                                │  │       │ 熔断 fund-svc / user-svc 调用  │  │  │  │
│  │                                │  │  OrderEventPublisher ──► EventBridge │  │  │  │
│  │                                │  │                                       │  │  │  │
│  │                                │  │  HealthIndicator（actuator）         │  │  │  │
│  │                                │  └───────────────────────────────────────┘  │  │  │
│  │                                │                                              │  │  │
│  │                                │  ┌───────────────────────────────────────┐  │  │  │
│  │                                │  │  Volume Mounts                       │  │  │  │
│  │                                │  │                                       │  │  │  │
│  │                                │  │  /mnt/secrets ──► CSI Secrets Store  │  │  │  │
│  │                                │  │    (DB 密码, JWT 密钥, SES creds)    │  │  │  │
│  │                                │  │  /tmp        ──► emptyDir (可写)      │  │  │  │
│  │                                │  │  /var/log    ──► fluent-bit         │  │  │  │
│  │                                │  └───────────────────────────────────────┘  │  │  │
│  │                                └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  Sidecar: X-Ray Daemon（共享 Process Namespace，同 Pod）                                  │
│  Sidecar: Fluent Bit（DaemonSet，按 namespace 过滤日志）                                    │
│                                                                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐    │
│  │                    Kubernetes Supporting Resources                                  │    │
│  │                                                                                   │    │
│  │  Service (ClusterIP)   ──► order-svc:8080  ──► ALB Target Group              │    │
│  │  PodDisruptionBudget  ──► minAvailable: 1  ──► 维护时至少保留 1 副本           │    │
│  │  HorizontalPodAutoscaler ──► min:2 max:20 ──► CPU/Memory 双重指标             │    │
│  │  ServiceAccount        ──► IRSA: order-svc IAM Role                          │    │
│  │  NetworkPolicy         ──► Deny All; allow: alb-sg → port 8080               │    │
│  └───────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

**Kubernetes 资源清单（per service）**

```
每个微服务在 EKS 命名空间 smart-invest 中包含:
  ├── Deployment.yaml          ← Pod 模板，镜像，健康检查，安全上下文
  ├── Service.yaml             ← ClusterIP（内部服务发现）
  ├── HPA.yaml                 ← HorizontalPodAutoscaler（V2, 双重指标）
  ├── PDB.yaml                 ← PodDisruptionBudget（minAvailable: 1）
  ├── ServiceAccount.yaml      ← IRSA 注解（eks.amazonaws.com/role-arn）
  └── NetworkPolicy.yaml      ← Calico 强制，默认拒绝，精确放行
```

---

### Level 4 — 代码图（Code）

展示生产环境微服务拆分后的代码包结构（以 order-svc 为例）。

```
order-svc/（独立 Maven module，groupId: com.smartinvest.order）
│
├── src/main/java/com/smartinvest/order/
│   │
│   ├── OrderServiceApplication.java   ← @SpringBootApplication
│   │
│   ├── domain/
│   │   ├── model/
│   │   │   ├── Order.java              ← 聚合根，@Entity, @Table
│   │   │   ├── OrderId.java            ← Value Object（DDD）
│   │   │   ├── OrderStatus.java        ← enum: PENDING/PROCESSING/COMPLETED/CANCELLED/FAILED
│   │   │   ├── OrderType.java          ← enum: ONE_TIME/MONTHLY_PLAN
│   │   │   └── Money.java              ← Value Object（HKD 货币）
│   │   ├── repository/
│   │   │   ├── OrderRepository.java     ← JpaRepository, @Query 方法
│   │   │   └── OrderRepositoryCustom.java  ← 复杂查询实现
│   │   ├── event/
│   │   │   ├── OrderCreatedEvent.java   ← ApplicationEvent（发布）
│   │   │   └── OrderDomainEventPublisher.java  ← 领域事件发布器
│   │   └── service/
│   │       ├── OrderDomainService.java  ← 聚合根内业务逻辑
│   │       ├── IdempotencyChecker.java   ← Redis TTL=24h 幂等性
│   │       └── SagaOrchestrator.java    ← 超时补偿事务协调
│   │
│   ├── application/                     ← Application Layer（DDD）
│   │   ├── dto/
│   │   │   ├── PlaceOrderCommand.java    ← Command（入站）
│   │   │   └── OrderDTO.java             ← 转换后的视图对象
│   │   └── service/
│   │       └── OrderApplicationService.java  ← @Transactional，编排领域服务
│   │
│   ├── infrastructure/
│   │   ├── persistence/
│   │   │   └── OrderJpaRepository.java   ← JPA 实现
│   │   ├── messaging/
│   │   │   └── EventBridgePublisher.java ← 出站事件发布
│   │   ├── resilience/
│   │   │   └── CircuitBreakerConfig.java← Resilience4j 配置
│   │   └── cache/
│   │       └── RedisIdempotencyService.java  ← Redis TTL 幂等检查
│   │
│   └── api/
│       ├── controller/
│       │   └── OrderController.java       ← REST 入口，/api/v1/orders
│       ├── advice/
│       │   └── OrderExceptionHandler.java← @RestControllerAdvice
│       └── security/
│           └── OrderSecurityConfig.java   ← Spring Security 配置
│
└── src/main/resources/
    ├── application.yml                   ← Spring 配置（profiles: prod）
    ├── db/migration/                    ← Flyway 迁移（order-svc 专用）
    │   ├── V1__create_orders.sql
    │   └── V2__create_order_audit_log.sql
    └── config.yaml                      ← K8s ConfigMap（环境变量注入）
```

---

## 二、架构五视图（5-View Architecture）

---

### 2.1 逻辑视图（Logical View）

从业务功能角度分解系统，展示服务边界、职责划分及核心业务规则。

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                          Smart Invest — Logical View                                      │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         业务能力分解（Bounded Contexts）                             │  │
│  │                                                                                     │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  │  用户与认证     │  │  基金目录       │  │  订单与交易     │  │  持仓与盈亏     │ │
│  │  │  Bounded       │  │  Bounded        │  │  Bounded        │  │  Bounded       │ │
│  │  │  Context       │  │  Context        │  │  Context ★★★   │  │  Context       │ │
│  │  │                │  │                 │  │  金融核心        │  │                │ │
│  │  │  · 用户注册    │  │  · 基金浏览     │  │  · 订单创建     │  │  · 持仓查询    │ │
│  │  │  · 登录认证    │  │  · 净值查询     │  │  · 订单取消     │  │  · 市值计算    │ │
│  │  │  · 风险评估    │  │  · 资产配置     │  │  · 状态流转     │  │  · 盈亏计算    │ │
│  │  │  · 用户画像    │  │  · 持仓明细     │  │  · 幂等性保证  │  │  · 组合汇总    │ │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  │
│  │           │                    │                    │                    │           │
│  │           ▼                    ▼                    ▼                    ▼           │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                        共享内核（Shared Kernel）                            │ │  │
│  │  │  UserId (Value Object)  ·  Money (HKD)  ·  RiskLevel (enum)  ·  AssetClass│ │  │
│  │  └─────────────────────────────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         服务间事件流（Event Storming 视角）                         │  │
│  │                                                                                     │  │
│  │  user-svc          fund-svc          order-svc       portfolio-svc    plan-svc    │  │
│  │     │                 │                 │                │                │         │  │
│  │     │ UserRegistered │                 │                │                │         │  │
│  │     │──────────────► │                 │                │                │         │  │
│  │     │                 │                 │                │                │         │  │
│  │     │                 │  Fund NAV Updated               │                │         │  │
│  │     │                 │──────────────► │                │                │         │  │
│  │     │                 │                 │                │                │         │  │
│  │     │                 │                 │ OrderCreated ◄────────────── │         │  │
│  │     │                 │                 │   (EventBridge)              │         │  │
│  │     │                 │                 │     │           │                │         │  │
│  │     │                 │                 │     ▼           ▼                │         │  │
│  │     │                 │                 │  notification  portfolio     │         │  │
│  │     │                 │                 │  -svc          -svc            │         │  │
│  │     │                 │                 │                 │                │         │  │
│  │     │                 │                 │ PlanExecuted ◄───────────────┘         │  │
│  │     │                 │                 │   (定时触发)                           │  │
│  └─────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         金融核心 — Order 状态机                                     │  │
│  │                                                                                     │  │
│  │    ┌──────────┐    ┌────────────┐    ┌────────────┐    ┌───────────┐              │  │
│  │    │ PENDING  │───►│ PROCESSING │───►│ COMPLETED  │    │ CANCELLED │              │  │
│  │    └──────────┘    └─────┬──────┘    └────────────┘    └───────────┘              │  │
│  │         │                │                                                      │  │
│  │         │                ▼                                                      │  │
│  │         │          ┌──────────┐    Saga 补偿:                                    │  │
│  │         └─────────►│  FAILED  │───► 恢复 Holding（如已扣除）                     │  │
│  │                    └──────────┘                                                  │  │
│  │                                                                                   │  │
│  │  幂等性键: reference_number（P-XXXXXX）存入 Redis，TTL=24h                       │  │
│  │  审计: 每个状态变更记录 pgaudit（写 orders_audit_log）                           │  │
│  └─────────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 2.2 开发视图（Development View）

从软件开发团队角度，描述代码组织、依赖管理和 GitOps 流水线。

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                         Smart Invest — Development View                                  │
│                                                                                          │
│  GitHub Repository 结构                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │
│  │  smart-invest/（Monorepo）                                                          │  │
│  │                                                                                     │  │
│  │  backend/                              frontend/         infra/                     │  │
│  │  ├── pom.xml（父 POM，版本管理）     ├── package.json  ├── terraform/（VPC/EKS/RDS） │  │
│  │  │                                    ├── src/          │      /modules/            │  │
│  │  ├── user-svc/                      │   ├── pages/     │      /environments/       │  │
│  │  ├── fund-svc/                      │   ├── api/       │                            │  │
│  │  ├── order-svc/                     │   └── hooks/     ├── helm/（Prometheus/ArgoCD）│  │
│  │  ├── portfolio-svc/                  └── Dockerfile      │                            │  │
│  │  ├── plan-svc/                                              k8s/                    │  │
│  │  ├── notification-svc/                                    ├── base/                 │  │
│  │  └── app/（可执行 JAR）                                    │   ├── namespace.yaml     │  │
│  │                                                              │   ├── networkpolicy.yaml │  │
│  │  .github/workflows/                                          │   └── irsa-roles/        │  │
│  │  ├── ci.yml（PR: 测试+SAST+镜像扫描）                      │   └── services/          │  │
│  │  ├── deploy-staging.yml                                    │       ├── user-svc/       │  │
│  │  └── deploy-prod.yml（Tag 触发，审批门）                   │       ├── fund-svc/        │  │
│  │                                                              │       └── ...             │  │
│  └─────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  GitOps CD 流水线（ArgoCD + Kustomize）                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                                                                     │  │
│  │  GitHub Actions                    ArgoCD（EKS 内运行）                            │  │
│  │  ┌──────────────────────┐           ┌─────────────────────────────────────────┐ │  │
│  │  │ mvn package          │           │  infra/k8s/overlays/prod/                 │ │  │
│  │  │ docker build         │           │  ┌─────────────────────────────────────┐  │ │  │
│  │  │ ECR push (tag: sha)  │──────────►│  │ image: 123456.ecr/.../order-svc:abc │  │ │  │
│  │  │ Sign image (cosign) │           │  │ kustomization.yaml                   │  │ │  │
│  │  │                      │           │  │   images:                             │  │ │  │
│  │  │ Update k8s/overlays/ │           │  │     - name: order-svc                 │  │ │  │
│  │  │   image tag → commit│           │  │       newTag: abc123                 │  │ │  │
│  │  │ git push             │           │  └─────────────────────────────────────┘  │ │  │
│  │  └──────────────────────┘           └─────────────┬───────────────────────────┘ │  │
│  │                                                    │ 自动 Sync（5 分钟轮询）       │  │
│  │                                                    ▼                               │  │
│  │                                        ┌─────────────────────────────┐            │  │
│  │                                        │ ArgoCD Rollout (Canary)    │            │  │
│  │                                        │ 10% → 30% → 100%            │            │  │
│  │                                        │ 分析: error rate < 1%       │            │  │
│  │                                        │ 持续时间: 10 分钟           │            │  │
│  │                                        └─────────────────────────────┘            │  │
│  │                                                    │ 滚动更新至 EKS                   │  │
│  │                                                    ▼                               │  │
│  │  ┌───────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │  EKS Cluster: smart-invest-prod  │  命名空间: smart-invest              │  │  │
│  │  │  Pod: order-svc-abc123-x2pqr      │  replicas: 2                       │  │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 2.3 进程视图（Process View）

描述运行时行为：请求如何经过 EKS 路由、Pod 如何扩缩容、事件如何异步流转。

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                         Smart Invest — Process View                                      │
│                                                                                          │
│  请求处理流程（用户下单，order-svc 为例）                                                    │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                                                                 │    │
│  │  用户浏览器 ──HTTPS──► Route 53 ──► CloudFront ──► ALB                      │    │
│  │                                              │                                 │    │
│  │                               WAF 检查（SQLi/XSS/Rate）  │                       │    │
│  │                                              │  通过                           │    │
│  │                                              ▼                                 │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐ │    │
│  │  │  ALB Target Group: order-svc-tg（跨 3 AZ 健康检查）                       │ │    │
│  │  │  目标: IP mode（EKS Pods，直连 VPC IP）                                   │ │    │
│  │  │  健康检查: /actuator/health  │ interval:10s │ threshold:2              │ │    │
│  │  └──────────────────────────────────────────┬──────────────────────────────┘ │    │
│  │                                               │                                   │    │
│  │  ┌──────────────────────────────────────────▼──────────────────────────────┐ │    │
│  │  │  EKS Pod (order-svc, Spring Boot JAR)                                    │ │    │
│  │  │                                                                           │ │    │
│  │  │  JwtAuthenticationFilter                                                 │ │    │
│  │  │    ├─ 验证 JWT RS256（公钥从 JWKS 端点获取）                             │ │    │
│  │  │    └─ 设置 SecurityContext                                               │ │    │
│  │  │                                                                           │ │    │
│  │  │  OrderController                                                          │ │    │
│  │  │    └─ OrderApplicationService.placeOrder(cmd)                             │ │    │
│  │  │         │                                                                 │ │    │
│  │  │    ┌─────▼────────────────────────────────────────────────────────┐    │ │    │
│  │  │    │  @Transactional                                                  │    │ │    │
│  │  │    │                                                                   │    │ │    │
│  │  │    │  ① IdempotencyChecker（Redis GET reference_number）              │    │ │    │
│  │  │    │     ├─ 已存在 ──► 返回原结果（防重复下单）                        │    │ │    │
│  │  │    │     └─ 不存在 ──► 继续                                           │    │ │    │
│  │  │    │                                                                   │    │ │    │
│  │  │    │  ② Resilience4j CircuitBreaker（调用 user-svc / fund-svc）        │    │ │    │
│  │  │    │     ├─ 熔断: failureRate > 50% → open（立即失败）                │    │ │    │
│  │  │    │     ├─ 降级: 返回友好错误信息                                     │    │ │    │
│  │  │    │     └─ 重试: 3 次，exponential backoff                            │    │ │    │
│  │  │    │                                                                   │    │ │    │
│  │  │    │  ③ OrderService.placeOrder()                                     │    │ │    │
│  │  │    │     ├─ 业务规则验证（金额、风险等级、最小投资额）                   │    │ │    │
│  │  │    │     ├─ OrderRepository.save(order) ──► Aurora Writer             │    │ │    │
│  │  │    │     │   (pgaudit 记录 INSERT)                                    │    │ │    │
│  │  │    │     ├─ Redis SET reference_number TTL=24h（幂等键）              │    │ │    │
│  │  │    │     └─ OrderCreatedEvent.publish() ──► EventBridge              │    │ │    │
│  │  │    │                                                                   │    │ │    │
│  │  │    │  ④ RedisIdempotencyService.set(reference_number, orderId)      │    │ │    │
│  │  │    │                                                                   │    │ │    │
│  │  └────┴─────────────────────────────────────────────────────────────────┘    │ │    │
│  │                                                                           │    │    │
│  │  EventBridge 路由：                                                           │    │    │
│  │    OrderCreated ──► [notification-svc, portfolio-svc]                      │    │    │
│  │                                                                                 │    │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                          │
│  弹性扩缩时序                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                                                                 │    │
│  │  时间          事件                        HPA 行为                            │    │
│  │  ─────        ───────                      ──────                            │    │
│  │  09:00 HKT   前盘准备                      fund-svc  2 → 6                   │    │
│  │  09:30 HKT   开市高峰                      order-svc  2 → 8                 │    │
│  │  10:00 HKT   持续高峰                     ALB 开始报告 latency ↑            │    │
│  │  12:00 HKT   午间休息                      缩容开始（stabilization=300s）   │    │
│  │  13:00 HKT   下午开盘                      扩容反弹                           │    │
│  │  16:00 HKT   收盘                         缩至 minReplicas=2               │    │
│  │  22:00 HKT   非交易时段                   spot-ng 缩至 0                     │    │
│  │                                                                                 │    │
│  │  Karpenter 供给 Node（如 Node 不足）：                                        │    │
│  │    检测: Pod 处于 Pending > 30s                                              │    │
│  │    供给: 选择最优 Spot 实例（m5.large/c5.large 混用）                        │    │
│  │    加入: Cluster Autoscaler 接受新 Node，调度 Pending Pods                   │    │
│  │                                                                                 │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 2.4 物理视图（Physical View）

展示 AWS 生产基础设施的完整拓扑，包括多账号结构、VPC 分层、Aurora Global DB 和安全控制。

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                     Smart Invest — Physical View（生产环境）                              │
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐  │
│  │              AWS Organizations（多账号结构）                                        │  │
│  │                                                                                   │  │
│  │   Root                                                                             │  │
│  │   ├── Management Account（主账号，账单 + SCP 管理）                                 │  │
│  │   │                                                                               │  │
│  │   ├── Security Tools OU                                                           │  │
│  │   │   └── security-tools-acct                                                     │  │
│  │   │           ├── Security Hub（聚合所有账号安全发现）                             │  │
│  │   │           ├── GuardDuty（威胁检测）                                           │  │
│  │   │           ├── CloudTrail（Org Trail，S3 WORM）                               │  │
│  │   │           └── AWS Config（合规配置记录）                                       │  │
│  │   │                                                                               │  │
│  │   └── Production OU                                                               │  │
│  │       └── production-acct                                                        │  │
│  │               │                                                                   │  │
│  │               │ SCP: DenyLeavingOrg │ RequireMFA │ DenyRegionsExcept us-east-1 │  │
│  │               │                                                                   │  │
│  └───────────────┼───────────────────────────────────────────────────────────────────┘  │
│                  │                                                                       │
│                  ▼                                                                       │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐  │
│  │                 production-acct — VPC 10.0.0.0/16 (us-east-1)                    │  │
│  │                                                                                   │  │
│  │   ┌───────────────────────────────────────────────────────────────────────────┐  │  │
│  │   │  Public Subnets（3 AZ，/24 each）                                          │  │  │
│  │   │                                                                           │  │  │
│  │   │  AZ-a ──► NAT Gateway-a ──► NAT Gateway-a 的 EIP（出站流量）              │  │  │
│  │   │  AZ-b ──► NAT Gateway-b ──► NAT Gateway-b 的 EIP                         │  │  │
│  │   │  AZ-c ──► NAT Gateway-c ──► NAT Gateway-c 的 EIP                         │  │  │
│  │   │                                                                           │  │  │
│  │   │  ALB（跨 3 AZ，Internet-facing）                                          │  │  │
│  │   │  SG: 仅接受 CloudFront prefix list（443）                                │  │  │
│  │   └───────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                   │  │
│  │   ┌───────────────────────────────────────────────────────────────────────────┐  │  │
│  │   │  Private Subnet — App Tier（3 AZ，10.0.16.0/20）                        │  │  │
│  │   │                                                                           │  │  │
│  │   │  AZ-a ──► EKS Node（app-ng，m5.large On-Demand）──► user/fund/order/Pod │  │  │
│  │   │  AZ-b ──► EKS Node（app-ng）──► Pod（跨 AZ topologySpread）            │  │  │
│  │   │  AZ-c ──► EKS Node（app-ng + spot-ng）──► Spot Pods                   │  │  │
│  │   │              │                                                           │  │  │
│  │   │              │ AZ-a ──► EKS Node（system-ng，t3.medium）              │  │  │
│  │   │              │                                                           │  │  │
│  │   │  EKS 集群: smart-invest-prod（私有 API Server，无公网端点）              │  │  │
│  │   │  Addon: AWS LBC │ Karpenter │ CoreDNS │ Metrics Server │                │  │  │
│  │   │         Karpenter │ cert-manager │ Prometheus │ Fluent Bit │ Calico  │  │  │
│  │   │                                                                           │  │  │
│  │   │  VPC Endpoints（Interface，流量不离开 AWS 网络）:                        │  │  │
│  │   │    ├─ S3 Gateway Endpoint（app tier → S3）                             │  │  │
│  │   │    ├─ Secrets Manager Endpoint（Pod → SecretsMgr）                    │  │  │
│  │   │    ├─ ECR API / ECR DKR Endpoint（Pod → ECR）                         │  │  │
│  │   │    ├─ SSM Endpoint（Karpenter → SSM）                                  │  │  │
│  │   │    └─ CloudWatch Logs Endpoint（Pod → CloudWatch）                     │  │  │
│  │   └───────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                   │  │
│  │   ┌───────────────────────────────────────────────────────────────────────────┐  │  │
│  │   │  Private Subnet — Data Tier（3 AZ，10.0.32.0/20）                       │  │  │
│  │   │                                                                           │  │  │
│  │   │  ┌─────────────────────────────────────────────────────────────────────┐ │  │  │
│  │   │  │  Aurora PostgreSQL Global Database                                  │ │  │  │
│  │   │  │  Cluster: smart-invest-global                                       │ │  │  │
│  │   │  │                                                                     │ │  │  │
│  │   │  │  Primary (us-east-1):                                              │ │  │  │
│  │   │  │    AZ-a: Writer (db.r6g.large, KMS CMK 加密)                      │ │  │  │
│  │   │  │    AZ-b: Reader (db.r6g.large)                                     │ │  │  │
│  │   │  │    AZ-c: Reader (db.r6g.large)                                     │ │  │  │
│  │   │  │    pgaudit: write+ddl │ IAM Auth │ Deletion Protection            │ │  │  │
│  │   │  │                                                                     │ │  │  │
│  │   │  │  Secondary (us-west-2, DR):                                       │ │  │  │
│  │   │  │    AZ-a: Reader（可在 <1 分钟内提升为 Global Primary）              │ │  │  │
│  │   │  └─────────────────────────────────────────────────────────────────────┘ │  │  │
│  │   │                                                                           │  │  │
│  │   │  ┌─────────────────────────────────────────────────────────────────────┐ │  │  │
│  │   │  │  Amazon ElastiCache Redis 7                                        │ │  │  │
│  │   │  │  3 Shards × 2 Replicas（每 Shard: 1 主 + 2 副本，Multi-AZ）        │ │  │  │
│  │   │  │  auth token │ TLS in-transit │ 集群模式                           │ │  │  │
│  │   │  │  用途: NAV 缓存(5min) │ Holdings 缓存(30s) │ 幂等键(24h)          │ │  │  │
│  │   │  └─────────────────────────────────────────────────────────────────────┘ │  │  │
│  │   │                                                                           │  │  │
│  │   │  RDS Proxy: smart-invest-proxy                                         │  │  │
│  │   │    IAM Auth │ Secrets Manager 自动轮换 │ maxConn=1000                 │  │  │
│  │   └───────────────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  AWS Backup（跨账号复制）: daily 35d │ weekly 1y │ monthly 7y │ Vault Lock (WORM)     │
│                                                                                          │
│  S3: smart-invest-frontend-prod（KMS CMK 加密 │ 版本控制 │ OAC │ CloudFront 唯一入口）│
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

**Aurora Global Database 拓扑详图**

```
Aurora Global: smart-invest-global (us-east-1 ←─── Global Replication ───→ us-west-2)

us-east-1（主 Region）
│
├── DB Cluster: smart-invest-db
│   │
│   ├── Writer Instance
│   │     Instance: db.r6g.large
│   │     AZ: us-east-1a
│   │     KMS: smart-invest/aurora（CMK 加密）
│   │     IAM Auth: ENABLED
│   │     pgaudit: 'write, ddl, function'
│   │     log_connections: on
│   │     log_disconnections: on
│   │     synchronous_commit: on
│   │     wal_level: logical
│   │
│   ├── Reader Instance ①
│   │     Instance: db.r6g.large
│   │     AZ: us-east-1b
│   │     自动同步自 Writer（< 1s 复制延迟）
│   │
│   └── Reader Instance ②
│         Instance: db.r6g.large
│         AZ: us-east-1c
│
└── Storage Layer（6 副本，AZ 间自动复制）
      最大容量: 128 TB（Aurora Auto Scaling）
      备份: 连续备份（PITR，35 天）
      删除保护: ENABLED

us-west-2（DR Region，Secondary）
│
└── Aurora Cluster: smart-invest-db-us-west-2
      可通过 failover-global-cluster 在 <1 分钟内提升为 Global Primary
      用于跨区域灾备（DR）
      演练: 每季度执行 DR Runbook

RDS Proxy（us-east-1，Application Tier）
│
└── Proxy Endpoints: smart-invest-proxy
      ├── IAM Auth: ENABLED（无密码，Token 来自 IRSA）
      ├── Secrets Manager 集成: 密码每 30 天自动轮换
      ├── Connection pool: max 1000
      ├── Failover 感知: Aurora Writer 切换时 Proxy 自动重路由
      └── Target: Aurora Cluster（Writer + Readers 负载均衡）
```

---

### 2.5 场景视图（Scenario View）

通过关键场景的时序图，展示系统在生产环境中的典型行为与故障恢复路径。

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                         Smart Invest — Scenario View                                      │
│                                                                                          │
│  场景 A：用户 Pathway A 下单（生产环境微服务版）                                            │
│  ──────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  用户(浏览器)      ALB         order-svc Pod    user-svc Pod   fund-svc Pod   Aurora/RDS  │
│       │             │              │               │              │              │        │
│       │ POST /api/v1/orders        │               │              │              │        │
│       │────────────────────────────►│               │              │              │        │
│       │             │              │               │              │              │        │
│       │        WAF 检查            │               │              │              │        │
│       │             │              │               │              │              │        │
│       │        路由至 Pod          │               │              │              │        │
│       │             │──────────────►│               │              │              │        │
│       │             │              │               │              │              │        │
│       │             │       ┌─────▼──────┐        │              │              │        │
│       │             │       │ JWT 验证   │        │              │              │        │
│       │             │       │ 幂等检查   │        │              │              │        │
│       │             │       │ (Redis)   │        │              │              │        │
│       │             │       └─────┬──────┘        │              │              │        │
│       │             │              │               │              │              │        │
│       │             │    熔断器 CircuitBreaker    │              │              │        │
│       │             │       ├─ GET /internal/users/{id}/status   │              │        │
│       │             │       │────────────────────────────────────►│              │        │
│       │             │       │◄────────────────────────────────────│ user record  │
│       │             │       │               │              │              │        │
│       │             │       ├─ GET /internal/funds/{code}/price │              │        │
│       │             │       │───────────────────────────────────────────►│        │
│       │             │       │◄───────────────────────────────────────────│ nav data   │
│       │             │       └───────┬───────────┘              │              │        │
│       │             │               │                          │              │        │
│       │             │    @Transactional                       │              │        │
│       │             │    BEGIN ISOLATION LEVEL SERIALIZABLE   │              │        │
│       │             │               │───────► INSERT orders ───────────────►│ INSERT   │
│       │             │               │◄────── ◄────────────────────────────│ order_id │
│       │             │               │───────► UPSERT holdings ────────────►│ UPSERT  │
│       │             │               │◄────── ◄────────────────────────────│ holding  │
│       │             │               │───────────────────────────────────────│ pgaudit  │
│       │             │               │ COMMIT                               │        │
│       │             │               │                                      │        │
│       │             │    Redis SET order:ref:P-123456 TTL=86400           │        │
│       │             │               │              │              │              │        │
│       │             │    EventBridge Publish: order.created              │              │
│       │             │               │─────────────────────────────────────►│        │
│       │             │               │              │              │              │        │
│       │  201 Created│               │              │              │              │        │
│       │◄────────────────────────────│              │              │              │        │
│       │             │               │              │              │              │        │
│  ─────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  场景 B：Aurora 可用区故障自动恢复                                                         │
│  ──────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  Aurora AZ-a Writer 故障                                                                  │
│       │                                                                                  │
│       ▼                                                                                  │
│  [0-30s] Aurora 检测 Writer无响应，标记为不可用                                            │
│       │                                                                                  │
│       ▼                                                                                  │
│  [30-60s] Aurora 自动提升 AZ-b Reader 为 Writer                                           │
│       │    DNS cluster endpoint 自动更新指向新 Writer                                     │
│       │                                                                                  │
│       ▼                                                                                  │
│  [60-90s] RDS Proxy 感知新 Writer，主动断开旧连接，重路由至新 Writer                      │
│       │    HikariCP 连接池检测连接异常，销毁并重建                                        │
│       │                                                                                  │
│       ▼                                                                                  │
│  [90-120s] order-svc Pod 中 Resilience4j 熔断器短时触发（<5s）                            │
│       │    Spring Retry 自动重试失败的 DB 操作                                           │
│       │    最终恢复业务处理                                                               │
│       │                                                                                  │
│       ▼                                                                                  │
│  PagerDuty 告警 ──► on-call 工程师收到 P1 告警                                            │
│       │    执行 Post-mortem，分析根因                                                   │
│       │    评估是否需要调整 Pod topologySpreadConstraints                                │
│       │                                                                                  │
│       ▼                                                                                  │
│  结果: RTO < 2 分钟，RPO = 0（无数据丢失）                                                │
│                                                                                          │
│  ─────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  场景 C：Spot 实例中断时的 Pod 迁移                                                         │
│  ──────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  AWS EC2 Spot 中断通知（2 分钟警告）                                                       │
│       │                                                                                  │
│       ▼                                                                                  │
│  Karpenter 检测: spot-ng Node 即将回收                                                    │
│       │    识别受影响 Pod（spot 实例上，非关键批处理任务）                                 │
│       │                                                                                  │
│       ▼                                                                                  │
│  K8s Node Lifecycle Controller 触发优雅驱逐（graceful eviction）                          │
│       │    Pod 收到 SIGTERM，优雅终止（terminationGracePeriodSeconds: 30）                │
│       │    Prometheus 停止向该 Pod 抓取指标                                               │
│       │    ALB 从 Target Group 移除该 Pod（health check 失败检测）                       │
│       │                                                                                  │
│       ▼                                                                                  │
│  Karpenter provision 新 Node（Spot，m5.large，从多可用区选择）                             │
│       │    新 Pod schedule 到新 Node                                                    │
│       │                                                                                  │
│       ▼                                                                                  │
│  新 Pod 就绪（Readiness Probe 通过）                                                       │
│       │    ALB 自动添加回 Target Group                                                   │
│       │    业务恢复正常（中断时间: < 2 分钟）                                              │
│       │    注意: spot-ng 上运行的是非关键任务，关键业务服务在 On-Demand app-ng 上不受影响  │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、全链路可观测性

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        全链路可观测性 — Observability Stack                               │
│                                                                                         │
│   应用层（Pods）                                                                         │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │  Spring Boot Actuator (/actuator/prometheus)   ← Micrometer SDK               │   │
│   │  Micrometer Custom Metrics（RED Metrics，JVM，business KPIs）                  │   │
│   │  OpenTelemetry SDK（分布式追踪，traceId 注入每个日志行）                          │   │
│   │                                                                                │   │
│   │  日志格式（JSON 结构化）:                                                        │   │
│   │  {"timestamp","level","service","traceId","spanId","message","userId"...}     │   │
│   └────────────────────────────────┬─────────────────────────────────────────────┘   │
│                                    │                                                  │
│                          Fluent Bit DaemonSet                                         │
│                                    │                                                  │
│              ┌────────────────────┼────────────────────┐                             │
│              │                     │                     │                             │
│              ▼                     ▼                     ▼                             │
│   ┌──────────────────┐  ┌───────────────────┐  ┌──────────────────────┐                │
│   │ CloudWatch Logs  │  │ Amazon S3         │  │ Amazon OpenSearch     │                │
│   │ 热存储: 90 天     │  │ 归档: 7 年         │  │ 可选: 高级日志分析     │                │
│   │ (KMS CMK 加密)  │  │ (Glacier, WORM)  │  │ (Kibana 可视化)      │                │
│   └──────────────────┘  └───────────────────┘  └──────────────────────┘                │
│                                                                                         │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    Prometheus + Grafana Stack                                 │   │
│   │                                                                                │   │
│   │  kube-prometheus-stack（Helm）                                                  │   │
│   │    ├─ Prometheus Server（指标采集，90 天保留）                                    │   │
│   │    ├─ Alertmanager（P1/P2 告警路由）                                           │   │
│   │    ├─ node-exporter（基础设施指标）                                             │   │
│   │    ├─ kube-state-metrics（K8s 资源状态）                                        │   │
│   │    └─ prometheus-adapter（HPA 自定义指标）                                      │   │
│   │                                                                                │   │
│   │  Grafana Dashboards（托管版 AMG）                                               │   │
│   │    ├─ SLO Dashboard（SLO: 99.9%，Error Budget）                                │   │
│   │    ├─ RED Metrics per Service（P50/P95/P99）                                   │   │
│   │    ├─ JVM Dashboard（Heap/GC/Threads）                                         │   │
│   │    ├─ Aurora Dashboard（连接/复制延迟/慢查询）                                  │   │
│   │    └─ Business Metrics（订单量/活跃用户/定投执行率）                             │   │
│   │                                                                                │   │
│   └────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    AWS X-Ray + OpenTelemetry Collector                       │   │
│   │                                                                                │   │
│   │  X-Ray Daemon（Sidecar，每 Pod）                                                │   │
│   │    追踪: HTTP Request ──► ALB ──► order-svc ──► user-svc ──► Aurora           │   │
│   │                                                                                │   │
│   │  OpenTelemetry Collector（DaemonSet）                                            │   │
│   │    统一收集 Metrics + Logs + Traces，发往 AWS 原生服务                          │   │
│   └────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│   告警路由:                                                                              │
│   CloudWatch Alarms / Alertmanager ──► SNS ──► Lambda ──► PagerDuty（P1 立即）       │
│                                                       ──► Slack（P2 延迟）            │
│                                                       ──► Email（P3 低优先级）        │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 四、安全架构（纵深防御）

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                          纵深防御 — Defense in Depth                                      │
│                                                                                         │
│  Layer 1: 边界安全                                                                       │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  CloudFront + WAF v2 + Shield Standard                                         │     │
│  │   ├─ Managed Rules: CommonRuleSet, SQLiRuleSet, XSSRuleSet, PHPRuleSet       │     │
│  │   ├─ Rate Limit: 2000 req/5min per IP（防暴力破解/CC）                          │     │
│  │   ├─ Bot Control: CAPTCHA for suspicious traffic                               │     │
│  │   ├─ Shield Standard: 基础 DDoS 防护（免费）                                    │     │
│  │   └─ CloudFront Function: JWT 有效性预检查（拒绝无效 Token，减少后端压力）         │     │
│  │                                                                               │     │
│  │  Route 53 DNSSEC: DNS 响应完整性验证                                           │     │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                         │
│  Layer 2: 网络安全                                                                       │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  Security Groups（白名单，No broad CIDR）                                       │     │
│  │   alb-sg:    Inbound 443 from CloudFront managed prefix list                   │     │
│  │   eks-node-sg: Inbound from alb-sg only（精确端口 per service）                │     │
│  │   aurora-sg: Inbound 5432 from eks-node-sg only                               │     │
│  │   redis-sg:  Inbound 6379 TLS from eks-node-sg only                            │     │
│  │                                                                               │     │
│  │  Kubernetes Network Policy（Calico，Default Deny All）                         │     │
│  │   仅允许: alb-sg → service:8080                                               │     │
│  │          service-a → service-b（精确双向授权）                                 │     │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                         │
│  Layer 3: 身份与访问管理                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  AWS Organizations + SCPs: DenyLeavingOrg │ RequireMFA │ ApprovedRegionsOnly │     │
│  │  IRSA（每个 Pod 独立 Role，最小权限）                                            │     │
│  │  IAM Access Analyzer: 检测跨账号访问风险                                        │     │
│  │  CloudTrail: Org Trail，S3 WORM（7年），CloudTrail Insights                    │     │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                         │
│  Layer 4: 密钥与加密                                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  KMS CMK（客户管理密钥，每个用途独立）:                                           │     │
│  │   aurora/storage │ s3/objects │ logs/cloudwatch │ secrets                    │     │
│  │                                                                               │     │
│  │  Secrets Manager: 每 30 天自动轮换密码，IRSA 运行时注入                           │     │
│  │  Secrets Store CSI Driver: Pod 内直接挂载，无 K8s Secret 中间存储               │     │
│  │                                                                               │     │
│  │  TLS Everywhere: CloudFront→ALB(TLS1.2+)│ALB→Pod(TLS)│Pod→Aurora(sslmode=verify-full)│ │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                         │
│  Layer 5: 应用安全                                                                        │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  Spring Security: JWT RS256，HTTP-only Cookie（Refresh Token）                 │     │
│  │  输入验证: @Valid + Jakarta Validation API                                    │     │
│  │  限流: Resilience4j RateLimiter（每服务 100 req/s）                           │     │
│  │  CORS: 仅允许前端域名                                                          │     │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                         │
│  Layer 6: 容器安全                                                                        │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  ECR + Amazon Inspector: push 时自动 CVE 扫描（阻断高危漏洞）                   │     │
│  │  Kyverno Image Signing Policy: 只允许 GitHub Actions 签名的镜像运行            │     │
│  │  Pod Security Standards: restricted 级别（非 root │ 只读根文件系统 │ 能力降权）  │     │
│  │  Pod topologySpreadConstraints: 强制 Pod 跨 AZ 分布                            │     │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                         │
│  Layer 7: 威胁检测                                                                        │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  GuardDuty: EC2 Runtime Monitoring │ S3 Protection │ IAM Protection │ EKS Audit│     │
│  │  Security Hub: 聚合 GuardDuty + Config + Inspector 发现，按严重性分级            │     │
│  │  AWS Config: Conformance Pack: AWS-FinancialServicesBestPractices             │     │
│  │  CloudWatch Log Insights: 异常登录模式检测（同一 IP 多账号失败登录）               │     │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                         │
│  Layer 8: 合规与审计                                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────┐     │
│  │  pgaudit: Aurora 所有写操作 + DDL 记录（不可关闭）                               │     │
│  │  操作日志: CloudTrail（不可篡改，S3 Object Lock WORM）                           │     │
│  │  数据库审计: AWS Backup Vault（WORM，7年，SFC 合规要求）                         │     │
│  │  PCI-DSS v4.0 对齐: TLS │ KMS │ 审计日志 │ 访问控制                             │     │
│  │  SOC 2 Type II: CloudTrail + CloudWatch + GuardDuty + Config 持续覆盖            │     │
│  └───────────────────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 五、关键设计决策（SAP-C02 级别）

| 维度     | 决策                               | 选择                                                      | 权衡分析                                                               |
| ------ | -------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| 容器编排   | EKS（不用 ECS Fargate）              | 金融场景需要 NetworkPolicy（Calico）、PDB、Pod Security Standards | Fargate 无细粒度网络策略控制，EKS 更适合强安全合规场景                                  |
| 数据库    | Aurora PostgreSQL Global         | Global Database + Multi-AZ                              | 单 Region RDS failover > 1min；Aurora < 30s；Global DB 满足 RTO < 15min |
| 连接池    | RDS Proxy                        | IAM Auth + Secrets Manager 自动轮换                         | 应用无需重启密码即可轮换；Aurora failover 时 Proxy 透明切换                          |
| 密钥注入   | Secrets Store CSI Driver         | 不用 K8s Secret                                           | K8s Secret base64 存储在 etcd（非加密）；CSI 直接从 Secrets Manager 挂载，零中间存储   |
| GitOps | ArgoCD + Kustomize               | Canary Rollout + 自动漂移检测                                 | 蓝绿部署成本高；Canary 更适合金融场景渐进式发布                                        |
| 可观测性   | Prometheus + X-Ray + Fluent Bit  | 全开源 + AWS 原生集成                                          | 托管版（AMP/AMG）减少运维；不开源自建维护成本高                                        |
| IaC    | Terraform + Helm + Kustomize     | 不用 CDK                                                  | Terraform 模块生态成熟；Helm 管理复杂 Add-on；Kustomize 分环境差异                  |
| 镜像安全   | ECR + Inspector + Kyverno        | push 时扫描 + 运行时签名验证                                      | 供应链攻击防护；扫描但不禁令=形同虚设                                                |
| 成本治理   | Spot + Savings Plans + Karpenter | 最低优先级                                                   | 金融安全优先；Spot 仅用于无状态非关键任务；核心服务用 Savings Plans 锁定成本                   |

---

## 六、合规与治理框架对齐

| 框架                              | 核心要求                                            | Smart Invest 对应措施                                                       |
| ------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------- |
| AWS Well-Architected（5 pillars） | 运营卓越 / 安全 / 可靠性 / 性能效率 / 成本优化                   | ArgoCD · 纵深防御 · Aurora Multi-AZ · HPA + Spot · Savings Plans            |
| CIS EKS Benchmark               | Pod Security / RBAC / Network Policy            | restricted PSA · IRSA 最小权限 · Calico Deny-All                            |
| PCI-DSS v4.0                    | TLS · KMS · 审计日志 · 访问控制                         | 全链路 TLS · CMK · pgaudit + CloudTrail · SG 白名单                           |
| SOC 2 Type II                   | 持续监控 · 威胁检测 · 合规验证                              | GuardDuty + Security Hub + Config                                       |
| NIST CSF                        | Identify · Protect · Detect · Respond · Recover | IAM + SCP · WAF/Encryption · GuardDuty · EventBridge · Aurora Global DB |
| SFC 电子交易指引                      | 交易记录 7 年保留 · 不可篡改 · 灾难恢复                        | AWS Backup WORM · CloudTrail Object Lock · Aurora Global DR             |
