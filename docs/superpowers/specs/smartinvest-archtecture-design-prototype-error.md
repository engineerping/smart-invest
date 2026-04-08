# Smart Invest — 原型阶段架构设计文档

**版本**: 1.0
**日期**: 2026-04-08
**阶段**: 产品原型（Proof of Concept）
**设计原则**: 快速验证业务假设，控制在 $200 AWS 积分预算内
**参考文档**: SmartInvest_ProjectRoadmap_v3.md · 2026-04-08-aws-deployment-plan-a.md

---

## 一、4C 架构模型（4C Models）

4C 架构模型从四个维度描述系统的完整设计：概念（Concept）、内容（Contents）、上下文（Context）和连接（Connections）。该模型由 IBM 的 Peter Eeles 提出，适用于软件架构的前期沟通与文档化。

### 1.1 Concept（概念）— 系统愿景与目标

**产品定位**

Smart Invest 是一款面向个人投资者的基金投资平台（Mobile Web），帮助用户完成基金浏览、组合构建、定期投资计划管理，以及持仓查询等全链路投资操作。

**核心价值主张**

- **低门槛入场**：最低 100 HKD 起投，覆盖货币市场、债券指数、股票指数和多资产组合
- **智能投顾辅助**：基于风险评估问卷（5 级）推荐资产配置方案
- **自动化管理**：支持月度定投计划自动执行，减少用户操作负担
- **透明化展示**：实时展示持仓市值、未实现损益、订单状态

**目标用户画像**

- 25–45 岁的香港地区在职人士
- 有闲置资金管理需求，但对金融产品了解有限
- 使用移动端浏览器访问，偏好简洁 UI

**成功标准（原型阶段）**

- 用户完成注册 → 风险评估 → 模拟下单的完整流程
- 前端在移动端浏览器正常展示，API 响应时间 < 500ms
- 系统在 $200 积分内稳定运行 6 个月以上

### 1.2 Contents（内容）— 系统构成要素

**业务实体（Domain Entities）**

| 实体             | 关键属性                                                            | 说明      |
| -------------- | --------------------------------------------------------------- | ------- |
| User           | email, password, full_name, risk_level (1-5), status            | 用户及风险等级 |
| Fund           | code, name, type, NAV, risk_level, annual_fee, asset_allocation | 基金基本信息  |
| FundNavHistory | fund_id, nav, nav_date                                          | 历史净值    |
| Holding        | user_id, fund_id, total_units, avg_cost_nav, total_invested     | 用户持仓    |
| Order          | type, amount, reference_number, status, settlement_date         | 订单      |
| InvestmentPlan | monthly_amount, next_contribution_date, completed_orders        | 定投计划    |
| RiskAssessment | user_id, answers (JSONB), total_score, risk_level               | 风险评估结果  |

**三大投资路径（业务场景）**

- **Pathway A**：单基金投资（货币市场 / 债券指数 / 股票指数）
- **Pathway B**：多资产组合投资（5 个风险级别对应 5 个推荐组合）
- **Pathway C**：自定义组合构建（仅对风险级别 4-5 开放，分配比例总和 = 100%）

**技术组件**

| 组件    | 技术选型                                       | 职责               |
| ----- | ------------------------------------------ | ---------------- |
| 前端    | React 18 + TypeScript + Vite + TailwindCSS | 用户界面，Mobile Web  |
| 后端    | Spring Boot 3.3 (Java 21) + Maven 多模块      | 业务逻辑，REST API    |
| 数据库   | PostgreSQL 16 + Flyway                     | 持久化存储，版本化迁移      |
| 前端部署  | Amazon S3 + CloudFront                     | 静态 SPA 托管，CDN 分发 |
| 后端部署  | Amazon EC2 t3.micro                        | 应用运行时            |
| 密钥管理  | AWS Secrets Manager                        | DB 密码、JWT 密钥安全存储 |
| 邮件服务  | Amazon SES                                 | 订单确认、计划到期通知      |
| 监控    | Amazon CloudWatch                          | 日志、指标、告警         |
| CI/CD | GitHub Actions                             | 自动构建、推送镜像、部署     |

