# Smart Invest 项目构建总结

---

## 一、项目概览

Smart Invest 是一个投资平台，基于 **Java 21 + Spring Boot 3.3** 后端和 **React 18 + TypeScript + Vite** 前端构建。后端已从多模块 Maven 的单体架构升级为 micro-service 架构，通过 **Terraform (IaC) + Kubernetes (K3S) + Helm** 部署在 AWS 上。通过 Flyway 管理数据库迁移，前端使用 Tailwind CSS 设计移动端 UI，采用 JWT（RS256）实现身份认证。

**技术栈：**

- 后端：Java 21, Spring Boot 3.3 微服务, Spring Cloud Gateway, JPA/Hibernate, Flyway, JWT (RS256)
- 前端：React 18, TypeScript, Vite, Tailwind CSS, React Router 6, TanStack Query
- 数据库：PostgreSQL 16（K3S StatefulSet + PVC）
- 消息队列：RabbitMQ · 缓存：Redis
- 编排：Kubernetes (K3S) + Helm · IaC：Terraform
- 认证：JWT RS256 非对称签名

---

## 二、后端模块结构

项目包含 6 个 Maven 模块：

| 模块                     | 说明                         |
| ---------------------- | -------------------------- |
| `common`               | 共享库（JWT 工具、DTO、公共配置）      |
| `user-service`         | 用户管理、认证、风险评估；负责数据库迁移      |
| `fund-service`         | 基金数据、NAV 历史、资产配置、持仓       |
| `order-service`        | 订单管理（T+2 结算）              |
| `notification-worker`  | RabbitMQ 消费者，邮件通知            |
| `api-gateway`          | Spring Cloud Gateway，入口 :8080 |

---

## 三、数据库架构（21 个 Flyway 迁移，V1–V21）

所有迁移文件位于 `backend/user-service/src/main/resources/db/migration/`（user-service 负责数据库）。

### 表结构（V1–V13）

- `V1` — `users` 用户表
- `V2` — `risk_assessments` 风险评估表
- `V3` — `funds` 基金主表
- `V4` — `fund_nav_history` 基金净值历史表
- `V5` — `fund_asset_allocations` 资产配置表
- `V6` — `fund_top_holdings` 前 10 大持仓表
- `V7` — `fund_geo_allocations` 地理配置表
- `V8` — `fund_sector_allocations` 行业配置表
- `V9` — `reference_asset_mix` 参考资产配置表
- `V10` — `user_portfolios` 用户组合表
- `V11` — `orders` 订单表（认购/赎回，T+2 结算）
- `V12` — `investment_plans` 投资计划表
- `V13` — `holdings` 持仓表

### 种子数据（V14–V20）

- `V14` — 11 只基金基础数据（SI-MM-01 货币基金、SI-BI-01/02 债券指数、SI-EI-01/02/03 股票指数、SI-MA-01~05 多资产组合）
- `V15` — 演示用户（demo@smartinvest.com / Demo1234!）及初始演示数据
- `V16` — 种子 NAV 及演示数据
- `V17` — 2025-01-02 至 2026-04-07 完整 NAV 历史（约 329 个交易日 × 11 只基金 ≈ 3619 条记录）
- `V18` — 基金资产/行业/地理配置及前 10 大持仓数据
- `V19` — 演示订单
- `V20` — 演示投资计划

### 表结构（V21）

- `V21` — `notifications` 通知表

---

## 四、API 端点

> 所有请求都通过 `api-gateway`（:8080）进入，由网关将 `/api/*` 路由到对应服务。

### 认证模块 (`/api/auth`)

| 方法   | 路径                   | 说明        |
| ---- | -------------------- | --------- |
| POST | `/api/auth/login`    | 登录，返回 JWT |
| POST | `/api/auth/register` | 注册用户      |

### 用户模块 (`/api/users`)

| 方法  | 路径                      | 说明       |
| --- | ----------------------- | -------- |
| GET | `/api/users/me`         | 获取当前用户信息 |
| GET | `/api/users/risk-level` | 获取用户风险等级 |

### 基金模块 (`/api/funds`)

| 方法  | 路径                                  | 说明            |
| --- | ----------------------------------- | ------------- |
| GET | `/api/funds`                        | 基金列表（含当前 NAV） |
| GET | `/api/funds/{id}`                   | 基金详情          |
| GET | `/api/funds/{id}/nav-history`       | NAV 历史（用于图表）  |
| GET | `/api/funds/{id}/top-holdings`      | 前 10 大持仓      |
| GET | `/api/funds/{id}/sector-allocation` | 行业配置          |
| GET | `/api/funds/{id}/geo-allocation`    | 地理配置          |
| GET | `/api/funds/{id}/asset-allocation`  | 资产配置          |

### 订单模块 (`/api/orders`)

| 方法   | 路径               | 说明          |
| ---- | ---------------- | ----------- |
| POST | `/api/orders`    | 创建订单（认购/赎回） |
| GET  | `/api/orders/my` | 我的交易记录      |

### 持仓模块 (`/api/portfolio`)

| 方法  | 路径                          | 说明         |
| --- | --------------------------- | ---------- |
| GET | `/api/portfolio/me`         | 我的所有持仓     |
| GET | `/api/portfolio/me/summary` | 持仓汇总（市值总计） |

