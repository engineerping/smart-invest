# Smart Invest — 原型阶段架构设计文档

**版本**: 2.0（修订）
**日期**: 2026-04-08
**阶段**: 产品原型（Proof of Concept）
**设计原则**: 快速验证业务假设，控制在 $200 AWS 积分预算内
**参考文档**: SmartInvest_ProjectRoadmap_v3.md · 2026-04-08-aws-deployment-plan-a.md

---

## 一、C4 架构模型（C4 Models）

C4 模型由 Simon Brown 提出，通过四个层次的图来描述系统：**上下文（Context）**、**容器（Container）**、**组件（Component）**、**代码（Code）**。每一层服务于不同的受众，逐层深入，从"系统是什么"到"代码怎么写"。

---

### Level 1 — 系统上下文图（System Context）

描述系统与外部世界的关系：谁在使用系统，系统与哪些外部系统交互。

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│    ┌──────────────┐      ┌─────────────────────────────────────────┐            │
│    │  终端用户     │      │         Smart Invest 基金投资平台           │            │
│    │  Mobile Web  │      │                                         │            │
│    │  浏览器      │      │   Spring Boot 模块化单体（EC2）           │            │
│    └──────┬───────┘      │   ┌─────────────────────────────────┐  │            │
│           │ HTTPS         │   │  user  fund  order  portfolio   │  │            │
│           │              │   │  plan  scheduler  notification  │  │            │
│           │              │   │  模块（Java 21, Maven 多模块）     │  │            │
│           │              │   └───────────────┬─────────────────┘  │            │
│           │              └──────────────────┼───────────────────┘            │
│           │                                 │                                │
│           │ HTTPS                           │                                │
│           │                                 │                                │
│    ┌──────▼───────────────────────┐         │                                │
│    │     Amazon CloudFront         │         │                                │
│    │  /api/*  →  EC2:443         │         │                                │
│    │  /*      →  S3               │         │                                │
│    └──────┬───────────────────────┘         │                                │
│           │                                 │                                │
│    ┌──────▼───────────────────────┐         │                                │
│    │   Amazon S3                  │         │                                │
│    │   React SPA（静态托管）       │         │                                │
│    └──────────────────────────────┘         │                                │
│                                             │                                │
└────────────────────────────────────────────┼────────────────────────────────┘
                                              │
                        ┌─────────────────────┼─────────────────────┐
                        │                     │                     │
                        ▼                     ▼                     ▼
               ┌──────────────────┐  ┌────────────────┐  ┌──────────────────┐
               │  Amazon SES      │  │ AWS Secrets    │  │ Amazon RDS       │
               │  邮件发送        │  │ Manager        │  │ PostgreSQL 16    │
               │  订单确认通知    │  │ DB 密码 / JWT   │  │ 原型数据库       │
               └──────────────────┘  └────────────────┘  └──────────────────┘
```

**干系人与系统边界说明**

| 元素                  | 类型        | 说明                              |
| ------------------- | --------- | ------------------------------- |
| 终端用户                | 人员（Actor） | 25-45 岁香港地区投资者，Mobile Web 浏览器访问 |
| CloudFront          | 外部系统      | HTTPS 终止、静态资源 CDN、路由分发          |
| Amazon SES          | 外部系统      | 订单确认邮件、定投计划到期通知                 |
| AWS Secrets Manager | 外部系统      | DB 密码、JWT 密钥的安全存储与运行时注入         |
| Amazon RDS          | 外部系统      | PostgreSQL 16，Aurora 在原型阶段不使用   |

---

### Level 2 — 容器图（Container）

描述系统的高层技术架构：有哪些应用进程/容器，各自负责什么，如何通信。

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Smart Invest — Container 视图                           │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                        Amazon CloudFront CDN                          │   │
│   │                      (HTTPS 终止, /api/* 路由)                        │   │
│   └─────────────────────────────┬────────────────────────────────────────┘   │
│                                 │                                              │
│           ┌─────────────────────┴─────────────────────┐                       │
│           │                                       │                          │
│           ▼                                       ▼                          │
│   ┌───────────────────┐                   ┌─────────────────────┐            │
│   │   Amazon S3       │                   │  Amazon EC2 t3.micro│            │
│   │   Static Hosting  │                   │  ┌───────────────┐  │            │
│   │                   │                   │  │ Nginx          │  │            │
│   │  React SPA        │                   │  │ 反向代理 :443  │  │            │
│   │  (index.html +    │                   │  │ SSL 终止       │  │            │
│   │   JS/CSS bundles) │                   │  └───────┬───────┘  │            │
│   │                   │                   │          │ :8080     │            │
│   └───────────────────┘                   │  ┌───────▼────────┐  │            │
│                                           │  │ Spring Boot    │  │            │
│                                           │  │ JAR (JVM 21)   │  │            │
│                                           │  │                │  │            │
│                                           │  │ 8 个 Spring    │  │            │
│                                           │  │ 模块在同一个    │  │            │
│                                           │  │ JVM 进程内      │  │            │
│                                           │  └───────┬────────┘  │            │
│                                           │          │ :5432     │            │
│                                           │  ┌───────▼────────┐  │            │
│                                           │  │ PostgreSQL 16  │  │            │
│                                           │  │ (Docker 容器)  │  │            │
│                                           │  └────────────────┘  │            │
│                                           └─────────────────────┘              │
│                                                                              │
│   ┌───────────────────────┐                 ┌─────────────────────────────┐    │
│   │  Amazon SES           │                 │  AWS Secrets Manager        │    │
│   │  邮件发送服务          │                 │  密钥存储（运行时注入）       │    │
│   └───────────────────────┘                 └─────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

**容器说明**

| 容器              | 技术                       | 职责                 | 部署位置               |
| --------------- | ------------------------ | ------------------ | ------------------ |
| React SPA       | React 18 + Vite          | 用户界面，Mobile Web    | Amazon S3          |
| Nginx           | Nginx                    | 反向代理，SSL 终止，静态资源服务 | EC2 t3.micro       |
| Spring Boot JAR | Java 21, Spring Boot 3.3 | 全部业务逻辑（8 个模块）      | EC2 t3.micro       |
| PostgreSQL 16   | PostgreSQL + Flyway      | 持久化存储，DB 迁移        | EC2 Docker Compose |
| Amazon SES      | AWS SDK v2               | 邮件发送               | AWS 托管             |
| Secrets Manager | AWS SDK v2               | 密钥安全存储             | AWS 托管             |

---

### Level 3 — 组件图（Component）

描述每个容器内部的主要组件及其职责。本系统容器为 Spring Boot JAR，以下展示核心组件。

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                   Spring Boot JAR — Component 视图                              │
│                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │                        SmartInvestApplication.java                        │  │
│  │                           (Spring Boot 主入口)                           │  │
│  └────────────────────────────────┬─────────────────────────────────────────┘  │
│                                   │                                              │
│  ┌──────────────┬─────────────────┼────────────────┬────────────────┐       │
│  │              │                 │                │                │         │
│  ▼              ▼                 ▼                ▼                ▼         │
│ ┌─────────┐ ┌─────────┐   ┌─────────────┐ ┌──────────────┐ ┌─────────────┐   │
│ │ user    │ │  fund   │   │   order     │ │  portfolio   │ │   plan     │   │
│ │ module  │ │ module  │   │   module    │ │  module      │ │   module   │   │
│ └────┬────┘ └────┬────┘   └──────┬──────┘ └──────┬─────┘ └──────┬──────┘   │
│      │           │              │               │              │            │
│ ┌────▼───────────▼──────────────▼───────────────▼──────────────▼──────┐    │
│ │                    Spring MVC Layer (REST Controllers)                  │    │
│ │                                                                        │    │
│ │  AuthController    FundController    OrderController   PortfolioCtrl  │    │
│ │  UserController   NavController     PlanController    RiskController │    │
│ └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │  ApplicationEvent (Spring Events)        │
│                          ┌────────▼────────┐                                 │
│                          │ notification    │                                 │
│                          │ module          │                                 │
│                          │                 │                                 │
│                          │ EmailService    │                                 │
│                          │ (AWS SES)       │                                 │
│                          └─────────────────┘                                 │
│                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │                       Scheduler Module（内部调度）                        │  │
│  │  MonthlyPlanScheduler (@Scheduled) ──► 扫描到期计划 ──► 创建 Order        │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │                       Shared Infrastructure                              │  │
│  │  JwtAuthenticationFilter  GlobalExceptionHandler  JwtTokenProvider      │  │
│  │  SecurityConfig           AwsConfig             FlywayConfig           │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │                           Database Layer                                 │  │
│  │                                                                        │  │
│  │  users  funds  fund_nav_history  orders  holdings                     │  │
│  │  investment_plans  risk_assessments  reference_asset_mix              │  │
│  │  (Flyway 迁移管理, schema 版本化)                                       │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────────┘
```

**组件职责矩阵**

| 组件包                 | 聚合根/实体               | 主要 Service                      | REST API 前缀                                     | 外部依赖                     |
| ------------------- | -------------------- | ------------------------------- | ----------------------------------------------- | ------------------------ |
| user-module         | User, RiskAssessment | UserService, AuthService        | `/api/auth/**`, `/api/users/**`, `/api/risk/**` | JWT, SES                 |
| fund-module         | Fund, FundNavHistory | FundService                     | `/api/funds/**`                                 | —                        |
| order-module        | Order                | OrderService                    | `/api/orders/**`                                | user, fund, notification |
| portfolio-module    | Holding              | PortfolioService, PnLCalculator | `/api/portfolio/**`                             | fund                     |
| plan-module         | InvestmentPlan       | PlanService                     | `/api/plans/**`                                 | user, fund               |
| scheduler-module    | —                    | MonthlyPlanScheduler            | 内部调度                                            | plan, order              |
| notification-module | —                    | EmailService                    | 事件驱动                                            | SES                      |

---

### Level 4 — 代码图（Code）

展示关键类设计与包结构。以下为核心领域模型与 API 层代码组织。

```
com.smartinvest/
│
├── SmartInvestApplication.java          ← 主入口, @SpringBootApplication
│
├── user/
│   ├── domain/
│   │   ├── entity/
│   │   │   ├── User.java              ← 聚合根, @Entity
│   │   │   └── RiskAssessment.java    ← 值对象
│   │   ├── repository/
│   │   │   └── UserRepository.java    ← JpaRepository<User, UUID>
│   │   └── service/
│   │       ├── UserService.java
│   │       └── AuthService.java        ← JWT 签发/验证
│   ├── api/
│   │   ├── controller/
│   │   │   ├── AuthController.java     ← POST /api/auth/login
│   │   │   └── UserController.java      ← GET /api/users/me
│   │   └── dto/
│   │       ├── LoginRequest.java
│   │       ├── LoginResponse.java
│   │       └── UserResponse.java
│   └── config/
│       └── SecurityConfig.java          ← @Bean SecurityFilterChain
│
├── fund/
│   ├── domain/
│   │   ├── entity/
│   │   │   ├── Fund.java               ← 聚合根
│   │   │   ├── FundNavHistory.java
│   │   │   └── FundAssetAllocation.java
│   │   ├── repository/
│   │   │   └── FundRepository.java     ← JpaRepository
│   │   └── service/
│   │       └── FundService.java
│   └── api/
│       ├── controller/
│       │   └── FundController.java      ← GET /api/funds, GET /api/funds/{code}
│       └── dto/
│           ├── FundDetailResponse.java
│           └── NavHistoryResponse.java
│
├── order/
│   ├── domain/
│   │   ├── entity/
│   │   │   ├── Order.java              ← 聚合根, @Entity
│   │   │   ├── OrderStatus.java        ← enum: PENDING/COMPLETED/CANCELLED
│   │   │   └── OrderType.java          ← enum: ONE_TIME/MONTHLY_PLAN
│   │   ├── repository/
│   │   │   └── OrderRepository.java
│   │   └── service/
│   │       ├── OrderService.java       ← 下单逻辑, 状态机
│   │       └── OrderPlacedEvent.java   ← @ApplicationEvent
│   └── api/
│       ├── controller/
│       │   └── OrderController.java    ← POST/GET /api/orders
│       └── dto/
│           ├── PlaceOrderRequest.java
│           └── OrderResponse.java
│
├── portfolio/
│   ├── domain/
│   │   ├── entity/
│   │   │   └── Holding.java            ← 聚合根, @Entity
│   │   ├── repository/
│   │   │   └── HoldingRepository.java
│   │   └── service/
│   │       ├── PortfolioService.java
│   │       └── PnLCalculator.java     ← 市值与盈亏计算
│   └── api/
│       ├── controller/
│       │   └── PortfolioController.java
│       └── dto/
│           ├── HoldingResponse.java
│           └── PortfolioSummaryResponse.java
│
├── plan/
│   ├── domain/
│   │   ├── entity/
│   │   │   └── InvestmentPlan.java     ← 聚合根, @Entity
│   │   ├── repository/
│   │   │   └── InvestmentPlanRepository.java
│   │   └── service/
│   │       └── PlanService.java
│   ├── api/
│   │   └── controller/
│   │       └── PlanController.java
│   └── scheduler/
│       └── MonthlyPlanScheduler.java   ← @Scheduled(cron), @EnableScheduling
│
└── shared/
    ├── security/
    │   ├── JwtTokenProvider.java       ← JJWT 0.12.6, RS256
    │   └── JwtAuthenticationFilter.java
    └── exception/
        └── GlobalExceptionHandler.java  ← @RestControllerAdvice
```

**数据库 Schema（核心表）**

```
┌──────────────┐     ┌──────────────────────┐     ┌──────────────────┐
│    users     │     │   investment_plans  │     │      funds       │
├──────────────┤     ├──────────────────────┤     ├──────────────────┤
│ id (PK, UUID)│◄─┐  │ id (PK, UUID)       │     │ id (PK, UUID)   │
│ email        │  │  │ user_id (FK)         │────►│ code (UNIQUE)   │
│ password     │  │  │ fund_id (FK)         │────►│ name, type      │
│ full_name    │  │  │ monthly_amount       │     │ current_nav     │
│ risk_level   │  └──│ next_contribution_   │     │ risk_level      │
│ status       │     │ date                 │     │ annual_mgmt_fee  │
└──────────────┘     │ status               │     └────────┬─────────┘
       │            └──────────────────────┘              │
       │                   │                    ┌───────▼──────────┐
       ▼                   │                    │ fund_nav_history │
┌──────────────────┐       │                    ├──────────────────┤
│  risk_assessments│       │                    │ id, fund_id (FK) │
├──────────────────┤       │                    │ nav, nav_date    │
│ id, user_id (FK) │───────┘                    │ UNIQUE(fund_id,  │
│ answers (JSONB)  │                            │  nav_date)       │
│ total_score      │                            └──────────────────┘
│ risk_level       │
└──────────────────┘
                                            ┌──────────────────┐
┌──────────────────┐     ┌──────────────────┐│    holdings      │
│     orders       │     │ fund_asset_      │├──────────────────┤
├──────────────────┤     │ allocations      ││ id, user_id (FK) │
│ id (PK, UUID)    │────►│ ├──────────────┐ ││ fund_id (FK)     │
│ user_id (FK)     │     │ │ fund_id (FK)  │─┼│ total_units      │
│ fund_id (FK)     │     │ │ asset_class   │ ││ avg_cost_nav     │
│ type, amount     │     │ │ percentage    │ ││ total_invested   │
│ reference_number │     │ └──────────────┘ │└──────────────────┘
│ status           │     └──────────────────┘
│ settlement_date  │
└──────────────────┘
```

---

## 二、架构五视图（5-View Architecture）

---

### 2.1 逻辑视图（Logical View）

从功能角度分解系统，说明系统提供了哪些功能、服务和接口。

**模块化单体架构说明**

```
┌─────────────────────────────────────────────────────────┐
│         Smart Invest 模块化单体（Modular Monolith）      │
│                                                         │
│  各模块是独立的 Maven 子项目，有各自的:                    │
│    • domain/entity    (领域实体)                         │
│    • domain/repository  (数据访问)                       │
│    • service         (业务逻辑)                         │
│    • api/controller  (REST 接口)                        │
│    • config          (配置)                             │
│                                                         │
│  模块之间通过 Java 接口调用，不通过网络，                   │
│  完全在同一个 JVM 进程内完成，属于单体架构。                │
│                                                         │
│  迁移路径: 当某模块负载成为瓶颈时，                        │
│  可将其重构为独立微服务，其余模块保持不变。                 │
└─────────────────────────────────────────────────────────┘
```

**核心 API 端点设计**

```
认证与用户:
  POST /api/auth/register          ← 用户注册
  POST /api/auth/login             ← 登录，返回 JWT（Access + Refresh Token）
  GET  /api/users/me               ← 当前用户信息
  POST /api/risk/assess            ← 提交风险评估问卷

基金:
  GET  /api/funds                   ← 基金列表（支持 type/risk_level 筛选，排序）
  GET  /api/funds/{code}           ← 基金详情（NAV 图表数据 + 资产配置 + 持仓）
  GET  /api/funds/{code}/nav?from=&to=  ← 历史净值

持仓:
  GET  /api/portfolio/holdings      ← 用户持仓列表（含实时市值与盈亏）
  GET  /api/portfolio/summary      ← 持仓汇总（总市值，总盈亏）

订单:
  POST /api/orders                 ← 提交订单（单基金 / Pathway A）
  POST /api/orders/portfolio       ← 提交组合订单（Pathway C，多个 fund 同时下单）
  GET  /api/orders                 ← 订单历史（按月分组）
  GET  /api/orders/{ref}          ← 订单详情
  POST /api/orders/{ref}/cancel   ← 取消待处理订单

定投计划:
  GET  /api/plans                  ← 定投计划列表
  POST /api/plans                  ← 创建定投计划
  POST /api/plans/{id}/terminate   ← 终止定投计划
```

---

### 2.2 开发视图（Development View）

从软件开发团队的角度，描述代码如何组织、模块如何构建和依赖。

**Maven 多模块依赖关系**

```
smart-invest-parent (pom.xml)
│
├── module-user         ← 无内部依赖
├── module-fund         ← 依赖 module-user
├── module-portfolio    ← 依赖 module-user, module-fund
├── module-order        ← 依赖 module-user, module-fund, module-portfolio
├── module-plan         ← 依赖 module-user, module-fund, module-order
├── module-scheduler    ← 依赖 module-plan, module-order
├── module-notification ← 依赖 module-order（ApplicationEvent 监听）
│
└── app                 ← 依赖所有业务模块，可执行 JAR
```

**前端项目结构**

```
frontend/
├── src/
│   ├── api/
│   │   └── client.ts              ← Axios 实例 + JWT 请求拦截器
│   ├── pages/
│   │   ├── Auth/                  ← 登录/注册/风险评估流程
│   │   ├── Fund/                   ← 基金浏览/详情
│   │   ├── Portfolio/              ← 我的持仓/组合构建
│   │   ├── Order/                  ← 下单确认/我的交易
│   │   └── Plan/                   ← 我的定投计划
│   ├── components/                 ← 可复用 UI 组件（Button, Card, Modal...）
│   ├── hooks/                      ← useAuth, useFunds, usePortfolio, useOrders...
│   ├── stores/                    ← Zustand stores（authStore, portfolioStore...）
│   └── App.tsx                    ← React Router v6 路由配置
├── Dockerfile                      ← 生产构建
└── Dockerfile.dev                 ← 本地 Docker 开发（热重载）
```

---

### 2.3 进程视图（Process View）

描述运行时行为：请求如何流转、定时任务如何执行、并发如何处理。

**HTTP 请求全链路**

```
浏览器 ──HTTPS──► CloudFront ──► EC2:443 (Nginx)
                                    │
                                    │ 反向代理 → 127.0.0.1:8080
                                    ▼
                              Spring Boot (Tomcat)
                                    │
                          JwtAuthenticationFilter
                                    │ (从 Authorization Header 解析 JWT)
                                    │ Token 有效 → SecurityContextHolder → 放行
                                    │ Token 无效/缺失 → 401 (除 /api/auth/*)
                                    ▼
                              HandlerMapping (@RequestMapping)
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
        AuthController         FundController      OrderController
              │                     │                     │
        AuthService            FundService         OrderService
              │                     │                     │
        UserRepository         FundRepository      OrderRepository
              │                     │                OrderPlacedEvent
              │                     │                     │  ▼
              │                     │            EmailService (异步)
              │                     │               AWS SES
              │                     │                     │
              ◄─────────────────────────────────────────┘
                              JSON Response
```

**定时任务执行流**

```
MonthlyPlanScheduler (@Scheduled, 每分钟执行一次)
        │
        ▼
查询所有 InvestmentPlan
  WHERE status = 'ACTIVE'
  AND next_contribution_date <= CURRENT_DATE
        │
        ▼
对每个计划:
  ① OrderService.placeOrder()  ──► 创建 Order 记录
  ② 更新 Holding（如不存在则 INSERT，如存在则 UPDATE units）
  ③ 计算下一个扣款日（节假日顺延）
  ④ EmailService.sendPlanExecuted() ──► SES 发送通知
  ⑤ 记录调度执行日志（CloudWatch）
        │
        ▼
定时任务结束（下次执行: 1 分钟后）
```

---

### 2.4 物理视图（Physical View）

描述系统如何部署到基础设施，包含网络拓扑、资源规格和可用性配置。

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        原型阶段 — Physical View                               │
│                                                                             │
│   Internet                                                                 │
│      │                                                                     │
│      │ HTTPS                                                               │
│      ▼                                                                     │
│ ┌─────────────────────────────────────────────────────────────┐             │
│ │              Amazon CloudFront (us-east-1)                  │             │
│ │   分发域名: https://d1abc123.cloudfront.net                │             │
│ │   WAF: 基础 Rate Limiting                                   │             │
│ │   SSL: ACM 自动管理（免费）                                  │             │
│ │                                                              │             │
│ │   路由规则:                                                  │             │
│ │     /*       → S3 Origin (前端静态资源)                      │             │
│ │     /api/*   → EC2 Origin (HTTPS, :8080)                   │             │
│ └──────────────────────────────────┬──────────────────────────┘             │
│                                    │                                        │
│                    HTTPS (CloudFront 鉴权转发)                               │
│                                    ▼                                        │
│ ┌─────────────────────────────────────────────────────────────┐             │
│ │                    EC2 t3.micro                            │             │
│ │                   (us-east-1a, Amazon Linux 2023)           │             │
│ │                                                              │             │
│ │  ┌──────────────────────────────────────────────────────┐ │             │
│ │  │  Nginx :443                                           │ │             │
│ │  │  SSL 终止  │  静态文件缓存  │  请求转发 :8080         │ │             │
│ │  └──────────────────────────┬───────────────────────────┘ │             │
│ │                              │                            │             │
│ │  ┌──────────────────────────▼───────────────────────────┐ │             │
│ │  │  Docker Compose                                    │ │             │
│ │  │                                                    │ │             │
│ │  │  ┌────────────────┐  ┌─────────────────────────┐  │ │             │
│ │  │  │ Spring Boot JAR │  │ PostgreSQL 16 Alpine    │  │ │             │
│ │  │  │  port: 8080    │  │  port: 5432            │  │ │             │
│ │  │  │  JVM: 512MB    │  │  Health Check 开启      │  │ │             │
│ │  │  │  重启: always  │  │  Volume: postgres_data  │  │ │             │
│ │  │  └───────┬────────┘  └───────────┬─────────────┘  │ │             │
│ │  │          │                       │                │ │             │
│ │  │  ┌───────▼───────────────────────▼─────────────┐  │ │             │
│ │  │  │  IAM Role: smart-invest-ec2-role            │  │ │             │
│ │  │  │  权限: SecretsManagerRead, ECRPull, SES     │  │ │             │
│ │  │  └──────────────────────────────────────────────┘  │ │             │
│ │  └──────────────────────────────────────────────────────┘ │             │
│ └─────────────────────────────────────────────────────────────┘             │
│                                                                            │
│ ┌─────────────────────────────────────────────────────────────┐            │
│ │  Amazon S3 (smart-invest-frontend-prod)                    │            │
│ │  托管 React SPA  │ OAC 访问  │ 开启版本控制                   │            │
│ └─────────────────────────────────────────────────────────────┘            │
│                                                                            │
│ ┌──────────────────┐              ┌──────────────────────────────────┐    │
│ │ AWS Secrets Mgr   │              │ Amazon SES                       │    │
│ │ DB 密码           │              │ 邮件发送（注册确认/订单通知/定投到期）│    │
│ │ JWT 密钥          │              │ 沙盒模式（原型阶段）               │    │
│ └──────────────────┘              └──────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────────┘
```

**资源规格**

| 组件              | 规格                         | 成本/月        |
| --------------- | -------------------------- | ----------- |
| EC2 t3.micro    | 2 vCPU, 1 GB RAM, 8 GB EBS | ~$8         |
| S3              | ~100 MB 静态文件               | ~$0.03      |
| CloudFront      | 1 distribution             | ~$1         |
| Secrets Manager | 2 个密钥                      | ~$0.40      |
| SES             | 沙盒模式                       | Free        |
| **合计**          |                            | **~$9.5/月** |

---

### 2.5 场景视图（Scenario View）

通过关键用例的时序图，展示系统的核心行为路径。

**场景 A：用户完成 Pathway A 单基金下单（全时序）**

```
用户 (Mobile Web)          Spring Boot              PostgreSQL          AWS SES
      │                        │                        │                  │
      │ POST /api/orders       │                        │                  │
      │ {fundCode, amount:500} │                        │                  │
      │───────────────────────►│                        │                  │
      │                        │                        │                  │
      │                   ┌─────▼──────┐                │                  │
      │                   │ 验证 JWT   │                │                  │
      │                   │ 验证 fund  │                │                  │
      │                   │ 验证金额≥100│                │                  │
      │                   └──┬──────┬─┘                │                  │
      │                        │      │ SELECT fund WHERE │              │
      │                        │      │ code=?            │              │
      │                        │      │────────────────►││              │
      │                        │      │◄────────────────││ fund record
      │                        │      │                  │                  │
      │                        │ BEGIN TX                │                  │
      │                        │─────►│ INSERT orders   ││              │
      │                        │◄────│ order_id        ││              │
      │                        │      │                  │                  │
      │                        │      │ UPSERT holdings ││              │
      │                        │◄────│ holding updated ││              │
      │                        │ COMMIT                 │                  │
      │                        │                        │                  │
      │                   发布 OrderPlacedEvent         │                  │
      │                        │─────────────────────────────────────────►│
      │                        │   sendOrderConfirmationEmail()            │
      │                        │◄────────────────────────────────────────│ 邮件已提交
      │                        │                        │                  │
      │  201 Created           │                        │                  │
      │ {ref: P-123456,        │                        │                  │
      │  status: PENDING}      │                        │                  │
      │◄───────────────────────│                        │                  │
      │                        │                        │                  │
```

**场景 B：持仓市值实时计算**

```
用户                PortfolioController     PortfolioService     FundRepository   PostgreSQL
   │                        │                       │           │              │
   │ GET /api/portfolio/holdings                     │           │              │
   │───────────────────────►│                       │           │              │
   │                        │                       │           │              │
   │                   HOLDINGs.findByUserId()     │           │              │
   │                        │──────────────────────►│           │              │
   │                        │                       │──────────►│              │
   │                        │                       │◄─────────│ holdings[]
   │                        │                       │           │              │
   │                   对每个 Holding:             │           │              │
   │                   LATEST_NAV(fund_id)        │           │              │
   │                        │                       │──────────►│              │
   │                        │                       │◄─────────│ nav record    │
   │                        │                       │           │              │
   │                   market_value = units × nav │           │              │
   │                   unrealised_pnl =          │           │              │
   │                     (nav - avg_cost) × units │           │              │
   │                        │                       │           │              │
   │ 200 OK [{holding,...}] │                       │           │              │
   │◄───────────────────────│                       │           │              │
   │                        │                       │           │              │
```

**场景 C：月度定投计划自动执行**

```
MonthlyPlanScheduler        PlanService           OrderService       SES
      │                        │                      │                │
      │ (每分钟 cron)          │                      │                │
      │───────────────────────►│                      │                │
      │                        │                      │                │
      │ findDuePlans(today)    │                      │                │
      │◄───────────────────────│                      │                │
      │                        │                      │                │
      │ [Plan A, Plan B, ...]  │                      │                │
      │                        │                      │                │
      │ foreach Plan:           │                      │                │
      │   placeMonthlyOrder()    │                      │                │
      │   ─────────────────────►│                      │                │
      │                        │ INSERT order         │                │
      │                        │─────────────────────►│                │
      │                        │◄─────────────────────│ order created
      │                        │ UPSERT holding       │                │
      │                        │─────────────────────►│                │
      │                        │                      │                │
      │   advanceNextDate()    │                      │                │
      │   (顺延节假日)          │                      │                │
      │                        │                      │                │
      │   PlanExecutedEvent     │                      │                │
      │   ────────────────────────────────────────────►│                │
      │                        │                      │◄sendNotify()   │
      │                        │                      │                │
```

---

## 三、关键设计决策

| 决策    | 选择                | 理由                                      |
| ----- | ----------------- | --------------------------------------- |
| 架构风格  | 模块化单体             | $200 预算下单 EC2 成本优先；无网络开销；模块边界清晰，未来可独立拆分 |
| 定时任务  | Spring @Scheduled | 原型阶段无需独立调度基础设施；一个 EC2 足够                |
| 密钥管理  | Secrets Manager   | 代码中无硬编码密钥；EC2 IAM Role 最小权限             |
| 前端部署  | S3 + CloudFront   | 静态 SPA 无需服务器；CloudFront 提供 HTTPS + CDN  |
| CI/CD | GitHub Actions    | 零基础设施成本；与 GitHub 原生集成                   |

---

## 四、非功能性需求

| 维度  | 目标                      | 说明                                 |
| --- | ----------------------- | ---------------------------------- |
| 性能  | API P99 < 500ms         | 单 EC2 + HikariCP 连接池（max=10）满足原型规模 |
| 可用性 | 月正常运行率 99%              | EC2 Auto Recovery；RDS 自动备份（7 天）    |
| 安全  | HTTPS 全链路；JWT 认证；密钥不进代码 | IAM Least Privilege；SG 白名单         |
| 成本  | < $10/月                 | t3.micro；充分利用 AWS 免费套餐             |