### 1.3 Context（上下文）— 系统边界与外部交互

**用户交互上下文**

```
用户（Mobile Web 浏览器，Chrome/Safari）
    │
    │ HTTPS（公网）
    ▼
CloudFront CDN（含 WAF 基础防护）
    │
    ├── GET /（静态资源）──→ S3（React SPA）
    │                        缓存策略: Cache-Control max-age=1 year
    │
    └── POST /api/*（API 请求）──→ EC2:443（Nginx 反向代理）
                                       │
                                       ├── /api/auth/*  ──→ UserModule（认证）
                                       ├── /api/users/* ──→ UserModule（用户管理）
                                       ├── /api/funds/* ──→ FundModule（基金浏览）
                                       ├── /api/orders/* ──→ OrderModule（订单）
                                       ├── /api/portfolio/* → PortfolioModule（持仓）
                                       ├── /api/plans/* ──→ PlanModule（定投计划）
                                       │
                                       ▼
                               PostgreSQL（RDS，私有子网）
```

**外部依赖系统**

| 外部系统                | 交互方式               | 数据流向                                 |
| ------------------- | ------------------ | ------------------------------------ |
| AWS SES             | SMTP/HTTP API      | 应用 → SES：发送订单确认邮件、计划执行通知             |
| AWS Secrets Manager | SDK GetSecretValue | EC2 IAM Role → 运行时拉取 DB 密码、JWT 密钥    |
| CloudWatch          | SDK PutMetricData  | 应用 → CloudWatch：结构化 JSON 日志（Logback） |
| Fund NAV 数据源        | 内部模拟 + Flyway 种子数据 | 初始化时写入 fund_nav_history 表            |

**不在原型范围内的系统**

- 真实基金净值数据提供商（如 Bloomberg、Refinitiv）
- 真实交易清算通道（与基金公司对接）
- 支付网关（信用卡/银行转账）
- 监管报告系统

### 1.4 Connections（连接）— 模块边界与通信协议

**模块间通信（模块化单体内部）**

各 Spring 模块通过 Java 接口（Domain Service）进行内部调用，**不通过网络**，完全在同一个 JVM 进程内完成。这是模块化单体（Modular Monolith）的核心特征。

```
SmartInvestApplication（主模块）
    │
    ├── user-module
    │       UserService · UserRepository · AuthService
    │       API: /api/auth/**, /api/users/**
    │
    ├── fund-module
    │       FundService · FundRepository
    │       API: /api/funds/**
    │
    ├── order-module
    │       OrderService · OrderRepository
    │       API: /api/orders/**
    │       Events: OrderPlacedEvent → NotificationModule
    │
    ├── portfolio-module
    │       PortfolioService · HoldingRepository
    │       API: /api/portfolio/**
    │
    ├── plan-module
    │       PlanService · PlanRepository
    │       API: /api/plans/**
    │       Scheduler: MonthlyPlanScheduler（@Scheduled）
    │
    └── notification-module
            EmailService（AWS SES）
            Listens: OrderPlacedEvent, PlanExecutedEvent
```

**外部 API 协议**

| 交互对象                 | 协议               | 认证方式                   |
| -------------------- | ---------------- | ---------------------- |
| 前端 → 后端              | HTTPS REST（JSON） | JWT Bearer Token       |
| 后端 → AWS SES         | AWS SDK v2       | EC2 IAM Role（自动获取临时凭证） |
| 后端 → Secrets Manager | AWS SDK v2       | EC2 IAM Role           |
| 后端 → CloudWatch      | AWS SDK v2       | EC2 IAM Role           |

**数据库 Schema 概览**

```
Schema: smartinvest（单一数据库）

  users ──────────────────────┐
  risk_assessments ──→ users  │
  funds ───────────────────────┼── fund_nav_history
  fund_asset_allocations ──→ funds
  fund_top_holdings ─────→ funds
  fund_sector_allocations → funds
  fund_geo_allocations ───→ funds
  reference_asset_mix
  orders ────────────────────→ users, funds
  investment_plans ────────→ users
  holdings ────────────────→ users, funds, orders
```

---

## 二、架构五视图（5-View Architecture）