### 投资计划模块 (`/api/plans`)

| 方法     | 路径           | 说明       |
| ------ | ------------ | -------- |
| GET    | `/api/plans` | 我的投资计划   |
| POST   | `/api/plans` | 创建月度定投计划 |
| DELETE | `/{id}`      | 终止投资计划   |

---

## 五、前端页面结构

```
src/pages/
├── auth/
│   ├── LoginPage.tsx        # 登录页
│   └── RegisterPage.tsx     # 注册页
├── funds/
│   ├── FundListPage.tsx     # 基金列表（含 NAV）
│   ├── FundDetailPage.tsx   # 基金详情（概览/持仓/风险 Tab）
│   └── MultiAssetFundListPage.tsx  # 多资产组合列表
├── holdings/
│   └── MyHoldingsPage.tsx   # 我的持仓
├── home/
│   └── SmartInvestHomePage.tsx  # 首页
├── order/
│   └── OrderPage.tsx        # 下单页
├── plans/
│   └── InvestmentPlansPage.tsx  # 我的投资计划
└── portfolio/
    └── BuildPortfolioPage.tsx   # 自建组合（限风险等级 4-5）
```

**路由配置：**

- `/` → 首页（需登录）
- `/login` → 登录页
- `/register` → 注册页
- `/funds` → 基金列表
- `/funds/:id` → 基金详情
- `/multi-asset` → 多资产组合
- `/holdings` → 我的持仓
- `/plans` → 我的投资计划
- `/build-portfolio` → 自建组合
- `/order` → 下单

---

## 六、种子数据摘要

### 11 只基金

| 代码       | 名称                                                                    | 类型       | 风险等级 |
| -------- | --------------------------------------------------------------------- | -------- | ---- |
| SI-MM-01 | Smart Invest Global Money Funds - HK Dollar                           | 货币基金     | 1    |
| SI-BI-01 | Smart Invest Global Aggregate Bond Index Fund                         | 债券指数     | 2    |
| SI-BI-02 | Smart Invest Global Corporate Bond Index Fund                         | 企业债指数    | 3    |
| SI-EI-01 | Smart Invest US Equity Index Fund                                     | 股票指数（美国） | 4    |
| SI-EI-02 | Smart Invest Global Equity Index Fund                                 | 股票指数（全球） | 4    |
| SI-EI-03 | Smart Invest Hang Seng Index Fund                                     | 股票指数（恒生） | 4    |
| SI-MA-01 | Smart Invest Portfolios - World Selection 1 (Conservative)            | 多资产      | 1    |
| SI-MA-02 | Smart Invest Portfolios - World Selection 2 (Moderately Conservative) | 多资产      | 2    |
| SI-MA-03 | Smart Invest Portfolios - World Selection 3 (Balanced)                | 多资产      | 3    |
| SI-MA-04 | Smart Invest Portfolios - World Selection 4 (Adventurous)             | 多资产      | 4    |
| SI-MA-05 | Smart Invest Portfolios - World Selection 5 (Speculative)             | 多资产      | 5    |

### 演示用户持仓

- Smart Invest Global Money Funds: 5,000 单位，市值 HKD 50,113.50
- Smart Invest Global Aggregate Bond Index Fund: 3,000 单位，市值 HKD 42,407.70
- Smart Invest US Equity Index Fund: 150 单位，市值 HKD 4,002.05
- **总市值：HKD 96,523.25**

### 投资计划

- PLAN-20260115-001：每月 HKD 1,000 投入 SI-EI-01，已完成 3 期

---

## 七、架构与部署

后端拆分为 6 个 Maven 模块（5 个服务 + `common`），每个服务有独立的 Dockerfile，以容器形式部署在 AWS EC2 `t3.medium`（ap-southeast-1，新加坡）上的单节点 **K3S** 集群中。

| 服务                   | 端口   | 职责                            |
| --------------------- | ---- | ----------------------------- |
| `api-gateway`         | 8080 | Spring Cloud Gateway，路由 `/api/*` |
| `user-service`        | 8081 | 认证 + 用户 + 风险评估；负责 Flyway 迁移  |
| `fund-service`        | 8082 | 基金目录 + NAV 历史                 |
| `order-service`       | 8083 | 订单 + T+2 结算                   |
| `notification-worker` | 8084 | RabbitMQ 消费者，邮件通知              |
| `frontend`            | 80   | React SPA（nginx）              |

有状态服务全部**在集群内运行**（不使用 RDS/MQ/ElastiCache）：`postgresql`（StatefulSet + PVC）、`rabbitmq`（Deployment + PVC）、`redis`（Deployment + PVC，默认禁用）。

部署完全通过 IaC + Helm 完成：
- **Terraform**（`infrastructure/terraform`）负责 VPC、EC2、S3、CloudFront + WAF。
- **Helm umbrella chart**（`infrastructure/helm/umbrella`）通过 `helm upgrade --install smart-invest . --namespace smart-invest` 一键部署所有服务。
- **CI/CD** — 单一 workflow `.github/workflows/cd-k3s.yml`（手动 `workflow_dispatch`）。
- 镜像构建为 `gongchengship/smart-invest-<service>:1.0.0`（Mac arm64 → Ubuntu x86_64 构建机 → `k3s ctr image import`）。

完整部署记录见 `infrastructure/deployment-guide.md`。
