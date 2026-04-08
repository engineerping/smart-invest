# Smart Invest 项目构建总结

> 生成日期：2026-04-08

---

## 一、项目概览

Smart Invest 是一个移动端优先的智能投资平台，基于 **Java 21 + Spring Boot 3.3** 后端和 **React 18 + TypeScript + Vite** 前端构建。项目采用多模块 Maven 架构，通过 Flyway 管理数据库迁移，前端使用 Tailwind CSS 设计移动端 UI。

**技术栈：**
- 后端：Java 21, Spring Boot 3.3, JPA/Hibernate, PostgreSQL 16, Flyway, JWT (RS256)
- 前端：React 18, TypeScript, Vite, Tailwind CSS, React Router 6, TanStack Query
- 数据库：PostgreSQL 16 (Docker)
- 认证：JWT RS256 非对称签名

---

## 二、后端模块结构

项目包含 8 个 Maven 模块：

| 模块 | 说明 |
|------|------|
| `module-user` | 用户管理、认证、风险评估 |
| `module-fund` | 基金数据、NAV 历史、持仓信息 |
| `module-order` | 订单管理（T+2 结算） |
| `module-portfolio` | 用户持仓组合计算 |
| `module-plan` | 定期投资计划 |
| `module-scheduler` | 定时任务（月度定投执行） |
| `module-notification` | 通知服务 |
| `app` | Spring Boot 主应用，聚合所有模块 |

---

## 三、数据库架构（17 个 Flyway 迁移）

### 用户与认证
- `V1` — 用户表 (`users`)，支持手机号/邮箱注册，密码加盐哈希存储
- `V2` — 风险评估表 (`risk_assessments`)，存储用户的风险承受等级

### 基金核心
- `V3` — 基金主表 (`funds`)，含名称、代码、风险等级、管理费、起投金额等
- `V4` — 基金净值历史表 (`fund_nav_history`)，记录每日 NAV

### 基金分析数据
- `V5` — 资产配置表 (`fund_asset_allocations`)，按资产类别（股票/债券/现金等）分类
- `V6` — 基金持仓表 (`fund_top_holdings`)，每只基金前 10 大持仓及权重
- `V7` — 地理配置表 (`fund_geo_allocations`)，按地区（北美/欧洲/亚洲等）分类
- `V8` — 行业配置表 (`fund_sector_allocations`），按 GICS 行业分类

### 投资相关
- `V9` — 参考资产配置表 (`reference_asset_mix`），风险等级对应的参考配置
- `V10` — 订单表 (`orders`)，支持认购/赎回，T+2 结算日期自动计算
- `V11` — 投资计划表 (`investment_plans`)，月度定期投资计划
- `V12` — 持仓表 (`holdings`)，用户实时持仓汇总

### 种子数据
- `V13` — 11 只基金基础数据（SI-MM-01 货币基金、SI-BI-01/02 债券指数、SI-EI-01/02/03 股票指数、SI-MA-01~05 多资产组合）
- `V14` — 演示用户（demo@smartinvest.com / Demo1234!）及初始持仓
- `V15` — 回填所有基金的当前 NAV（从最新净值历史）
- `V16` — 补充 2025-01-02 至 2026-04-07 完整 NAV 历史（约 329 个交易日 × 11 只基金 ≈ 3619 条记录）
- `V17` — 基金资产/行业/地理配置及前 10 大持仓数据

---

## 四、API 端点

### 认证模块 (`/api/auth`)
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/login` | 登录，返回 JWT |
| POST | `/api/auth/register` | 注册用户 |

### 用户模块 (`/api/users`)
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/users/me` | 获取当前用户信息 |
| GET | `/api/users/risk-level` | 获取用户风险等级 |

### 基金模块 (`/api/funds`)
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/funds` | 基金列表（含当前 NAV） |
| GET | `/api/funds/{id}` | 基金详情 |
| GET | `/api/funds/{id}/nav-history` | NAV 历史（用于图表） |
| GET | `/api/funds/{id}/top-holdings` | 前 10 大持仓 |
| GET | `/api/funds/{id}/sector-allocation` | 行业配置 |
| GET | `/api/funds/{id}/geo-allocation` | 地理配置 |
| GET | `/api/funds/{id}/asset-allocation` | 资产配置 |

### 订单模块 (`/api/orders`)
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/orders` | 创建订单（认购/赎回） |
| GET | `/api/orders/my` | 我的交易记录 |

### 持仓模块 (`/api/portfolio`)
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/portfolio/me` | 我的所有持仓 |
| GET | `/api/portfolio/me/summary` | 持仓汇总（市值总计） |

### 投资计划模块 (`/api/plans`)
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/plans` | 我的投资计划 |
| POST | `/api/plans` | 创建月度定投计划 |
| DELETE | `/{id}` | 终止投资计划 |

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
| 代码 | 名称 | 类型 | 风险等级 |
|------|------|------|---------|
| SI-MM-01 | Smart Invest Global Money Funds - HK Dollar | 货币基金 | 1 |
| SI-BI-01 | Smart Invest Global Aggregate Bond Index Fund | 债券指数 | 2 |
| SI-BI-02 | Smart Invest Global Corporate Bond Index Fund | 企业债指数 | 3 |
| SI-EI-01 | Smart Invest US Equity Index Fund | 股票指数（美国） | 4 |
| SI-EI-02 | Smart Invest Global Equity Index Fund | 股票指数（全球） | 4 |
| SI-EI-03 | Smart Invest Hang Seng Index Fund | 股票指数（恒生） | 4 |
| SI-MA-01 | Smart Invest Portfolios - World Selection 1 (Conservative) | 多资产 | 1 |
| SI-MA-02 | Smart Invest Portfolios - World Selection 2 (Moderately Conservative) | 多资产 | 2 |
| SI-MA-03 | Smart Invest Portfolios - World Selection 3 (Balanced) | 多资产 | 3 |
| SI-MA-04 | Smart Invest Portfolios - World Selection 4 (Adventurous) | 多资产 | 4 |
| SI-MA-05 | Smart Invest Portfolios - World Selection 5 (Speculative) | 多资产 | 5 |

### 演示用户持仓
- Smart Invest Global Money Funds: 5,000 单位，市值 HKD 50,113.50
- Smart Invest Global Aggregate Bond Index Fund: 3,000 单位，市值 HKD 42,407.70
- Smart Invest US Equity Index Fund: 150 单位，市值 HKD 4,002.05
- **总市值：HKD 96,523.25**

### 投资计划
- PLAN-20260115-001：每月 HKD 1,000 投入 SI-EI-01，已完成 3 期

---

## 七、本地启动方式

### 数据库（Docker）
```bash
docker-compose up -d
# PostgreSQL: localhost:5432, 用户 smartadmin / localdev_only
```

### 后端
```bash
cd backend
SPRING_PROFILES_ACTIVE=local JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl app
# 访问：http://localhost:8080
```

### 前端
```bash
cd frontend
npm run dev
# 访问：http://localhost:5173
# 演示账号：demo@smartinvest.com / Demo1234!
```