架构五视图由 Kruchten（1995）提出，从不同干系人的视角描述系统。五个视图分别为：逻辑视图、开发视图、进程视图、物理视图和场景视图。

### 2.1 逻辑视图（Logical View）— 功能分解

**包结构（Package Structure）**

```
com.smartinvest
├── SmartInvestApplication.java              ← Spring Boot 主入口
│
├── user                     ← 用户模块
│   ├── domain/
│   │   ├── entity/           User, RiskAssessment
│   │   ├── repository/       UserRepository, RiskAssessmentRepository
│   │   └── service/         UserService, AuthService, RiskAssessmentService
│   ├── api/
│   │   ├── controller/       AuthController, UserController
│   │   └── dto/             LoginRequest, RegisterRequest, UserResponse
│   └── config/              SecurityConfig (JWT filter chain)
│
├── fund                     ← 基金模块
│   ├── domain/
│   │   ├── entity/           Fund, FundNavHistory, FundAssetAllocation, ...
│   │   └── repository/       FundRepository, FundNavHistoryRepository
│   ├── service/              FundService, NavHistoryService
│   └── api/
│       ├── controller/       FundController
│       └── dto/              FundDetailResponse, NavHistoryResponse
│
├── order                    ← 订单模块
│   ├── domain/
│   │   ├── entity/           Order, OrderType, OrderStatus
│   │   └── repository/       OrderRepository
│   ├── service/              OrderService (下单逻辑、验证规则)
│   └── api/
│       ├── controller/       OrderController
│       └── dto/              PlaceOrderRequest, OrderResponse
│
├── portfolio                ← 持仓模块
│   ├── domain/
│   │   ├── entity/           Holding
│   │   └── repository/       HoldingRepository
│   ├── service/              PortfolioService, PnLCalculator
│   └── api/
│       ├── controller/       PortfolioController
│       └── dto/              HoldingResponse, PortfolioSummaryResponse
│
├── plan                     ← 定投计划模块
│   ├── domain/
│   │   ├── entity/           InvestmentPlan, PlanStatus
│   │   └── repository/       InvestmentPlanRepository
│   ├── service/              PlanService
│   └── api/
│       ├── controller/       PlanController
│       └── dto/              CreatePlanRequest, PlanResponse
│
├── scheduler                ← 调度模块
│   └── MonthlyPlanScheduler  @Scheduled(cron) → 扫描到期计划 → 创建 Order
│
├── notification             ← 通知模块
│   └── EmailService          AWS SES 发送邮件（事件驱动）
│
└── shared                   ← 共享基础设施
    ├── config/              JwtConfig, AwsConfig, FlywayConfig
    ├── security/            JwtTokenProvider, JwtAuthenticationFilter
    └── exception/           GlobalExceptionHandler
```

**核心 API 端点**

| 端点                          | 方法   | 模块        | 说明             |
| --------------------------- | ---- | --------- | -------------- |
| `/api/auth/register`        | POST | user      | 用户注册           |
| `/api/auth/login`           | POST | user      | 登录，返回 JWT      |
| `/api/users/me`             | GET  | user      | 获取当前用户信息       |
| `/api/risk/assess`          | POST | user      | 提交风险评估问卷       |
| `/api/funds`                | GET  | fund      | 基金列表（支持筛选/排序）  |
| `/api/funds/{code}`         | GET  | fund      | 基金详情（含 NAV 历史） |
| `/api/portfolio/holdings`   | GET  | portfolio | 用户持仓列表         |
| `/api/portfolio/summary`    | GET  | portfolio | 持仓汇总（市值、盈亏）    |
| `/api/orders`               | POST | order     | 提交订单           |
| `/api/orders/{ref}`         | GET  | order     | 查询订单详情         |
| `/api/orders/{ref}/cancel`  | POST | order     | 取消待处理订单        |
| `/api/plans`                | GET  | plan      | 查询定投计划列表       |
| `/api/plans`                | POST | plan      | 创建定投计划         |
| `/api/plans/{id}/terminate` | POST | plan      | 终止定投计划         |

### 2.2 开发视图（Development View）— 代码组织与依赖

**Maven 多模块结构**

