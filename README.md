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

## Overview

Smart Invest is a **Low-cost investment platform** through which, Banks pool small amounts of money from many users, use these funds to buy high-quality funds that only those with large sums of money are eligible to purchase, and then distribute the profits to the users. — modelled after a real-world bank investment app.

**What users can do:**

- Browse and invest in money market, bond index, equity index, and multi-asset funds
- Build custom portfolios with risk-matched fund allocation
- Set up automated monthly investment plans
- Track holdings with real-time unrealised P&L

---

**Architecture:** Modular Monolith on AWS following the [Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) — cost-optimised for a `$200` credit budget (~5–6 months of live operation at ~$34/month).

**Cost Plan:** I have implemented AWS Instance Scheduler to enable services only during weekdays (8:00-12:00 and 14:00-18:00), and automatically shut down EC2 and RDS at other times, reducing server operating costs.
---

## Table of Contents

1. [Product Analysis & Scope](#1-product-analysis--scope)
2. [System Architecture](#2-system-architecture)
3. [AWS Infrastructure Design](#3-aws-infrastructure-design)
4. [Development Environment Setup](#4-development-environment-setup)
5. [Database Design](#5-database-design)
6. [Backend Services Development](#6-backend-services-development)
7. [Frontend Development (Mobile Web)](#7-frontend-development-mobile-web)
8. [Infrastructure as Code (Terraform)](#8-infrastructure-as-code-terraform)
9. [CI/CD Pipeline](#9-cicd-pipeline)
10. [Deployment Guide](#10-deployment-guide)
11. [Project Timeline](#11-project-timeline)
12. [Repository Structure](#12-repository-structure)

---

## 1. Product Analysis & Scope

For detailed content, see: [Product-Analysis-Scope.md](./doc-manually/I.Product-Analysis-Scope.md)

## 2. System Architecture

### 2.1 Architecture Overview

The system follows the **AWS Well-Architected Framework** across its five pillars: Operational Excellence, Security, Reliability, Performance Efficiency, and Cost Optimization.

Given the $200 AWS credit budget, the deployment uses **EC2-hosted Spring Boot services** instead of container orchestration, reducing operational overhead while maintaining production-grade design principles.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         End Users (Mobile Web Browser)                  │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │ HTTPS
┌──────────────────────────────────▼──────────────────────────────────────┐
│                    Amazon CloudFront (CDN + HTTPS termination)           │
│                    AWS Certificate Manager (SSL/TLS — free)             │
└──────────┬───────────────────────────────────────┬──────────────────────┘
           │                                       │
┌──────────▼──────────┐               ┌────────────▼────────────────────┐
│  Amazon S3          │               │  EC2 Instance (t3.small)        │
│  React SPA          │               │  Nginx (reverse proxy)          │
│  (static hosting)   │               │  ┌────────────────────────────┐ │
│                     │               │  │  Spring Boot Application   │ │
│                     │               │  │  (Modular Monolith)        │ │
│                     │               │  │                            │ │
│                     │               │  │  Modules:                  │ │
│                     │               │  │  • UserModule      :8080   │ │
│                     │               │  │  • FundModule              │ │
│                     │               │  │  • OrderModule             │ │
│                     │               │  │  • HoldingModule           │ │
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
│  PostgreSQL 16       │              │  CloudWatch       │  │  (email notify)  │
│  db.t3.micro         │              │  (monitoring +    │  │                  │
│                      │              │   alerting)       │  │                  │
└──────────────────────┘              └───────────────────┘  └──────────────────┘
```

### 2.2 Architecture Decision: Modular Monolith vs. Microservices

**Decision: Modular Monolith on EC2**

| Factor            | Rationale                                                                                                                                 |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Budget constraint | A single EC2 t3.small instance runs all modules within $200 credits                                                                       |
| Simplicity        | No inter-service network calls, no service discovery, no distributed tracing overhead                                                     |
| Modularity        | Each business domain is a separate Spring module with clear package boundaries; migration to microservices is straightforward when needed |
| Production parity | The modular design preserves architectural intent and reflects real-world patterns used in cost-constrained environments                  |

### 2.3 Module Responsibilities

| Module (Spring package) | Responsibilities                                             | API Prefix                                      |
| ----------------------- | ------------------------------------------------------------ | ----------------------------------------------- |
| `user`                  | Registration, login, JWT auth, risk questionnaire            | `/api/auth/**`, `/api/users/**`, `/api/risk/**` |
| `fund`                  | Fund catalogue, NAV history, asset allocation, top holdings  | `/api/funds/**`                                 |
| `order`                 | Place order (individual + portfolio), cancel order           | `/api/orders/**`                                |
| `holding`               | Holdings calculation, unrealised P&L, total market value     | `/api/holdings/**`                              |
| `portfolio`             | Build Your Own Portfolio — create templates, invest proportionally across N funds | `/api/portfolio/**`    |
| `plan`                  | Monthly investment plan management, termination              | `/api/plans/**`                                 |
| `scheduler`             | Monthly plan execution (Spring `@Scheduled`), NAV simulation | Internal                                        |
| `notification`          | Email dispatch via Amazon SES                                | Internal event-driven                           |

### 2.4 AWS Well-Architected Alignment

| Pillar                     | Implementation                                                                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Operational Excellence** | CloudWatch Logs + Alarms; structured JSON logging (Logback); `/actuator/health` endpoints                                                   |
| **Security**               | IAM roles with least privilege; Secrets Manager for DB credentials; ACM for HTTPS; JWT (RS256); Security Groups restricting RDS to EC2 only |
| **Reliability**            | RDS automated backups (7-day retention); EC2 health check with auto-restart (systemd); CloudWatch alarm → SNS notification                  |
| **Performance Efficiency** | CloudFront CDN for static assets; connection pooling (HikariCP); Redis-compatible in-memory caching for NAV data (Spring Cache)             |
| **Cost Optimization**      | Single t3.small EC2; db.t3.micro RDS; S3 + CloudFront for frontend (avoids extra EC2); CloudWatch free tier for monitoring                  |

---

## 3. AWS Infrastructure Design

### 3.1 Services Used & Cost Estimate

| Service                 | Specification                                      | Monthly Cost (est.) |
| ----------------------- | -------------------------------------------------- | ------------------- |
| EC2 t3.small            | 1 instance (2 vCPU, 2 GB RAM) — application server | ~$17 (credits)      |
| RDS PostgreSQL 16       | db.t3.micro, 20 GB gp2, single-AZ                  | ~$15 (credits)      |
| Amazon S3               | Static frontend hosting, ~100 MB                   | ~$0.01 (credits)    |
| Amazon CloudFront       | CDN for S3 frontend, HTTPS termination             | ~$1 (credits)       |
| AWS Certificate Manager | SSL/TLS certificate for custom domain              | Free                |
| Amazon SES              | Email notifications (~500/month)                   | Free tier           |
| Amazon CloudWatch       | Logs + 10 metrics + 10 alarms                      | Free tier           |
| Amazon SNS              | Alert notifications                                | Free tier           |
| Route 53                | DNS for custom domain (optional)                   | ~$0.50              |
| AWS IAM                 | Identity & access management                       | Free                |
| **Total**               |                                                    | **~$34/month**      |

> With $200 credits, this architecture sustains approximately **5–6 months** of continuous operation.

### 3.2 Network Architecture

```
Internet
    │
    ▼
CloudFront Distribution
    ├── /static/* → S3 Bucket (React SPA)
    └── /api/*   → EC2 Public IP (Nginx :443)
         │
         ▼
    EC2 Security Group:
    - Inbound: 443 (HTTPS, 0.0.0.0/0), 22 (SSH, your IP only)
    - Outbound: All
         │
         ▼
    Spring Boot Application (:8080, internal only)
         │
         ▼
    RDS Security Group:
    - Inbound: 5432 (PostgreSQL, EC2 Security Group ID only)
```

### 3.3 Security Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Public Subnet                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  EC2 (t3.small)                                │    │
│  │  IAM Role: smart-invest-app-role               │    │
│  │  Permissions:                                  │    │
│  │    - secretsmanager:GetSecretValue             │    │
│  │    - ses:SendEmail                             │    │
│  │    - cloudwatch:PutMetricData                  │    │
│  │    - logs:CreateLogGroup, PutLogEvents         │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Private Subnet (RDS resides in isolated subnet)        │
│  ┌────────────────────────────────────────────────┐    │
│  │  RDS PostgreSQL                                │    │
│  │  Credentials: AWS Secrets Manager             │    │
│  │  Encryption at rest: AES-256 (default)        │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Development Environment Setup

### 4.1 Required Tools

```bash
# ── Java 21 via SDKMAN ──────────────────────────────────────────────────
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-open
sdk use java 21-open
java --version   # must show: openjdk 21

# ── Maven 3.9+ ──────────────────────────────────────────────────────────
sdk install maven 3.9.6
mvn --version

# ── Node.js 20 LTS (frontend) ───────────────────────────────────────────
# macOS:
brew install node@20

# Ubuntu/Debian:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version && npm --version

# ── Docker Desktop ──────────────────────────────────────────────────────
# Download: https://www.docker.com/products/docker-desktop/
docker --version

# ── AWS CLI v2 ──────────────────────────────────────────────────────────
# macOS:
brew install awscli

# Linux:
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

aws configure

# Prompts:
# AWS Access Key ID     → [your IAM user access key]
# AWS Secret Access Key → [your IAM user secret]
# Default region name   → us-east-1   (or ap-east-1 for Hong Kong)
# Default output format → json

# ── Terraform 1.9+ ──────────────────────────────────────────────────────
# macOS:
brew tap hashicorp/tap && brew install hashicorp/tap/terraform

# Linux:
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform --version

# ── Session Manager Plugin (SSH-free EC2 access) ──────────────────────
# macOS:
brew install --cask session-manager-plugin

# Linux: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
```

### 4.2 Local Development with Docker Compose

> File: [docker-compose.yml](docker-compose.yml)

---

## 5. Database Design

### 5.1 Schema Overview

All tables reside in a single PostgreSQL 16 database (`smartinvest`). Schema migrations are managed by **Flyway**, versioned incrementally.

### 5.2 Migration Files

> Directory: [backend/app/src/main/resources/db/migration](backend/app/src/main/resources/db/migration)

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
├── [V10__create_user_portfolios.sql](backend/app/src/main/resources/db/migration/V10__create_user_portfolios.sql)
├── [V11__create_orders.sql](backend/app/src/main/resources/db/migration/V11__create_orders.sql)
├── [V12__create_investment_plans.sql](backend/app/src/main/resources/db/migration/V12__create_investment_plans.sql)
├── [V13__create_holdings.sql](backend/app/src/main/resources/db/migration/V13__create_holdings.sql)
├── [V14__seed_funds.sql](backend/app/src/main/resources/db/migration/V14__seed_funds.sql)
├── [V15__seed_demo_data.sql](backend/app/src/main/resources/db/migration/V15__seed_demo_data.sql)
├── [V16__seed_nav_and_demo.sql](backend/app/src/main/resources/db/migration/V16__seed_nav_and_demo.sql)
├── [V17__seed_nav_history.sql](backend/app/src/main/resources/db/migration/V17__seed_nav_history.sql)
├── [V18__seed_fund_allocations.sql](backend/app/src/main/resources/db/migration/V18__seed_fund_allocations.sql)
├── [V19__seed_demo_orders.sql](backend/app/src/main/resources/db/migration/V19__seed_demo_orders.sql)
└── [V20__seed_demo_plans.sql](backend/app/src/main/resources/db/migration/V20__seed_demo_plans.sql)
```

### 5.3 DDL — Core Tables

```sql
-- V1__create_users.sql
CREATE TABLE users (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    email        VARCHAR(255) UNIQUE NOT NULL,
    password     VARCHAR(255) NOT NULL,          -- BCrypt hash
    full_name    VARCHAR(255) NOT NULL,
    risk_level   SMALLINT,                        -- NULL = questionnaire not completed; 1–5
    status       VARCHAR(20)  DEFAULT 'ACTIVE',
    created_at   TIMESTAMPTZ  DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  DEFAULT NOW()
);

-- V2__create_risk_assessments.sql
CREATE TABLE risk_assessments (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answers      JSONB       NOT NULL,            -- {"q1": "B", "q2": "C", ...}
    total_score  INTEGER     NOT NULL,
    risk_level   SMALLINT    NOT NULL,
    assessed_at  TIMESTAMPTZ DEFAULT NOW()
);

-- V3__create_funds.sql
CREATE TABLE funds (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(30)  UNIQUE NOT NULL,   -- e.g. "U50009"
    isin_class      VARCHAR(50),                    -- e.g. "CLASS HC-HKD-ACC"
    name            VARCHAR(300) NOT NULL,
    fund_type       VARCHAR(30)  NOT NULL,
    -- MONEY_MARKET | BOND_INDEX | EQUITY_INDEX | MULTI_ASSET
    risk_level      SMALLINT     NOT NULL,           -- 0–5
    currency        VARCHAR(5)   DEFAULT 'HKD',
    current_nav     DECIMAL(15,4),
    nav_date        DATE,
    annual_mgmt_fee DECIMAL(6,4),                   -- e.g. 0.0031 = 0.31%
    min_investment  DECIMAL(12,2) DEFAULT 100.00,
    benchmark_index VARCHAR(300),
    market_focus    VARCHAR(200),
    description     TEXT,
    is_active       BOOLEAN      DEFAULT TRUE,
    created_at      TIMESTAMPTZ  DEFAULT NOW()
);

-- V4__create_fund_nav_history.sql
CREATE TABLE fund_nav_history (
    id       BIGSERIAL    PRIMARY KEY,
    fund_id  UUID         NOT NULL REFERENCES funds(id),
    nav      DECIMAL(15,4) NOT NULL,
    nav_date DATE         NOT NULL,
    UNIQUE (fund_id, nav_date)
);
CREATE INDEX idx_nav_history_fund_date ON fund_nav_history (fund_id, nav_date DESC);

-- V5__create_fund_asset_allocations.sql
CREATE TABLE fund_asset_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    asset_class VARCHAR(50)  NOT NULL,  -- Stocks | Bonds | Cash | Others | Real Estate
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);

-- V6__create_fund_top_holdings.sql
CREATE TABLE fund_top_holdings (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id      UUID         NOT NULL REFERENCES funds(id),
    holding_name VARCHAR(200) NOT NULL,
    weight       DECIMAL(6,2) NOT NULL,
    as_of_date   DATE         NOT NULL,
    sequence     SMALLINT     NOT NULL    -- ranking 1–10
);

-- V7__create_fund_geo_allocations.sql
CREATE TABLE fund_geo_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    region      VARCHAR(100) NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);

-- V8__create_fund_sector_allocations.sql
CREATE TABLE fund_sector_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    sector      VARCHAR(100) NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);

-- V9__create_reference_asset_mix.sql
-- Reference asset mix shown in "Build a portfolio" (Step 1/5)
CREATE TABLE reference_asset_mix (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    risk_level  SMALLINT     NOT NULL,    -- 4 or 5 (only accessible risk levels)
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
    nav_at_order        DECIMAL(15,4),
    executed_units      DECIMAL(18,6),
    investment_account  VARCHAR(100),
    settlement_account  VARCHAR(100),
    status              VARCHAR(20)  DEFAULT 'PENDING',
    -- PENDING | PROCESSING | COMPLETED | CANCELLED | FAILED
    order_date          DATE         NOT NULL DEFAULT CURRENT_DATE,
    settlement_date     DATE,                    -- T+2 business days
    plan_id             UUID,                    -- FK to investment_plans (nullable)
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
    avg_cost_nav    DECIMAL(15,4),
    total_invested  DECIMAL(15,2) DEFAULT 0.00,
    updated_at      TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE (user_id, fund_id)
);

-- V13__seed_funds.sql
-- Based on funds visible in the User Guide screenshots
INSERT INTO funds (code, isin_class, name, fund_type, risk_level, annual_mgmt_fee, benchmark_index, market_focus, min_investment) VALUES
-- Money Market (Risk 1)
('SI-MM-01', 'CLASS D-ACC',
 'Smart Invest Global Money Funds - Hong Kong Dollar',
 'MONEY_MARKET', 1, 0.0031, NULL, 'Hong Kong Money Market instruments', 100.00),

-- Bond Index (Risk 1–2)
('SI-BI-01', 'CLASS HC-HKD-ACC',
 'Smart Invest Global Aggregate Bond Index Fund',
 'BOND_INDEX', 1, 0.0025, 'Bloomberg Global Aggregate Bond Index', 'Global investment-grade bonds', 100.00),
('SI-BI-02', 'CLASS HC-HKD-ACC',
 'Smart Invest Global Corporate Bond Index Fund',
 'BOND_INDEX', 2, 0.0031, 'Bloomberg Global Corporate Bond Index', 'Global investment-grade corporates', 100.00),

-- Equity Index (Risk 4–5)
('SI-EI-01', 'CLASS HC-HKD-ACC',
 'Smart Invest US Equity Index Fund',
 'EQUITY_INDEX', 4, 0.0031, 'S&P 500 Net Total Return Index', 'US domestic market — NYSE and NASDAQ top 500', 100.00),
('SI-EI-02', 'CLASS HC-HKD-ACC',
 'Smart Invest Global Equity Index Fund',
 'EQUITY_INDEX', 4, 0.0040, 'MSCI World Index', 'Global developed markets', 100.00),
('SI-EI-03', 'CLASS HC-HKD-ACC',
 'Smart Invest Hang Seng Index Fund',
 'EQUITY_INDEX', 5, 0.0050, 'Hang Seng Index', 'Hong Kong equity market', 100.00),

-- Multi-Asset Portfolios — one per risk level (Risk 1–5)
('SI-MA-01', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 1 (Conservative)',
 'MULTI_ASSET', 1, 0.0060, NULL, 'Diversified conservative multi-asset', 100.00),
('SI-MA-02', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 2 (Moderately Conservative)',
 'MULTI_ASSET', 2, 0.0060, NULL, 'Diversified moderately conservative multi-asset', 100.00),
('SI-MA-03', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 3 (Balanced)',
 'MULTI_ASSET', 3, 0.0060, NULL, 'Diversified balanced multi-asset', 100.00),
('SI-MA-04', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 4 (Adventurous)',
 'MULTI_ASSET', 4, 0.0060, NULL, 'Diversified medium-to-high risk multi-asset', 100.00),
('SI-MA-05', 'CLASS BC-HKD-ACC',
 'Smart Invest Portfolios - World Selection 5 (Speculative)',
 'MULTI_ASSET', 5, 0.0060, NULL, 'Diversified high-risk multi-asset', 100.00);
```

---

## 6. Backend Services Development

### 6.1 Maven Project Structure (Modular Monolith)

```
backend/
├── pom.xml                              (root aggregator)
├── app/                                 (Spring Boot launcher + config)
│   ├── src/main/java/com/smartinvest/
│   │   └── SmartInvestApplication.java
│   └── src/main/resources/
│       ├── application.yml
│       ├── application-local.yml
│       └── application-prod.yml
├── module-user/                         (User, Auth, Risk modules)
├── module-fund/                         (Fund catalogue, NAV, allocations)
├── module-order/                        (Order placement, settlement, cancellation)
├── module-holding/                      (Holdings, P&L calculation)
├── module-portfolio/                    (Build Your Own Portfolio — templates + invest)
├── module-plan/                         (Monthly investment plans)
├── module-scheduler/                    (Cron jobs)
└── module-notification/                 (SES email dispatch)
```

### 6.2 Root POM

```xml
<!-- backend/pom.xml -->
```

### 6.3 Application Configuration

```yaml
# app/src/main/resources/application.yml
```

### 6.4 module-user: API Reference & Key Algorithms

```
POST   /api/auth/register             Register new user → returns AuthResponse
POST   /api/auth/login                Authenticate → returns access_token + refresh_token
POST   /api/auth/refresh              Exchange refresh_token → new access_token
POST   /api/auth/logout               Invalidate refresh_token

GET    /api/users/me                  Current user profile (id, email, fullName, riskLevel)
PUT    /api/users/me                  Update user profile

GET    /api/risk/questionnaire        Fetch active questionnaire (questions + options)
POST   /api/risk/submit               Submit answers → returns risk_level; updates user
GET    /api/risk/assessment/me        Latest risk assessment result for current user
```

**Risk scoring logic** (matches 5 risk levels from User Guide):

```java
public RiskLevel calculateRiskLevel(int totalScore) {
    // 6 questions × 5 points max = 30 max score
    if (totalScore <= 9)  return CONSERVATIVE;   // Level 1
    if (totalScore <= 15) return MODERATE;        // Level 2
    if (totalScore <= 20) return BALANCED;        // Level 3
    if (totalScore <= 25) return ADVENTUROUS;     // Level 4
    return SPECULATIVE;                            // Level 5
}
```

### 6.5 module-fund: API Reference

```
GET    /api/funds                           Fund list (?type=EQUITY_INDEX&riskLevel=4&sortBy=RISK_LEVEL)
GET    /api/funds/{id}                      Fund detail (NAV, description, fees, asset allocation)
GET    /api/funds/{id}/nav-history          NAV history (?period=3M|6M|1Y|3Y|5Y)
GET    /api/funds/{id}/asset-allocation     Asset allocation (pie chart data)
GET    /api/funds/{id}/top-holdings         Top 10 holdings (Holdings tab)
GET    /api/funds/{id}/geo-allocation       Geographical distribution
GET    /api/funds/{id}/sector-allocation    Sector distribution
GET    /api/funds/multi-asset               All 5 multi-asset portfolios (for 5-tab ribbon)
GET    /api/funds/reference-asset-mix       Reference asset mix (?riskLevel=4)
```

### 6.6 module-order: API Reference

```
POST   /api/orders                          Place order for single fund (BUY)
POST   /api/orders/portfolio                Place portfolio orders (batch — one per fund)
GET    /api/orders                          Order history (?status=PENDING&page=0&size=20)
GET    /api/orders/{id}                     Order detail
DELETE /api/orders/{id}                     Cancel PENDING order only
```

**Order reference number generation:**

```java
public String generate(OrderType type) {
    if (type == ONE_TIME) {
        return "P-" + String.format("%06d",
            ThreadLocalRandom.current().nextInt(100_000, 999_999));
    }
    return LocalDateTime.now()
        .format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
        + String.format("%03d",
            ThreadLocalRandom.current().nextInt(0, 999));
}
```

**Settlement date calculation (T+2, skip weekends):**

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

**Portfolio order amount distribution** (User Guide p.19):

```java
public List<BigDecimal> distributeAmount(BigDecimal total,
                                          List<Integer> percentages) {
    List<BigDecimal> amounts = new ArrayList<>();
    BigDecimal allocated = BigDecimal.ZERO;

    for (int i = 0; i < percentages.size() - 1; i++) {
        BigDecimal amt = total
            .multiply(new BigDecimal(percentages.get(i)))
            .divide(new BigDecimal(100), 2, RoundingMode.DOWN);
        amounts.add(amt);
        allocated = allocated.add(amt);
    }
    // Last fund receives the remainder to avoid rounding loss
    amounts.add(total.subtract(allocated));
    return amounts;
}
```

### 6.7 module-holding: API Reference

```
GET    /api/holdings/me              Holdings list with market value per fund
GET    /api/holdings/me/summary      Total market value summary
```

### 6.8 module-portfolio: API Reference

```
POST   /api/portfolio                Create a portfolio template (name + fund allocations, must sum to 100%)
GET    /api/portfolio                List all active portfolio templates for current user
GET    /api/portfolio/{id}           Portfolio template detail (name, allocations, created date)
DELETE /api/portfolio/{id}           Soft-delete a portfolio template
POST   /api/portfolio/{id}/invest    Invest from portfolio — split total amount proportionally,
                                     creates N orders (ONE_TIME) or N plans (MONTHLY)
```

### 6.9 module-plan: API Reference

```
POST   /api/plans                     Create monthly investment plan
GET    /api/plans                     List active plans for current user
GET    /api/plans/{id}                Plan detail (next contribution date, completed orders, total invested)
DELETE /api/plans/{id}                Terminate plan (stops future contributions; does not sell holdings)
```

### 6.10 module-scheduler

> Class file: [MonthlyInvestmentScheduler.java](backend/module-scheduler/src/main/java/com/smartinvest/scheduler/MonthlyInvestmentScheduler.java)

---

## 7. Frontend Development (Mobile Web)

### 7.1 Design Specification

The frontend is a **mobile-only web application**. All pages must render correctly at mobile viewport sizes as defined in Chrome DevTools Device Toolbar.

**Target viewport**: 390 × 844 px (iPhone 14 equivalent)  
**Breakpoints**: No desktop layout required; all styles target `max-width: 430px`  
**Design language**: Adapted from Smart Invest User Guide screenshots — clean white backgrounds, red (#DB0011) primary actions, HSBC-inspired component patterns

### 7.2 Technology Stack

| Concern                | Library                               | Version |
| ---------------------- | ------------------------------------- | ------- |
| Framework              | React + TypeScript                    | 18.x    |
| Build tool             | Vite                                  | 5.x     |
| Routing                | React Router                          | 6.x     |
| State management       | Zustand                               | 4.x     |
| Server state / caching | TanStack Query (React Query)          | 5.x     |
| HTTP client            | Axios                                 | 1.x     |
| UI components          | Tailwind CSS                          | 3.x     |
| Charts                 | Recharts                              | 2.x     |
| Icons                  | Lucide React                          | latest  |
| Animations             | CSS transitions (no external library) | —       |

### 7.3 Page Structure (maps 1:1 to User Guide screens)

```
src/pages/
├── auth/
│   ├── LoginPage.tsx
│   └── RegisterPage.tsx
├── home/
│   └── SmartInvestHomePage.tsx          ← Main SmartInvest dashboard (p.3)
│       ├── TotalMarketValue widget
│       ├── InvestInIndividualFunds section
│       │   ├── MoneyMarketCard
│       │   ├── BondIndexCard
│       │   └── EquityIndexCard
│       ├── InvestInPortfolios section
│       │   ├── MultiAssetPortfoliosCard
│       │   └── BuildYourOwnPortfolioCard  ← hidden for risk < 4
│       └── LearnMoreSection
├── funds/
│   ├── FundListPage.tsx                  ← Fund list with sort/filter (p.11)
│   └── FundDetailPage.tsx               ← Fund detail with chart, risk gauge (p.7, p.12)
├── multi-asset/
│   └── MultiAssetPortfolioPage.tsx      ← 5-tab ribbon page (p.6)
├── build-portfolio/
│   ├── Step1_ReferenceAssetMix.tsx      ← Reference asset mix + fund selection (p.16–17)
│   ├── Step2_AllocateFunds.tsx          ← Allocation % input, must total 100% (p.18)
│   ├── Step3_InvestmentDetails.tsx      ← Amount, start date, accounts (p.19)
│   ├── Step4_ReviewEachFund.tsx         ← Per-fund review with toast notification (p.20)
│   └── Step5_BuyConfirmation.tsx        ← All orders confirmed (p.20)
├── order/
│   ├── OrderSetupPage.tsx               ← Investment type + amount (p.8, p.13)
│   ├── OrderReviewPage.tsx              ← Review all details (p.9)
│   ├── OrderTermsPage.tsx               ← T&C acceptance (p.9)
│   └── OrderSuccessPage.tsx             ← Order reference number (p.9)
├── holdings/
│   ├── MyHoldingsPage.tsx               ← Total market value + nav (p.22)
│   ├── MyTransactionsPage.tsx           ← Orders + Platform fees tabs (p.24)
│   └── MyPlansPage.tsx                  ← Active plans list (p.23)
├── plans/
│   ├── PlanDetailPage.tsx               ← Plan detail + Terminate plan (p.23)
│   └── PlanTerminationPage.tsx          ← Termination review + confirm (p.23)
├── orders/
│   ├── OrderDetailPage.tsx              ← Order status + Cancel order (p.24)
│   └── CancelOrderPage.tsx              ← Cancel confirmation (p.24)
└── risk/
    └── RiskQuestionnairePage.tsx        ← Risk profile questionnaire (p.15)
```

### 7.4 Key Components

**RiskGauge** — replicates the 0–5 colour bar with dual indicators (User Guide p.7, p.12):

> File: [frontend/src/components/RiskGauge.tsx](frontend/src/components/RiskGauge.tsx)

**NavChart** — 3M/6M/1Y/3Y/5Y toggle (User Guide p.7, p.12):

> File: [frontend/src/components/NavChart.tsx](frontend/src/components/NavChart.tsx)

**AllocationForm** — percentage inputs must total exactly 100% (User Guide p.18):

> File: `frontend/src/components/AllocationForm.tsx` (pending implementation)

### 7.5 Mobile-First CSS Configuration

> Config file: [frontend/tailwind.config.js](frontend/tailwind.config.js)

> Entry file: [frontend/index.html](frontend/index.html)

### 7.6 Frontend Build & Deployment to S3 + CloudFront

```bash
# Build
cd frontend
npm ci
npm run build         # output: dist/

# Deploy to S3
aws s3 sync dist/ s3://smart-invest-frontend-bucket/ \
  --delete \
  --cache-control "public, max-age=31536000, immutable"

aws s3 cp dist/index.html s3://smart-invest-frontend-bucket/index.html \
  --cache-control "no-cache"   # SPA entry — always re-validate

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $CF_DISTRIBUTION_ID \
  --paths "/*"
```

---

## 8. Infrastructure as Code (Terraform)

### 8.1 Directory Structure

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

### 8.2 VPC Module

> File: [infrastructure/modules/vpc/main.tf](infrastructure/modules/vpc/main.tf)

### 8.3 EC2 Module

> Files:
> 
> - [infrastructure/modules/ec2/main.tf](infrastructure/modules/ec2/main.tf)
> - [infrastructure/modules/ec2/user_data.sh](infrastructure/modules/ec2/user_data.sh)

### 8.4 RDS Module

> File: [infrastructure/modules/rds/main.tf](infrastructure/modules/rds/main.tf)

### 8.5 S3 + CloudFront Module

> File: [infrastructure/modules/s3-cloudfront/main.tf](infrastructure/modules/s3-cloudfront/main.tf)

### 8.6 Deployment Execution Order

```bash
# 1. Initialise and apply all modules
cd infrastructure
terraform init
terraform plan -out=tfplan -var="admin_cidr=$(curl -s ifconfig.me)/32"
terraform apply tfplan

# 2. Note outputs
terraform output -json

# → ec2_public_ip, cloudfront_domain, rds_endpoint, db_secret_arn

# 3. Update DNS (Route 53 or external DNS provider)
#    api.yourdomain.com  → A record → ec2_public_ip
#    yourdomain.com      → CNAME   → cloudfront_domain

# 4. Upload initial application JAR
aws s3 cp backend/app/target/smart-invest-app.jar \
  s3://smart-invest-artifacts/smart-invest-app.jar

# 5. SSH into EC2 and verify service
ssh -i smart-invest.pem ec2-user@<ec2_public_ip>
sudo systemctl status smart-invest
sudo journalctl -u smart-invest -f

# 6. Deploy frontend
cd frontend
npm run build
aws s3 sync dist/ s3://smart-invest-frontend-<account_id>/ --delete
aws cloudfront create-invalidation --distribution-id <CF_ID> --paths "/*"
```

---

## 9. CI/CD Pipeline

### 9.1 CI — Pull Request Checks

> File: [.github/workflows/ci.yml](.github/workflows/ci.yml)

### 9.2 CD — Deploy on Merge to Main

> File: [.github/workflows/cd.yml](.github/workflows/cd.yml)

---

## 10. Deployment Guide

### 10.1 First-Time Deployment Checklist

```
Pre-requisites:
  ☐ AWS account with $200 credits activated
  ☐ IAM user created with AdministratorAccess (for initial setup only)
  ☐ AWS CLI configured (aws configure)
  ☐ Terraform ≥ 1.9 installed
  ☐ Java 21 + Maven installed
  ☐ Node.js 20 installed
  ☐ Domain name (optional, but recommended for resume link)
  ☐ GitHub repository: smart-invest (public or private)

Step 1 — Configure GitHub Secrets:
  AWS_ACCESS_KEY_ID          IAM deploy user access key
  AWS_SECRET_ACCESS_KEY      IAM deploy user secret key
  EC2_INSTANCE_ID            From Terraform output
  ARTIFACT_BUCKET            S3 bucket name for JARs
  FRONTEND_BUCKET            S3 bucket name for React build
  CF_DISTRIBUTION_ID         CloudFront distribution ID
  API_BASE_URL               https://api.yourdomain.com

Step 2 — Deploy Infrastructure:
  cd infrastructure
  terraform init
  terraform apply

Step 3 — Initial Database Setup:
  # Flyway runs automatically on first Spring Boot start
  # Verify via EC2 logs:
  sudo journalctl -u smart-invest | grep "Flyway"

Step 4 — Deploy Application (first time):
  # Trigger CD pipeline by pushing to main, or manually:
  mvn clean package -f backend/pom.xml -DskipTests
  aws s3 cp backend/app/target/smart-invest-app.jar s3://<BUCKET>/smart-invest-app.jar
  # SSH to EC2 and start service (user_data.sh handles this on first boot)

Step 5 — Deploy Frontend:
  cd frontend && npm run build
  aws s3 sync dist/ s3://<FRONTEND_BUCKET>/ --delete
  aws cloudfront create-invalidation --distribution-id <CF_ID> --paths "/*"

Step 6 — Verify:
  ☐ https://yourdomain.com loads the Smart Invest mobile UI
  ☐ POST https://api.yourdomain.com/api/auth/register returns 201
  ☐ GET  https://api.yourdomain.com/actuator/health returns {"status":"UP"}
  ☐ CloudWatch Logs show structured JSON log entries
```

### 10.2 CloudWatch Monitoring Setup

```bash
# Create log group
aws logs create-log-group --log-group-name /smart-invest/application

# Create alarm: 5xx error rate > 1% in 5 minutes
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

# Create alarm: EC2 CPU > 80%
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

## 11. Project Timeline

| Week | Deliverable                                                                                  | Milestone                       |
| ---- | -------------------------------------------------------------------------------------------- | ------------------------------- |
| 0    | Tool installation, repository initialisation, Terraform skeleton, `docker-compose.yml`       | ✓ Development environment ready |
| 1–2  | AWS infrastructure (VPC, EC2, RDS, S3, CloudFront) provisioned via Terraform                 | ✓ Cloud environment ready       |
| 2–3  | `module-user`: registration, login, JWT, risk questionnaire (5 risk levels)                  | ✓ Authentication complete       |
| 3–4  | `module-fund`: fund catalogue, NAV history, asset allocation, top holdings, seed data        | ✓ Fund data ready               |
| 4    | `module-order`: single-fund order (Pathway A), portfolio batch order (Pathway C), cancel     | ✓ Core transaction flow         |
| 5    | `module-plan`: monthly investment plan CRUD, termination flow                                | ✓ Investment plans              |
| 5    | `module-holding`: holdings calculation, unrealised P&L; `module-portfolio`: Build Your Own Portfolio templates + invest | ✓ Holdings view |
| 5–6  | Frontend — authentication pages, Smart Invest home page, fund list with sort/filter          | ✓ Frontend foundation           |
| 6–7  | Frontend — fund detail page (NAV chart, risk gauge, tabs), all order flows (4-step + 5-step) | ✓ Full investment flows         |
| 7    | Frontend — My Holdings, My Transactions, My Plans, cancel order/plan flows                   | ✓ Complete feature coverage     |
| 8    | `module-scheduler` + `module-notification` (SES email)                                       | ✓ Automation complete           |
| 9    | CI/CD pipeline, GitHub Actions workflows, EC2 systemd auto-deploy                            | ✓ DevOps ready                  |
| 10   | End-to-end testing, CloudWatch alarms, structured logging                                    | ✓ Observability complete        |
| 11   | Production deployment, HTTPS, domain configuration, demo data population                     | ✓ **Live on production**        |
| 12   | README, architecture diagram, project documentation                                          | ✓ Repository ready              |

---

## 12. Repository Structure

```
smart-invest/
├── README.md                        Project overview, live URL, architecture diagram
├── CHANGELOG.md
├── docs/
│   ├── architecture.png             System architecture diagram
│   ├── er-diagram.png               Entity-relationship diagram
│   └── api/                         OpenAPI YAML specifications per module
├── backend/
│   ├── pom.xml                      Root Maven POM (Java 21)
│   ├── app/                         Spring Boot launcher
│   ├── module-user/
│   ├── module-fund/
│   ├── module-order/
│   ├── module-holding/
│   ├── module-portfolio/
│   ├── module-plan/
│   ├── module-scheduler/
│   ├── module-notification/
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── pages/                   Route-level components (mobile-only)
│   │   ├── components/              Shared UI components
│   │   ├── api/                     Axios API clients per module
│   │   ├── store/                   Zustand state stores
│   │   ├── hooks/                   Custom React hooks
│   │   └── types/                   TypeScript type definitions
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
│       ├── vpc/
│       ├── ec2/
│       ├── rds/
│       ├── s3-cloudfront/
│       └── iam/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── docker-compose.yml               Local full-stack development
└── scripts/
    ├── seed-nav-history.py          Populate historical NAV data
    └── create-demo-user.sh          Create demo account with pre-seeded holdings
```

---

*Document maintained as part of the `smart-invest` repository. All infrastructure and application code is version-controlled. Refer to the code in the repository for implementation details.*
