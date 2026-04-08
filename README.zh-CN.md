<div align="center">

# Smart Invest

[![Java](https://img.shields.io/badge/Java-21-ED8B00?logo=openjdk&logoColor=white)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.3-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![React](https://img.shields.io/badge/React-18-20232A?logo=react&logoColor=61DAFB)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![AWS](https://img.shields.io/badge/AWS-EC2_·_RDS_·_S3-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.9+-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)

**[English](./README.md) · [简体中文](./README.zh-CN.md)**

</div>

---

## 项目简介

Smart Invest 是一款**小成本投资平台**，通过这软件，银行将诸多用户的小额资金汇集到一起，用这些资金购买只有大量资金人才有资格购买的高质量基金，然后将利润分配给用户。——本软件以真实银行投资 App 为原型设计。

**核心功能：**

- 浏览并投资货币市场基金、债券指数基金、股票指数基金及多元资产组合
- 基于风险评估构建个性化投资组合
- 设置月度定期定额（DCA）投资计划，自动执行
- 实时查看持仓及未实现盈亏

---

**架构方案：** 在 AWS 上部署的模块化单体架构，遵循 [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) 五大支柱——针对 `$200` 积分预算进行成本优化（月均约 $34，可持续运行约 5–6 个月）。

---

## 目录

1. [产品分析与功能范围](#1-产品分析与功能范围)
2. [系统架构设计](#2-系统架构设计)
3. [AWS 基础设施设计](#3-aws-基础设施设计)
4. [开发环境搭建](#4-开发环境搭建)
5. [数据库设计](#5-数据库设计)
6. [后端服务开发](#6-后端服务开发)
7. [前端开发（移动端 Web）](#7-前端开发移动端-web)
8. [基础设施即代码（Terraform）](#8-基础设施即代码terraform)
9. [CI/CD 流水线](#9-cicd-流水线)
10. [部署指南](#10-部署指南)
11. [项目时间表](#11-项目时间表)
12. [代码仓库结构](#12-代码仓库结构)

---

## 1. 产品分析与功能范围

详细内容请参阅：[产品分析与功能范围.md](./doc-manually/I.产品分析与功能范围.md)

## 2. 系统架构设计

### 2.1 架构概览

本系统遵循 **AWS Well-Architected Framework** 五大支柱：卓越运营、安全性、可靠性、性能效率和成本优化。

在 $200 AWS 积分预算约束下，部署方案采用 **EC2 承载 Spring Boot 应用**，代替容器编排方案，在降低运维复杂度的同时保持生产级设计水准。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         终端用户（移动端 Web 浏览器）                     │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │ HTTPS
┌──────────────────────────────────▼──────────────────────────────────────┐
│               Amazon CloudFront（CDN + HTTPS 终止）                      │
│               AWS Certificate Manager（SSL/TLS 证书 — 免费）             │
└──────────┬───────────────────────────────────────┬──────────────────────┘
           │                                       │
┌──────────▼──────────┐               ┌────────────▼────────────────────┐
│  Amazon S3          │               │  EC2 实例（t3.small）            │
│  React SPA          │               │  Nginx（反向代理）               │
│  （静态文件托管）    │               │  ┌────────────────────────────┐ │
│                     │               │  │  Spring Boot 应用           │ │
│                     │               │  │  （模块化单体架构）          │ │
│                     │               │  │                            │ │
│                     │               │  │  模块列表：                 │ │
│                     │               │  │  • UserModule      :8080   │ │
│                     │               │  │  • FundModule              │ │
│                     │               │  │  • OrderModule             │ │
│                     │               │  │  • PortfolioModule         │ │
│                     │               │  │  • PlanModule              │ │
│                     │               │  │  • SchedulerModule         │ │
│                     │               │  └────────────────────────────┘ │
└─────────────────────┘               └──────────┬──────────────────────┘
                                                  │
           ┌──────────────────────────────────────┼──────────────┐
           │                                      │              │
┌──────────▼──────────┐              ┌────────────▼──────┐  ┌───▼──────────────┐
│  Amazon RDS          │              │  Amazon           │  │  Amazon SES      │
│  PostgreSQL 16       │              │  CloudWatch       │  │  （邮件通知）    │
│  db.t3.micro         │              │  （监控 + 告警）  │  │                  │
└──────────────────────┘              └───────────────────┘  └──────────────────┘
```

### 2.2 架构决策：模块化单体 vs. 微服务

**决策：EC2 上部署模块化单体（Modular Monolith）**

| 考量因素   | 决策依据                                     |
| ------ | ---------------------------------------- |
| 预算约束   | 单台 EC2 t3.small 实例可在 $200 积分范围内运行全部模块    |
| 运维简洁性  | 无服务间网络调用、无服务发现、无分布式追踪开销                  |
| 模块化设计  | 每个业务领域独立成 Spring 模块，包边界清晰；未来迁移至微服务架构路径明确 |
| 生产实践对齐 | 模块化设计保留了架构意图，符合成本受限环境下的真实工程实践            |

### 2.3 各模块职责

| 模块（Spring 包）   | 职责                                    | API 前缀                                        |
| -------------- | ------------------------------------- | --------------------------------------------- |
| `user`         | 注册、登录、JWT 认证、风险问卷                     | `/api/auth/**`、`/api/users/**`、`/api/risk/**` |
| `fund`         | 基金目录、NAV 历史、资产配置、Top10 持仓             | `/api/funds/**`                               |
| `order`        | 单只基金下单、组合批量下单、取消订单                    | `/api/orders/**`                              |
| `portfolio`    | 持仓计算、未实现盈亏、总市值                        | `/api/portfolio/**`                           |
| `plan`         | 月定投计划管理、终止计划                          | `/api/plans/**`                               |
| `scheduler`    | 月定投自动执行（Spring `@Scheduled`）、NAV 模拟更新 | 内部任务                                          |
| `notification` | 通过 Amazon SES 发送邮件通知                  | 内部事件驱动                                        |

### 2.4 AWS Well-Architected 五大支柱对应实现

| 支柱       | 实现方式                                                                                          |
| -------- | --------------------------------------------------------------------------------------------- |
| **卓越运营** | CloudWatch Logs + 告警；结构化 JSON 日志（Logback）；`/actuator/health` 健康检查端点                           |
| **安全性**  | IAM 最小权限角色；Secrets Manager 管理数据库凭证；ACM 提供 HTTPS；JWT（RS256 算法）；Security Group 限制 RDS 仅对 EC2 开放 |
| **可靠性**  | RDS 自动备份（保留 7 天）；systemd 管理 EC2 应用进程自动重启；CloudWatch 告警触发 SNS 通知                               |
| **性能效率** | CloudFront CDN 加速静态资源；HikariCP 连接池；Spring Cache 缓存 NAV 数据                                     |
| **成本优化** | 单台 t3.small EC2；db.t3.micro RDS；S3 + CloudFront 承载前端（避免额外 EC2 开销）；CloudWatch 免费套餐监控           |

---

## 3. AWS 基础设施设计

### 3.1 服务用量与费用估算

| 服务                      | 规格说明                         | 月费用（估算）      |
| ----------------------- | ---------------------------- | ------------ |
| EC2 t3.small            | 1 台实例（2 vCPU、2 GB 内存）— 应用服务器 | ~$17（积分抵扣）   |
| RDS PostgreSQL 16       | db.t3.micro、20 GB gp2、单可用区   | ~$15（积分抵扣）   |
| Amazon S3               | 前端静态托管，约 100 MB              | ~$0.01（积分抵扣） |
| Amazon CloudFront       | S3 前端 CDN + HTTPS 终止         | ~$1（积分抵扣）    |
| AWS Certificate Manager | 自定义域名 SSL/TLS 证书             | 免费           |
| Amazon SES              | 邮件通知（约 500 封/月）              | 免费套餐         |
| Amazon CloudWatch       | 日志 + 10 个指标 + 10 个告警         | 免费套餐         |
| Amazon SNS              | 告警推送通知                       | 免费套餐         |
| Route 53                | 自定义域名 DNS 解析（可选）             | ~$0.50       |
| AWS IAM                 | 身份与访问管理                      | 免费           |
| **合计**                  |                              | **~$34/月**   |

> 持有 $200 积分的情况下，本架构可持续运行约 **5–6 个月**。

### 3.2 网络架构

```
互联网
    │
    ▼
CloudFront 分发
    ├── /static/*  → S3 存储桶（React SPA 静态文件）
    └── /api/*     → EC2 公网 IP（Nginx :443）
         │
         ▼
    EC2 安全组规则：
    入站：443（HTTPS，0.0.0.0/0）、22（SSH，仅限管理员 IP）
    出站：全部放行
         │
         ▼
    Spring Boot 应用（:8080，仅内部访问）
         │
         ▼
    RDS 安全组规则：
    入站：5432（PostgreSQL，仅限 EC2 安全组 ID）
```

### 3.3 安全架构

```
┌─────────────────────────────────────────────────────────┐
│  公有子网                                               │
│  ┌────────────────────────────────────────────────┐    │
│  │  EC2（t3.small）                               │    │
│  │  IAM 角色：smart-invest-app-role               │    │
│  │  权限策略：                                    │    │
│  │    - secretsmanager:GetSecretValue             │    │
│  │    - ses:SendEmail                             │    │
│  │    - cloudwatch:PutMetricData                  │    │
│  │    - logs:CreateLogGroup, PutLogEvents         │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  私有子网（RDS 处于隔离子网中）                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  RDS PostgreSQL                                │    │
│  │  数据库凭证：AWS Secrets Manager 管理          │    │
│  │  静态数据加密：AES-256（默认开启）             │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## 4. 开发环境搭建

### 4.1 必要工具安装

```bash
# ── Java 21（通过 SDKMAN 管理版本）──────────────────────────────────
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-open
sdk use java 21-open
java --version   # 应显示：openjdk 21.x

# ── Maven 3.9+ ────────────────────────────────────────────────────
sdk install maven 3.9.6
mvn --version

# ── Node.js 20 LTS（前端构建）────────────────────────────────────
# macOS：
brew install node@20

# Ubuntu/Debian：
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version && npm --version

# ── Docker Desktop ────────────────────────────────────────────────
# 下载地址：https://www.docker.com/products/docker-desktop/
docker --version

# ── AWS CLI v2 ────────────────────────────────────────────────────
# macOS：
brew install awscli

# Linux：
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

aws configure :Done

# 依次输入：
# AWS Access Key ID     → [IAM 用户的 Access Key]
# AWS Secret Access Key → [IAM 用户的 Secret Key]
# Default region name   → us-east-1（或 ap-east-1 香港区）
# Default output format → json

# ── Terraform 1.9+ ───────────────────────────────────────────────
# macOS：
brew tap hashicorp/tap && brew install hashicorp/tap/terraform

# Linux：
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform --version

# ── Session Manager 插件（免 SSH 直接访问 EC2）───────────────────
# macOS：
# 下载适合您架构的安装包
# Intel Mac
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/session-manager-plugin.pkg" -o "session-manager-plugin.pkg"

# Apple Silicon Mac (M1/M2)
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/session-manager-plugin.pkg" -o "session-manager-plugin.pkg"

# 安装
sudo installer -pkg session-manager-plugin.pkg -target /
sudo ln -s /usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/session-manager-plugin


# Linux：参考 https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
```

### 4.2 本地开发 Docker Compose 配置

> 文件：[docker-compose.yml](docker-compose.yml)

---

## 5. 数据库设计

### 5.1 Schema 概览

所有数据表均存储于单个 PostgreSQL 16 数据库（`smartinvest`）中。数据库 Schema 变更通过 **Flyway** 管理，按版本号递增迁移。

### 5.2 迁移文件清单

> 目录：[backend/app/src/main/resources/db/migration](backend/app/src/main/resources/db/migration)

```
backend/app/src/main/resources/db/migration/
├── [V1__create_users.sql](backend/app/src/main/resources/db/migration/V1__create_users.sql)
├── [V2__create_risk_assessments.sql](backend/app/src/main/resources/db/migration/V2__create_risk_assessments.sql)
├── [V3__create_funds.sql](backend/app/src/main/resources/db/migration/V3__create_funds.sql)
├── [V4__create_fund_nav_history.sql](backend/app/src/main/resources/db/migration/V4__create_fund_nav_history.sql)
├── [V5__create_fund_asset_allocations.sql](backend/app/src/main/resources/db/migration/V5__create_fund_asset_allocations.sql)
├── [V6__create_fund_top_holdings.sql](backend/app/src/main/resources/db/migration/V6__create_fund_top_holdings.sql)
├── [V7__create_fund_geo_allocations.sql](backend/app/src/main/resources/db/migration/V7__create_fund_geo_allocations.sql)
├── [V8__create_fund_sector_allocations.sql](backend/app/src/main/resources/db/migration/V8__create_fund_sector_allocations.sql)
├── [V9__create_reference_asset_mix.sql](backend/app/src/main/resources/db/migration/V9__create_reference_asset_mix.sql)
├── [V10__create_orders.sql](backend/app/src/main/resources/db/migration/V10__create_orders.sql)
├── [V11__create_investment_plans.sql](backend/app/src/main/resources/db/migration/V11__create_investment_plans.sql)
├── [V12__create_holdings.sql](backend/app/src/main/resources/db/migration/V12__create_holdings.sql)
├── [V13__seed_funds.sql](backend/app/src/main/resources/db/migration/V13__seed_funds.sql)
├── [V14__seed_demo_data.sql](backend/app/src/main/resources/db/migration/V14__seed_demo_data.sql)
├── [V15__seed_nav_and_demo.sql](backend/app/src/main/resources/db/migration/V15__seed_nav_and_demo.sql)
├── [V16__seed_nav_history.sql](backend/app/src/main/resources/db/migration/V16__seed_nav_history.sql)
└── [V17__seed_fund_allocations.sql](backend/app/src/main/resources/db/migration/V17__seed_fund_allocations.sql)
```

### 5.3 DDL — 核心表定义

```sql
-- V1__create_users.sql
CREATE TABLE users (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    email        VARCHAR(255) UNIQUE NOT NULL,
    password     VARCHAR(255) NOT NULL,          -- BCrypt 哈希值
    full_name    VARCHAR(255) NOT NULL,
    risk_level   SMALLINT,                        -- NULL = 尚未完成问卷；1–5
    status       VARCHAR(20)  DEFAULT 'ACTIVE',
    created_at   TIMESTAMPTZ  DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  DEFAULT NOW()
);

-- V2__create_risk_assessments.sql
CREATE TABLE risk_assessments (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answers      JSONB       NOT NULL,            -- 示例：{"q1": "B", "q2": "C", ...}
    total_score  INTEGER     NOT NULL,
    risk_level   SMALLINT    NOT NULL,
    assessed_at  TIMESTAMPTZ DEFAULT NOW()
);

-- V3__create_funds.sql
CREATE TABLE funds (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(30)  UNIQUE NOT NULL,   -- 示例："SI-EI-01"
    isin_class      VARCHAR(50),                    -- 示例："CLASS HC-HKD-ACC"
    name            VARCHAR(300) NOT NULL,
    fund_type       VARCHAR(30)  NOT NULL,
    -- 枚举值：MONEY_MARKET | BOND_INDEX | EQUITY_INDEX | MULTI_ASSET
    risk_level      SMALLINT     NOT NULL,           -- 0–5
    currency        VARCHAR(5)   DEFAULT 'HKD',
    current_nav     DECIMAL(15,4),
    nav_date        DATE,
    annual_mgmt_fee DECIMAL(6,4),                   -- 示例：0.0031 = 0.31%
    min_investment  DECIMAL(12,2) DEFAULT 100.00,
    benchmark_index VARCHAR(300),                   -- 追踪指数名称
    market_focus    VARCHAR(200),                   -- 市场覆盖范围描述
    description     TEXT,
    is_active       BOOLEAN      DEFAULT TRUE,
    created_at      TIMESTAMPTZ  DEFAULT NOW()
);

-- V4__create_fund_nav_history.sql
-- 用于绘制 3M/6M/1Y/3Y/5Y 净值走势图
CREATE TABLE fund_nav_history (
    id       BIGSERIAL    PRIMARY KEY,
    fund_id  UUID         NOT NULL REFERENCES funds(id),
    nav      DECIMAL(15,4) NOT NULL,
    nav_date DATE         NOT NULL,
    UNIQUE (fund_id, nav_date)
);
CREATE INDEX idx_nav_history_fund_date ON fund_nav_history (fund_id, nav_date DESC);

-- V5__create_fund_asset_allocations.sql
-- 资产配置饼图数据
CREATE TABLE fund_asset_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    asset_class VARCHAR(50)  NOT NULL,  -- Stocks | Bonds | Cash | Others | Real Estate
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);

-- V6__create_fund_top_holdings.sql
-- Top 10 持仓（Holdings Tab）
CREATE TABLE fund_top_holdings (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id      UUID         NOT NULL REFERENCES funds(id),
    holding_name VARCHAR(200) NOT NULL,  -- 示例："Apple Inc"
    weight       DECIMAL(6,2) NOT NULL,  -- 示例：7.03
    as_of_date   DATE         NOT NULL,
    sequence     SMALLINT     NOT NULL   -- 排名 1–10
);

-- V7__create_fund_geo_allocations.sql
-- 地理分布（Geographical Tab）
CREATE TABLE fund_geo_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    region      VARCHAR(100) NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);

-- V8__create_fund_sector_allocations.sql
-- 行业分布（Sectors Tab）
CREATE TABLE fund_sector_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    sector      VARCHAR(100) NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);

-- V9__create_reference_asset_mix.sql
-- 参考资产配置（自建组合 第 1/5 步展示）
CREATE TABLE reference_asset_mix (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    risk_level  SMALLINT     NOT NULL,    -- 仅 4 或 5（自建组合功能开放等级）
    asset_class VARCHAR(50)  NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL
);

-- V10__create_orders.sql
CREATE TABLE orders (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number    VARCHAR(30)  UNIQUE NOT NULL,
    user_id             UUID         NOT NULL REFERENCES users(id),
    fund_id             UUID         NOT NULL REFERENCES funds(id),
    order_type          VARCHAR(20)  NOT NULL,   -- ONE_TIME | MONTHLY_PLAN
    investment_type     VARCHAR(20)  NOT NULL,   -- BUY | SELL
    amount              DECIMAL(15,2),
    nav_at_order        DECIMAL(15,4),           -- 下单时 NAV
    executed_units      DECIMAL(18,6),           -- 成交单位数
    investment_account  VARCHAR(100),
    settlement_account  VARCHAR(100),
    status              VARCHAR(20)  DEFAULT 'PENDING',
    -- 状态枚举：PENDING | PROCESSING | COMPLETED | CANCELLED | FAILED
    order_date          DATE         NOT NULL DEFAULT CURRENT_DATE,
    settlement_date     DATE,                    -- T+2 工作日
    plan_id             UUID,                    -- 关联投资计划（可为空）
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    completed_at        TIMESTAMPTZ
);
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
CREATE INDEX idx_orders_user_date   ON orders (user_id, order_date DESC);

-- V11__create_investment_plans.sql
CREATE TABLE investment_plans (
    id                     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number       VARCHAR(30)  UNIQUE NOT NULL,
    user_id                UUID         NOT NULL REFERENCES users(id),
    fund_id                UUID         NOT NULL REFERENCES funds(id),
    monthly_amount         DECIMAL(15,2) NOT NULL,
    next_contribution_date DATE         NOT NULL,
    investment_account     VARCHAR(100),
    settlement_account     VARCHAR(100),
    status                 VARCHAR(20)  DEFAULT 'ACTIVE',   -- ACTIVE | TERMINATED
    completed_orders       INTEGER      DEFAULT 0,
    total_invested         DECIMAL(15,2) DEFAULT 0.00,
    plan_creation_date     DATE         NOT NULL DEFAULT CURRENT_DATE,
    terminated_at          TIMESTAMPTZ
);

-- V12__create_holdings.sql
CREATE TABLE holdings (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID          NOT NULL REFERENCES users(id),
    fund_id         UUID          NOT NULL REFERENCES funds(id),
    total_units     DECIMAL(18,6) DEFAULT 0,
    avg_cost_nav    DECIMAL(15,4),               -- 平均成本价
    total_invested  DECIMAL(15,2) DEFAULT 0.00,
    updated_at      TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE (user_id, fund_id)
);

-- V13__seed_funds.sql
-- 基于用户指南截图中出现的真实基金信息生成种子数据
INSERT INTO funds (code, isin_class, name, fund_type, risk_level, annual_mgmt_fee, benchmark_index, market_focus, min_investment) VALUES
-- 货币市场基金（风险等级 1）
('SI-MM-01', 'CLASS D-ACC',
 'Smart Invest Global Money Funds - Hong Kong Dollar',
 'MONEY_MARKET', 1, 0.0031, NULL, '香港货币市场工具', 100.00),

-- 债券指数基金（风险等级 1–2）
('SI-BI-01', 'CLASS HC-HKD-ACC',
 'Smart Invest Global Aggregate Bond Index Fund',
 'BOND_INDEX', 1, 0.0025, 'Bloomberg Global Aggregate Bond Index', '全球投资级债券', 100.00),
('SI-BI-02', 'CLASS HC-HKD-ACC',
 'Smart Invest Global Corporate Bond Index Fund',
 'BOND_INDEX', 2, 0.0031, 'Bloomberg Global Corporate Bond Index', '全球投资级企业债券', 100.00),

-- 股票指数基金（风险等级 4–5）
('SI-EI-01', 'CLASS HC-HKD-ACC',
 'Smart Invest US Equity Index Fund',
 'EQUITY_INDEX', 4, 0.0031, 'S&P 500 Net Total Return Index', '美国本土市场 — 纽约证交所及纳斯达克前 500 大公司', 100.00),
('SI-EI-02', 'CLASS HC-HKD-ACC',
 'Smart Invest Global Equity Index Fund',
 'EQUITY_INDEX', 4, 0.0040, 'MSCI World Index', '全球发达市场', 100.00),
('SI-EI-03', 'CLASS HC-HKD-ACC',
 'Smart Invest Hang Seng Index Fund',
 'EQUITY_INDEX', 5, 0.0050, 'Hang Seng Index', '香港股票市场', 100.00),

-- 多资产组合基金（每个风险等级各一只，风险等级 1–5）
('SI-MA-01', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 1（保守型）',
 'MULTI_ASSET', 1, 0.0060, NULL, '多元分散投资 — 保守型', 100.00),
('SI-MA-02', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 2（稳健偏保守型）',
 'MULTI_ASSET', 2, 0.0060, NULL, '多元分散投资 — 稳健偏保守型', 100.00),
('SI-MA-03', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 3（平衡型）',
 'MULTI_ASSET', 3, 0.0060, NULL, '多元分散投资 — 平衡型', 100.00),
('SI-MA-04', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 4（进取型）',
 'MULTI_ASSET', 4, 0.0060, NULL, '多元分散投资 — 中高风险型', 100.00),
('SI-MA-05', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 5（投机型）',
 'MULTI_ASSET', 5, 0.0060, NULL, '多元分散投资 — 高风险型', 100.00);
```

---

## 6. 后端服务开发

### 6.1 Maven 项目结构（模块化单体）

```
backend/
├── pom.xml                              （根聚合 POM）
├── app/                                 （Spring Boot 启动器 + 全局配置）
│   ├── src/main/java/com/smartinvest/
│   │   └── SmartInvestApplication.java
│   └── src/main/resources/
│       ├── application.yml
│       ├── application-local.yml
│       └── application-prod.yml
├── module-user/                         （用户、认证、风险问卷模块）
├── module-fund/                         （基金目录、NAV、资产配置模块）
├── module-order/                        （订单下单、取消模块）
├── module-portfolio/                    （持仓、盈亏计算模块）
├── module-plan/                         （月定投计划模块）
├── module-scheduler/                    （定时任务模块）
└── module-notification/                 （SES 邮件发送模块）
```

### 6.2 根 POM 配置

```xml
<!-- backend/pom.xml -->
```

### 6.3 应用配置文件

```yaml
# app/src/main/resources/application.yml
```

### 6.4 module-user：API 接口清单 & 关键算法

```
POST   /api/auth/register             注册新用户 → 返回 AuthResponse（含 tokens）
POST   /api/auth/login                用户登录 → 返回 access_token + refresh_token
POST   /api/auth/refresh              刷新 access_token
POST   /api/auth/logout               使 refresh_token 失效

GET    /api/users/me                  获取当前用户资料（id、email、fullName、riskLevel）
PUT    /api/users/me                  更新用户资料

GET    /api/risk/questionnaire        获取当前有效问卷（题目 + 选项）
POST   /api/risk/submit               提交问卷答案 → 返回 risk_level，并更新用户记录
GET    /api/risk/assessment/me        获取当前用户最新风险评估结果
```

**风险评分逻辑**（对应用户指南中的 5 个风险等级）：

```java
public RiskLevel calculateRiskLevel(int totalScore) {
    // 共 6 题，每题最高 5 分，满分 30 分
    if (totalScore <= 9)  return CONSERVATIVE;   // 等级 1：保守型
    if (totalScore <= 15) return MODERATE;        // 等级 2：稳健型
    if (totalScore <= 20) return BALANCED;        // 等级 3：平衡型
    if (totalScore <= 25) return ADVENTUROUS;     // 等级 4：进取型
    return SPECULATIVE;                            // 等级 5：投机型
}
```

### 6.5 module-fund：API 接口清单

```
GET    /api/funds                           基金列表（?type=EQUITY_INDEX&riskLevel=4&sortBy=RISK_LEVEL）
GET    /api/funds/{id}                      基金详情（NAV、描述、费用、资产配置）
GET    /api/funds/{id}/nav-history          NAV 历史（?period=3M|6M|1Y|3Y|5Y）
GET    /api/funds/{id}/asset-allocation     资产配置（饼图数据）
GET    /api/funds/{id}/top-holdings         Top 10 持仓（Holdings Tab 数据）
GET    /api/funds/{id}/geo-allocation       地理分布（Geographical Tab 数据）
GET    /api/funds/{id}/sector-allocation    行业分布（Sectors Tab 数据）
GET    /api/funds/multi-asset               全部 5 只多资产组合基金（对应 5 个风险 Tab）
GET    /api/funds/reference-asset-mix       参考资产配置（?riskLevel=4）
```

### 6.6 module-order：API 接口清单

```
POST   /api/orders                          单只基金下单（买入）
POST   /api/orders/portfolio                自建组合批量下单（每只基金各生成一笔订单）
GET    /api/orders                          订单历史查询（?status=PENDING&page=0&size=20）
GET    /api/orders/{id}                     订单详情
DELETE /api/orders/{id}                     取消待处理订单（仅限 PENDING 状态）
```

**订单参考号生成逻辑：**

```java
public String generate(OrderType type) {
    if (type == ONE_TIME) {
        // 一次性投资：P- 前缀 + 6 位随机数
        return "P-" + String.format("%06d",
            ThreadLocalRandom.current().nextInt(100_000, 999_999));
    }
    // 月定投：时间戳（精确到秒）+ 3 位随机后缀
    return LocalDateTime.now()
        .format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
        + String.format("%03d",
            ThreadLocalRandom.current().nextInt(0, 999));
}
```

**结算日期计算（T+2，跳过周末）：**

```java
public LocalDate calculateSettlementDate(LocalDate from, int businessDays) {
    LocalDate date = from;
    int count = 0;
    while (count < businessDays) {
        date = date.plusDays(1);
        if (date.getDayOfWeek() != SATURDAY && date.getDayOfWeek() != SUNDAY) {
            count++;
        }
    }
    return date;
}
```

**自建组合各基金金额分配算法**（对应用户指南 p.19）：

```java
public List<BigDecimal> distributeAmount(BigDecimal total,
                                          List<Integer> percentages) {
    List<BigDecimal> amounts = new ArrayList<>();
    BigDecimal allocated = BigDecimal.ZERO;

    // 前 N-1 只基金按比例分配（向下取整，保留 2 位小数）
    for (int i = 0; i < percentages.size() - 1; i++) {
        BigDecimal amt = total
            .multiply(new BigDecimal(percentages.get(i)))
            .divide(new BigDecimal(100), 2, RoundingMode.DOWN);
        amounts.add(amt);
        allocated = allocated.add(amt);
    }
    // 最后一只基金分配剩余金额，避免舍入误差造成总额不符
    amounts.add(total.subtract(allocated));
    return amounts;
}
```

### 6.7 module-portfolio：API 接口清单

```
GET    /api/portfolio/me              持仓汇总（总市值、总盈亏、持仓列表）
GET    /api/portfolio/me/holdings     各基金持仓明细（含未实现盈亏金额及百分比）
```

### 6.8 module-plan：API 接口清单

```
POST   /api/plans                     创建月定投计划
GET    /api/plans                     获取当前用户所有活跃计划
GET    /api/plans/{id}                计划详情（下次扣款日、已完成笔数、累计投入金额）
DELETE /api/plans/{id}                终止计划（停止后续扣款，不自动赎回持仓）
```

### 6.9 module-scheduler 定时任务

> 类文件：[MonthlyInvestmentScheduler.java](backend/module-scheduler/src/main/java/com/smartinvest/scheduler/MonthlyInvestmentScheduler.java)

---

## 7. 前端开发（移动端 Web）

### 7.1 设计规范

前端为**纯移动端 Web 应用**。所有页面须在 Chrome DevTools 设备工具栏（Device Toolbar）切换至移动端模式时正确渲染。

**目标视口**：390 × 844 px（对应 iPhone 14）  
**响应式断点**：不设计桌面端布局，所有样式面向 `max-width: 430px`  
**设计语言**：基于 Smart Invest 用户指南截图还原 — 白色背景、红色（#DB0011）主操作按钮、简洁的金融类 UI 组件风格

### 7.2 前端技术栈

| 功能模块       | 技术选型                        | 版本   |
| ---------- | --------------------------- | ---- |
| 框架         | React + TypeScript          | 18.x |
| 构建工具       | Vite                        | 5.x  |
| 路由         | React Router                | 6.x  |
| 客户端状态管理    | Zustand                     | 4.x  |
| 服务端状态 / 缓存 | TanStack Query（React Query） | 5.x  |
| HTTP 客户端   | Axios                       | 1.x  |
| UI 样式      | Tailwind CSS                | 3.x  |
| 图表         | Recharts                    | 2.x  |
| 图标         | Lucide React                | 最新版  |
| 动画         | CSS transitions（不引入额外依赖）    | —    |

### 7.3 页面结构（与用户指南截图一一对应）

```
src/pages/
├── auth/
│   ├── LoginPage.tsx                           登录页
│   └── RegisterPage.tsx                        注册页
├── home/
│   └── SmartInvestHomePage.tsx                 Smart Invest 主页（p.3）
│       ├── TotalMarketValue 组件               总市值入口
│       ├── InvestInIndividualFunds 区块
│       │   ├── MoneyMarketCard                 货币市场基金入口
│       │   ├── BondIndexCard                   债券指数基金入口
│       │   └── EquityIndexCard                 股票指数基金入口
│       ├── InvestInPortfolios 区块
│       │   ├── MultiAssetPortfoliosCard        多资产组合入口
│       │   └── BuildYourOwnPortfolioCard       自建组合入口（风险 < 4 时隐藏）
│       └── LearnMoreSection                    投资知识学习区块
├── funds/
│   ├── FundListPage.tsx                        基金列表页（含排序/筛选，p.11）
│   └── FundDetailPage.tsx                      基金详情页（NAV 图表、风险标尺，p.7, p.12）
├── multi-asset/
│   └── MultiAssetPortfolioPage.tsx             多资产组合页（5 个风险 Tab，p.6）
├── build-portfolio/
│   ├── Step1_ReferenceAssetMix.tsx             第 1/5 步：参考资产配置 + 选择基金（p.16–17）
│   ├── Step2_AllocateFunds.tsx                 第 2/5 步：分配比例输入（合计必须 100%，p.18）
│   ├── Step3_InvestmentDetails.tsx             第 3/5 步：投资金额、日期、账户（p.19）
│   ├── Step4_ReviewEachFund.tsx                第 4/5 步：逐只基金审核 + Toast 通知（p.20）
│   └── Step5_BuyConfirmation.tsx               第 5/5 步：所有订单买入确认（p.20）
├── order/
│   ├── OrderSetupPage.tsx                      投资类型 + 金额输入页（p.8, p.13）
│   ├── OrderReviewPage.tsx                     订单信息确认页（p.9）
│   ├── OrderTermsPage.tsx                      条款与条件阅读页（p.9）
│   └── OrderSuccessPage.tsx                    下单成功页（展示订单参考号，p.9）
├── holdings/
│   ├── MyHoldingsPage.tsx                      我的持仓页（总市值，p.22）
│   ├── MyTransactionsPage.tsx                  我的交易页（订单 + 平台费 Tab，p.24）
│   └── MyPlansPage.tsx                         我的投资计划列表页（p.23）
├── plans/
│   ├── PlanDetailPage.tsx                      计划详情页 + 终止计划按钮（p.23）
│   └── PlanTerminationPage.tsx                 终止计划确认页（p.23）
├── orders/
│   ├── OrderDetailPage.tsx                     订单详情页 + 取消订单按钮（p.24）
│   └── CancelOrderPage.tsx                     取消订单确认页（p.24）
└── risk/
    └── RiskQuestionnairePage.tsx               风险承受评估问卷页（p.15）
```

### 7.4 核心组件

**RiskGauge — 风险等级标尺**（还原用户指南 p.7、p.12 的双指示器色彩条）：

> 文件：[frontend/src/components/RiskGauge.tsx](frontend/src/components/RiskGauge.tsx)

**NavChart — NAV 走势图**（支持 3M/6M/1Y/3Y/5Y 切换，对应用户指南 p.7、p.12）：

> 文件：[frontend/src/components/NavChart.tsx](frontend/src/components/NavChart.tsx)

**AllocationForm — 组合分配比例输入**（合计必须精确等于 100%，对应用户指南 p.18）：

> 文件：`frontend/src/components/AllocationForm.tsx`（待实现）

### 7.5 移动端优先 CSS 配置

> 配置文件：[frontend/tailwind.config.js](frontend/tailwind.config.js)

> 入口文件：[frontend/index.html](frontend/index.html)

### 7.6 前端构建与部署至 S3 + CloudFront

```bash
# 构建
cd frontend
npm ci
npm run build         # 输出目录：dist/

# 同步静态资源至 S3（设置长期缓存）
aws s3 sync dist/ s3://smart-invest-frontend-bucket/ \
  --delete \
  --cache-control "public, max-age=31536000, immutable"

# 单独上传 index.html（禁止缓存，保证 SPA 入口始终为最新版本）
aws s3 cp dist/index.html s3://smart-invest-frontend-bucket/index.html \
  --cache-control "no-cache"

# 使 CloudFront 缓存失效
aws cloudfront create-invalidation \
  --distribution-id $CF_DISTRIBUTION_ID \
  --paths "/*"
```

---

## 8. 基础设施即代码（Terraform）

### 8.1 目录结构

```
infrastructure/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   └── outputs.tf
    ├── ec2/
    │   ├── main.tf
    │   ├── user_data.sh
    │   └── outputs.tf
    ├── rds/
    │   ├── main.tf
    │   └── outputs.tf
    ├── s3-cloudfront/
    │   ├── main.tf
    │   └── outputs.tf
    └── iam/
        ├── main.tf
        └── outputs.tf
```

### 8.2 VPC 模块

> 文件：[infrastructure/modules/vpc/main.tf](infrastructure/modules/vpc/main.tf)

### 8.3 EC2 模块

> 配置文件：
> 
> - [infrastructure/modules/ec2/main.tf](infrastructure/modules/ec2/main.tf)
> - [infrastructure/modules/ec2/user_data.sh](infrastructure/modules/ec2/user_data.sh)

### 8.4 RDS 模块

> 文件：[infrastructure/modules/rds/main.tf](infrastructure/modules/rds/main.tf)

### 8.5 S3 + CloudFront 模块

> 文件：[infrastructure/modules/s3-cloudfront/main.tf](infrastructure/modules/s3-cloudfront/main.tf)

### 8.6 基础设施部署执行顺序

```bash
# 第 1 步：初始化并应用所有模块
cd infrastructure
terraform init
terraform plan -out=tfplan -var="admin_cidr=$(curl -s ifconfig.me)/32"
terraform apply tfplan

# 第 2 步：记录关键输出
terraform output -json

# → ec2_public_ip、cloudfront_domain、rds_endpoint、db_secret_arn

# 第 3 步：配置 DNS 解析
# api.yourdomain.com  → A 记录 → ec2_public_ip
# yourdomain.com      → CNAME  → cloudfront_domain

# 第 4 步：上传应用 JAR 包
aws s3 cp backend/app/target/smart-invest-app.jar \
  s3://smart-invest-artifacts/smart-invest-app.jar

# 第 5 步：SSH 登录 EC2 验证服务状态
ssh -i smart-invest.pem ec2-user@<ec2_public_ip>
sudo systemctl status smart-invest
sudo journalctl -u smart-invest -f

# 第 6 步：部署前端
cd frontend
npm run build
aws s3 sync dist/ s3://smart-invest-frontend-<account_id>/ --delete
aws cloudfront create-invalidation --distribution-id <CF_ID> --paths "/*"
```

---

## 9. CI/CD 流水线

### 9.1 CI — Pull Request 检查

> 文件：[.github/workflows/ci.yml](.github/workflows/ci.yml)

### 9.2 CD — 合并至 main 分支后自动部署

> 文件：[.github/workflows/cd.yml](.github/workflows/cd.yml)

---

## 10. 部署指南

### 10.1 首次部署检查清单

```
前置条件：
  ☐ AWS 账号已激活 $200 积分
  ☐ 已创建 IAM 用户并授予 AdministratorAccess（仅限初始部署阶段）
  ☐ AWS CLI 已配置（aws configure）
  ☐ Terraform ≥ 1.9 已安装
  ☐ Java 21 + Maven 已安装
  ☐ Node.js 20 已安装
  ☐ 已注册域名（可选，建议配置以获得规范的访问地址）
  ☐ GitHub 仓库 smart-invest 已创建（可公开或私有）

第 1 步 — 配置 GitHub Secrets：
  AWS_ACCESS_KEY_ID          IAM 部署用户的 Access Key
  AWS_SECRET_ACCESS_KEY      IAM 部署用户的 Secret Key
  EC2_INSTANCE_ID            来自 Terraform 输出
  ARTIFACT_BUCKET            存放 JAR 包的 S3 存储桶名称
  FRONTEND_BUCKET            存放 React 构建产物的 S3 存储桶名称
  CF_DISTRIBUTION_ID         CloudFront 分发 ID
  API_BASE_URL               https://api.yourdomain.com

第 2 步 — 部署基础设施：
  cd infrastructure
  terraform init
  terraform apply

第 3 步 — 初始化数据库：
  # Flyway 在 Spring Boot 首次启动时自动执行迁移
  # 通过 EC2 日志验证：
  sudo journalctl -u smart-invest | grep "Flyway"

第 4 步 — 首次部署应用（手动方式）：
  mvn clean package -f backend/pom.xml -DskipTests
  aws s3 cp backend/app/target/smart-invest-app.jar s3://<BUCKET>/smart-invest-app.jar
  # EC2 首次启动时 user_data.sh 会自动完成下载与服务启动

第 5 步 — 部署前端：
  cd frontend && npm run build
  aws s3 sync dist/ s3://<FRONTEND_BUCKET>/ --delete
  aws cloudfront create-invalidation --distribution-id <CF_ID> --paths "/*"

第 6 步 — 验收验证：
  ☐ https://yourdomain.com 可正常加载 Smart Invest 移动端界面
  ☐ POST https://api.yourdomain.com/api/auth/register 返回 HTTP 201
  ☐ GET  https://api.yourdomain.com/actuator/health 返回 {"status":"UP"}
  ☐ CloudWatch Logs 可看到结构化 JSON 格式日志条目
```

### 10.2 CloudWatch 监控配置

```bash
# 创建应用日志组
aws logs create-log-group --log-group-name /smart-invest/application

# 创建告警：5 分钟内 5xx 错误数超过 10 次
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-5xx-Rate" \
  --metric-name "5XXError" \
  --namespace "AWS/ApiGateway" \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions $SNS_TOPIC_ARN

# 创建告警：EC2 CPU 使用率连续 10 分钟超过 80%
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-CPU-High" \
  --metric-name "CPUUtilization" \
  --namespace "AWS/EC2" \
  --dimensions Name=InstanceId,Value=$EC2_INSTANCE_ID \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions $SNS_TOPIC_ARN
```

---

## 11. 项目时间表

| 周次      | 交付内容                                                        | 里程碑           |
| ------- | ----------------------------------------------------------- | ------------- |
| 第 0 周   | 工具安装、仓库初始化、Terraform 骨架搭建、`docker-compose.yml` 配置           | ✓ 开发环境就绪      |
| 第 1–2 周 | AWS 基础设施（VPC、EC2、RDS、S3、CloudFront）通过 Terraform 完成部署        | ✓ 云环境就绪       |
| 第 2–3 周 | `module-user`：注册、登录、JWT、风险问卷（5 个风险等级）                       | ✓ 认证模块完成      |
| 第 3–4 周 | `module-fund`：基金目录、NAV 历史、资产配置、Top10 持仓、种子数据录入              | ✓ 基金数据就绪      |
| 第 4 周   | `module-order`：单只基金下单（路径 A）、自建组合批量下单（路径 C）、取消订单             | ✓ 核心交易流程完成    |
| 第 5 周   | `module-plan`：月定投计划增删查、终止流程                                 | ✓ 投资计划模块完成    |
| 第 5 周   | `module-portfolio`：持仓计算、未实现盈亏、总市值                           | ✓ 持仓视图完成      |
| 第 5–6 周 | 前端 — 认证页面、Smart Invest 主页、基金列表（含排序/筛选）                      | ✓ 前端框架建立      |
| 第 6–7 周 | 前端 — 基金详情页（NAV 图表、风险标尺、多 Tab）、完整下单流程（4 步 + 5 步）             | ✓ 完整投资流程贯通    |
| 第 7 周   | 前端 — 我的持仓、我的交易、我的计划、取消订单/终止计划流程                             | ✓ 功能全覆盖       |
| 第 8 周   | `module-scheduler`（月定投自动执行） + `module-notification`（SES 邮件） | ✓ 自动化任务完成     |
| 第 9 周   | CI/CD 流水线、GitHub Actions 工作流、EC2 systemd 自动部署               | ✓ DevOps 体系就绪 |
| 第 10 周  | 端到端测试、CloudWatch 告警配置、结构化日志接入                               | ✓ 可观测性完成      |
| 第 11 周  | 生产环境部署、HTTPS 配置、域名绑定、演示数据填充                                 | ✓ **正式上线**    |
| 第 12 周  | README 撰写、系统架构图绘制、项目文档整理                                    | ✓ 仓库文档齐备      |

---

## 12. 代码仓库结构

```
smart-invest/
├── README.md                        项目概述、在线访问地址、架构图
├── CHANGELOG.md                     版本变更记录
├── docs/
│   ├── architecture.png             系统架构图
│   ├── er-diagram.png               数据库 ER 图
│   └── api/                         各模块 OpenAPI YAML 规范文档
├── backend/
│   ├── pom.xml                      根 Maven POM（Java 21）
│   ├── app/                         Spring Boot 启动器
│   ├── module-user/
│   ├── module-fund/
│   ├── module-order/
│   ├── module-portfolio/
│   ├── module-plan/
│   ├── module-scheduler/
│   ├── module-notification/
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── pages/                   路由级页面组件（纯移动端）
│   │   ├── components/              公共 UI 组件
│   │   ├── api/                     各模块 Axios API 客户端
│   │   ├── store/                   Zustand 状态存储
│   │   ├── hooks/                   自定义 React Hooks
│   │   └── types/                   TypeScript 类型定义
│   ├── public/
│   ├── index.html
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   ├── tsconfig.json
│   ├── package.json
│   └── Dockerfile.dev
├── infrastructure/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── modules/
│       ├── vpc/                     网络层（VPC、子网、安全组、IGW）
│       ├── ec2/                     计算层（EC2 实例、弹性 IP、user_data）
│       ├── rds/                     数据库层（PostgreSQL、子网组）
│       ├── s3-cloudfront/           静态资源层（S3 存储桶、CloudFront 分发）
│       └── iam/                     权限层（IAM 角色、实例配置文件、策略）
├── .github/
│   └── workflows/
│       ├── ci.yml                   PR 触发：构建 + 测试 + 校验
│       └── cd.yml                   main 合并触发：打包 + 部署
├── docker-compose.yml               本地全栈联调环境
└── scripts/
    ├── seed-nav-history.py          填充历史 NAV 数据脚本
    └── create-demo-user.sh          创建含预置持仓数据的演示账号脚本
```

---

*本文档作为 `smart-invest` 仓库的组成部分进行版本管理。所有基础设施配置与应用代码均纳入版本控制。各模块的具体实现细节请直接参阅代码仓库中的对应文件。*