```
smart-invest/（Parent POM, groupId=com.smartinvest, artifactId=smart-invest-parent）
│
├── pom.xml（父 POM，管理公共依赖和插件）
│
├── module-user/          ← Java 21, Spring Boot Starter Web/Security/Validation
├── module-fund/          ← 依赖: module-user
├── module-order/          ← 依赖: module-user, module-fund, module-portfolio
├── module-portfolio/      ← 依赖: module-user, module-fund
├── module-plan/           ← 依赖: module-user, module-fund, module-order
├── module-scheduler/      ← 依赖: module-plan, module-order
├── module-notification/   ← 依赖: module-order（事件监听）
│
└── app/                   ← 可执行模块（Spring Boot JAR）
    ├── pom.xml（继承父 POM，引入所有业务模块）
    ├── src/main/java/     SmartInvestApplication.java + 配置类
    └── src/main/resources/
            ├── application.yml          ← 公共配置
            ├── application-local.yml    ← 本地开发（Spring Profile: local）
            ├── application-prod.yml     ← 生产环境（从环境变量读取密钥）
            └── db/migration/            Flyway SQL 迁移文件
```

**前端目录结构**

```
frontend/
├── src/
│   ├── api/               ← Axios 实例（含 JWT 拦截器）
│   ├── pages/             ← 页面组件（按功能模块划分）
│   │   ├── Auth/         LoginPage, RegisterPage
│   │   ├── Fund/          FundListPage, FundDetailPage
│   │   ├── Portfolio/     MyHoldingsPage, PortfolioBuildPage
│   │   ├── Order/         OrderConfirmPage, MyTransactionsPage
│   │   └── Plan/          MyPlansPage, PlanCreatePage
│   ├── components/       ← 可复用 UI 组件
│   ├── hooks/            ← React Query hooks（数据获取）
│   ├── stores/           ← Zustand 全局状态
│   └── App.tsx           ← 路由配置
├── Dockerfile.dev        ← 本地 Docker 开发
└── Dockerfile           ← 生产构建
```

**依赖版本管理**

| 依赖                | 版本                        | 用途                  |
| ----------------- | ------------------------- | ------------------- |
| Java              | 21（Eclipse Temurin）       | 运行时                 |
| Spring Boot       | 3.3.2                     | 框架                  |
| PostgreSQL Driver | 42.7.x                    | JDBC                |
| Flyway            | 10.x（Spring Boot managed） | 数据库迁移               |
| JJWT              | 0.12.6                    | JWT 生成与验证           |
| AWS SDK v2        | 2.26.0（BOM）               | SES、Secrets Manager |
| React             | 19.x                      | 前端 UI               |
| Vite              | 8.x                       | 前端构建工具              |
| TanStack Query    | 5.x                       | 前端数据获取与缓存           |

### 2.3 进程视图（Process View）— 运行时行为与并发

**Spring Boot 启动与请求处理流程**

```
HTTP Request（CloudFront → Nginx → Spring Boot）
    │
    ▼
JwtAuthenticationFilter（从 Authorization Header 解析 JWT）
    │  有效 Token → 设置 SecurityContext → 放行
    │  无 Token / Token 过期 → 401 Unauthorized（登录接口除外）
    ▼
Spring MVC Handler Mapping（按 @RequestMapping 路由）
    │
    ├── AuthController    ──→ AuthService ──→ UserRepository
    ├── FundController   ──→ FundService ──→ FundRepository
    ├── OrderController  ──→ OrderService ──→ OrderRepository
    │                              │
    │                              ▼ 发布 OrderPlacedEvent（Spring ApplicationEvent）
    │                                    │
    │                                    ▼
    │                              EmailService（异步通知用户）
    │
    ├── PortfolioController ──→ PortfolioService
    │                              │
    │                              ▼ 计算 Holding.market_value = units × NAV
    │                                    （实时查询 fund_nav_history 最新净值）
    │
    └── PlanController    ──→ PlanService ──→ InvestmentPlanRepository

Response（JSON，HttpStatus 200/201/400/401/403/500）
    │
    ▼
JwtAuthenticationFilter（响应头注入新的 Access Token）
```

**定时任务（MonthlyPlanScheduler）**

```
触发频率: 每分钟执行一次（@Scheduled(fixedRate = 60000)）

1. 查询所有 status=ACTIVE 且 next_contribution_date ≤ 当天 的 InvestmentPlan
2. 对每个计划:
   a. 创建 Order（type=MONTHLY_PLAN, amount=monthly_amount）
   b. 更新 Holding（增加 units）
   c. 计算下一个扣款日（若当天为周末/节假日 → 顺延至下一工作日）
   d. 发送邮件通知（AWS SES）
3. 记录调度日志（CloudWatch）
```

**数据库连接池（HikariCP）**

```
最大连接数: 10（application.yml hikari.maximum-pool-size）
最小空闲: 2
连接超时: 30 秒
在途连接上限: maximum-pool-size × 2 = 20

连接复用策略:
  - 每个 HTTP 请求从池中借出连接
  - 请求结束立即归还（try-with-resources 或 finally）
  - 避免长时间持有连接（Long-running query 需要单独优化）
```

### 2.4 物理视图（Physical View）— 基础设施拓扑

**原型阶段部署拓扑（单 EC2）**

```
                          ┌──────────────────────────────────────────┐
                          │            AWS Region: us-east-1          │
                          │                                          │
                          │  ┌────────────────────────────────────┐  │
                          │  │ VPC（默认 VPC，Subnet 自动分配）      │  │
                          │  │                                     │  │
                          │  │  EC2 t3.micro（Public Subnet）       │  │
                          │  │  ┌─────────────────────────────┐   │  │
                          │  │  │ Nginx（反向代理，SSL 终止）   │   │  │
                          │  │  │  端口: 443（HTTPS）          │   │  │
                          │  │  │  端口: 80（HTTP 重定向）      │   │  │
                          │  │  └──────────┬──────────────────┘   │  │
                          │  │             │ 127.0.0.1:8080       │  │
                          │  │  ┌──────────▼──────────────────┐   │  │
                          │  │  │ Spring Boot JAR             │   │  │
                          │  │  │  port: 8080                 │   │  │
                          │  │  │  JVM: -Xmx512m -Xms256m     │   │  │
                          │  │  └──────────┬──────────────────┘   │  │
                          │  │             │                     │  │
                          │  │  ┌──────────▼──────────────────┐   │  │
                          │  │  │ PostgreSQL 16（Docker）     │   │  │
                          │  │  │  port: 5432                 │   │  │
                          │  │  └─────────────────────────────┘   │  │
                          │  └────────────────────────────────────┘  │
                          │                                          │
                          │  RDS PostgreSQL（Private Subnet）        │
                          │  ┌────────────────────────────────────┐  │
                          │  │ db.t3.micro                        │  │
                          │  │ 引擎: PostgreSQL 16                 │  │
                          │  │ 存储: 20GB gp3，KMS 静态加密        │  │
                          │  │ 备份: 每日快照，保留 7 天           │  │
                          │  │ 连接: 仅接受 EC2 SG（端口 5432）    │  │
                          │  └────────────────────────────────────┘  │
                          │                                          │
                          │  S3 Bucket（Static Website Hosting）      │
                          │  CloudFront Distribution                │
                          │  ACM Certificate Manager                 │
                          │  Secrets Manager                        │
                          │  SES（邮件发送）                         │
                          │  CloudWatch Logs + Alarms               │
                          └──────────────────────────────────────────┘

Internet ── HTTPS ──→ CloudFront（统一入口，HTTPS 终止）
                          │
                          ├── /*    → S3（React SPA，无服务器）
                          └── /api/* → EC2 公网 IP:443 → Nginx → :8080
```

**资源规格**

| 组件         | 规格                                      | 说明                               |
| ---------- | --------------------------------------- | -------------------------------- |
| EC2        | t3.micro（2 vCPU, 1 GB RAM）              | Spring Boot + PostgreSQL + Nginx |
| RDS        | db.t3.micro（2 vCPU, 1 GB RAM），20 GB gp3 | PostgreSQL 16，单 AZ               |
| S3         | 约 100 MB 静态文件                           | React SPA 构建产物                   |
| CloudFront | 1 distribution                          | 前端 CDN + HTTPS                   |

### 2.5 场景视图（Scenario View）— 关键用例时序

**场景 1：用户完成 Pathway A 单基金下单**

```
Actor: 用户（Mobile Web）
System: Smart Invest Platform

1. [前端] 用户登录 → AuthController.login() → 返回 JWT
2. [前端] 用户浏览基金列表 → FundController.getFunds()
3. [前端] 用户点击基金详情 → FundController.getFundDetail(code)
4. [前端] 用户点击"立即投资" → 填写金额 500 HKD
5. [前端] POST /api/orders
        OrderController.placeOrder(PlaceOrderRequest)
          → OrderService.placeOrder()
              → 验证: fund.exists && user.hasRiskLevel
              → 验证: amount >= fund.min_investment (100 HKD)
              → OrderRepository.save(order)
              → 发布 OrderPlacedEvent
                  → EmailService.sendOrderConfirmation()（异步）
          → 返回 OrderResponse(ref: P-123456)
6. [前端] 展示下单成功页面，显示订单参考号
```

**场景 2：月度定投计划自动执行**

```
Actor: 系统（Scheduler）
Trigger: MonthlyPlanScheduler 每分钟执行

1. Scheduler 查询: InvestmentPlanRepository.findDuePlans(today)
2. 对每个 Plan:
   a. OrderService.placeOrder(monthly_amount, plan.user, plan.fund)
   b. HoldingService.upsertHolding(user_id, fund_id, new_units)
   c. PlanService.advanceNextContributionDate(plan)  // 顺延节假日
   d. EmailService.sendPlanExecutedNotification(plan)
3. 记录执行日志（CloudWatch）
```

**场景 3：持仓市值计算**

```
Actor: 用户（Mobile Web）
Trigger: 用户打开"我的持仓"页面

1. GET /api/portfolio/holdings
2. PortfolioController.getHoldings(user_id)
3. PortfolioService.getHoldingsWithPnL(user_id)
     → HoldingRepository.findByUserId(user_id)
     → 对每个 Holding:
         latest_nav = FundNavHistoryRepository
           .findTopByFundIdOrderByNavDateDesc(fund_id).nav
         market_value = units × latest_nav
         unrealised_pnl = (latest_nav - avg_cost_nav) × units
4. 返回 HoldingResponse 列表
5. GET /api/portfolio/summary → 汇总市值、汇总盈亏
```

---

## 三、关键设计决策

| 决策    | 选择                      | 权衡理由                                       |
| ----- | ----------------------- | ------------------------------------------ |
| 架构风格  | 模块化单体（Modular Monolith） | $200 预算限制单 EC2 成本；无网络开销，性能最优；模块边界清晰，未来可拆分  |
| 数据库   | RDS PostgreSQL 单 AZ     | 原型阶段单 AZ 足够；自动备份保障数据安全；后期可升级 Multi-AZ      |
| 前端部署  | S3 + CloudFront         | 静态 SPA 无需服务器；CloudFront 提供免费 HTTPS 和全球 CDN |
| 密钥管理  | Secrets Manager         | 满足不在代码中硬编码密钥的基本安全要求                        |
| CI/CD | GitHub Actions          | 零基础设施成本；与 GitHub 原生集成；$200 预算内免费           |
| 定时任务  | Spring @Scheduled       | 原型阶段无需独立调度服务；一个 EC2 足够                     |

---

## 四、非功能性需求（原型阶段）

| 维度   | 目标                      | 说明                                     |
| ---- | ----------------------- | -------------------------------------- |
| 性能   | API P99 < 500ms         | 单 EC2 + PostgreSQL 连接池（max=10）满足原型规模   |
| 可用性  | 99%（月停机 < 7 小时）         | EC2 Auto Recovery（CloudWatch）；RDS 自动备份 |
| 安全   | HTTPS 全链路；JWT 认证；密钥不进代码 | IAM Least Privilege；Security Group 白名单 |
| 可扩展性 | 水平扩展无感知（模块化单体）          | Stateless API；会话存储在 JWT 中              |
| 成本   | < $34/月                 | t3.micro + db.t3.micro；充分利用免费套餐        |
