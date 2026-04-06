# Smart Invest — Project Development Roadmap

**Repository**: `smart-invest`  
**Version**: 3.0  
**Tech Stack**: Java 21 · Spring Boot 3.3 · React 18 (Mobile Web) · AWS EC2 · PostgreSQL · Terraform  
**Reference Document**: Smart Invest User Guide (adapted from SmartInvestInvest User Guide)

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

### 1.1 Core Business Entities

Extracted from the Smart Invest User Guide (all 26 pages):

| Entity              | Key Attributes                                                  | Source    |
| ------------------- | --------------------------------------------------------------- | --------- |
| User                | email, password, full_name, risk_level (1–5), status            | p.3, p.15 |
| Fund                | code, name, type, NAV, risk_level, annual_fee, asset_allocation | p.7, p.12 |
| Fund Type           | MONEY_MARKET / BOND_INDEX / EQUITY_INDEX / MULTI_ASSET          | p.4, p.10 |
| Holding             | user_id, fund_id, total_units, avg_cost_nav, total_invested     | p.22      |
| Order               | type, amount, reference_number, status, settlement_date         | p.9, p.14 |
| Investment Plan     | monthly_amount, next_contribution_date, completed_orders        | p.23      |
| Portfolio Build     | selected_funds + allocation_percentages (must sum to 100%)      | p.18      |
| Reference Asset Mix | recommended asset class ratios per risk level                   | p.16      |

### 1.2 Three Investment Pathways

**Pathway A — Individual Fund Investment** (Money Market / Bond Index / Equity Index)

```
Browse fund list (sort + filter)
  → View fund detail (NAV chart / holdings / risk gauge / fees)
  → Tap "Invest now"
  → Select investment type: Monthly Plan or One-Time
  → Enter amount (min. 100 HKD) + start date
  → Select investment account + settlement account
  → Review page
  → Read Terms & Conditions → Confirm
  → Buy confirmation page with order reference number
```

**Pathway B — Multi-Asset Portfolio Investment**

```
Navigate to "Multi-asset portfolios"
  → View 5-tab ribbon (one tab per risk level 1–5)
  → Each tab: fund name, 6-month return, asset allocation pie chart
  → Tap "View fund details" for full details
  → Tap "Invest now" → same order flow as Pathway A (min. 100 HKD)
```

**Pathway C — Build Your Own Portfolio** *(Risk level 4 or 5 only)*

```
Navigate to "Build your own portfolio"
  → Step 1/5: View reference asset mix → Select funds (multi-select, filter/sort)
  → Step 2/5: Allocate percentages (must total exactly 100%)
  → Step 3/5: Investment details (Monthly/One-Time, min. 500 HKD total, start date, accounts)
  → Step 4/5: Review each fund one-by-one (notification appears per fund)
  → Step 5/5: Buy confirmation with individual order reference numbers per fund
```

### 1.3 Holdings & Transaction Management

**My Holdings Page**

- Total market value
- My transactions (with pending count badge)
- My investment plans (with active count badge)
- Individual fund holdings list with unrealised gain/loss

**My Transactions Page**

- Two tabs: Orders | Platform fees
- Orders grouped by month
- Status indicators: Pending (orange) / Cancelled (grey) / Completed (green)
- In-app history: 90 days; eStatement: 24 months

**Cancelling an Investment Plan** (4-step flow from User Guide p.23)

1. My Holdings → My investment plans
2. Select active plan
3. Tap "Terminate plan"
4. Review termination details → Confirm

**Cancelling a Pending Order** (4-step flow from User Guide p.24)

1. My Holdings → My transactions
2. Select pending order
3. Tap "Cancel order"
4. Review details → Confirm

### 1.4 Business Rules

| Rule                                  | Specification                                                        |
| ------------------------------------- | -------------------------------------------------------------------- |
| Minimum investment — individual fund  | 100 HKD                                                              |
| Minimum investment — custom portfolio | 500 HKD (total across all selected funds)                            |
| Build Portfolio access                | Risk level 4 (Adventurous) or 5 (Speculative) only                   |
| Portfolio allocation                  | Sum of all fund percentages must equal exactly 100%                  |
| Last fund amount calculation          | Total amount − sum of amounts allocated to all other funds           |
| Weekend / holiday orders              | Processed on the next business day                                   |
| Monthly plan debit day                | If falls on weekend/holiday, deferred to next business day           |
| Transaction history (in-app)          | 90 days                                                              |
| Transaction history (eStatement)      | 24 months                                                            |
| Risk level labels                     | 1=Conservative, 2=Moderate, 3=Balanced, 4=Adventurous, 5=Speculative |
| Order reference format — one-time     | `P-XXXXXX` (P + 6 digits)                                            |
| Order reference format — monthly plan | `YYYYMMDDHHmmssXXX` (timestamp + 3-digit suffix)                     |

---

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
| `portfolio`             | Holdings calculation, unrealised P&L, total market value     | `/api/portfolio/**`                             |
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
# ── Java 25 via SDKMAN ──────────────────────────────────────────────────
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 25-open
sdk use java 25-open
java --version   # must show: openjdk 25

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

```yaml
# docker-compose.yml (repository root)
# Kompose can be used to convert docker-compose.yml into a K8s configuration file.

version: '3.9'
services:

  postgres:
    image: postgres:16-alpine
    container_name: smart-invest-db
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: smartinvest
      POSTGRES_USER: smartadmin
      POSTGRES_PASSWORD: localdev_only
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U smartadmin -d smartinvest"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: smart-invest-app
    ports:
      - "8080:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/smartinvest
      SPRING_DATASOURCE_USERNAME: smartadmin
      SPRING_DATASOURCE_PASSWORD: localdev_only
      JWT_SECRET: local-dev-secret-key-minimum-256-bits-long
      APP_ENV: local
    depends_on:
      postgres:
        condition: service_healthy

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    container_name: smart-invest-frontend
    ports:
      - "3000:3000"
    volumes:
      - ./frontend/src:/app/src   # hot reload
    environment:
      VITE_API_BASE_URL: http://localhost:8080

volumes:
  postgres_data:
```

---

## 5. Database Design

### 5.1 Schema Overview

All tables reside in a single PostgreSQL 16 database (`smartinvest`). Schema migrations are managed by **Flyway**, versioned incrementally.

### 5.2 Migration Files

```
backend/src/main/resources/db/migration/
├── V1__create_users.sql
├── V2__create_risk_assessments.sql
├── V3__create_funds.sql
├── V4__create_fund_nav_history.sql
├── V5__create_fund_asset_allocations.sql
├── V6__create_fund_top_holdings.sql
├── V7__create_fund_geo_allocations.sql
├── V8__create_fund_sector_allocations.sql
├── V9__create_reference_asset_mix.sql
├── V10__create_orders.sql
├── V11__create_investment_plans.sql
├── V12__create_holdings.sql
└── V13__seed_funds.sql
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
├── module-order/                        (Order placement, cancellation)
├── module-portfolio/                    (Holdings, P&L calculation)
├── module-plan/                         (Monthly investment plans)
├── module-scheduler/                    (Cron jobs)
└── module-notification/                 (SES email dispatch)
```

### 6.2 Root POM

```xml
<!-- backend/pom.xml -->
<project>
  <groupId>com.smartinvest</groupId>
  <artifactId>smart-invest-parent</artifactId>
  <version>1.0.0</version>
  <packaging>pom</packaging>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.2</version>
  </parent>

  <properties>
    <java.version>25</java.version>
    <mapstruct.version>1.6.0</mapstruct.version>
  </properties>

  <modules>
    <module>module-user</module>
    <module>module-fund</module>
    <module>module-order</module>
    <module>module-portfolio</module>
    <module>module-plan</module>
    <module>module-scheduler</module>
    <module>module-notification</module>
    <module>app</module>
  </modules>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-security</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
      <groupId>org.flywaydb</groupId>
      <artifactId>flyway-database-postgresql</artifactId>
    </dependency>
    <dependency>
      <groupId>org.postgresql</groupId>
      <artifactId>postgresql</artifactId>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>io.jsonwebtoken</groupId>
      <artifactId>jjwt-api</artifactId>
      <version>0.12.6</version>
    </dependency>
    <dependency>
      <groupId>io.jsonwebtoken</groupId>
      <artifactId>jjwt-impl</artifactId>
      <version>0.12.6</version>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <optional>true</optional>
    </dependency>
    <dependency>
      <groupId>org.mapstruct</groupId>
      <artifactId>mapstruct</artifactId>
      <version>${mapstruct.version}</version>
    </dependency>
    <dependency>
      <groupId>org.springdoc</groupId>
      <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
      <version>2.6.0</version>
    </dependency>
    <dependency>
      <groupId>io.micrometer</groupId>
      <artifactId>micrometer-registry-cloudwatch2</artifactId>
    </dependency>
    <dependency>
      <groupId>software.amazon.awssdk</groupId>
      <artifactId>ses</artifactId>
      <version>2.26.0</version>
    </dependency>
    <dependency>
      <groupId>software.amazon.awssdk</groupId>
      <artifactId>secretsmanager</artifactId>
      <version>2.26.0</version>
    </dependency>
  </dependencies>
</project>
```

### 6.3 Application Configuration

```yaml
# app/src/main/resources/application.yml
spring:
  application:
    name: smart-invest
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
      connection-timeout: 30000
  jpa:
    hibernate:
      ddl-auto: validate   # Flyway manages schema; Hibernate validates only
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        jdbc:
          time_zone: UTC
  flyway:
    enabled: true
    locations: classpath:db/migration

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    health:
      show-details: when-authorized

jwt:
  secret: ${JWT_SECRET}
  access-token-expiry-ms: 3600000      # 1 hour
  refresh-token-expiry-ms: 604800000   # 7 days

aws:
  region: ${AWS_REGION:us-east-1}
  ses:
    sender-email: noreply@yourdomain.com

logging:
  pattern:
    console: '{"timestamp":"%d{ISO8601}","level":"%p","service":"smart-invest","traceId":"%X{traceId}","message":"%m"}%n'
  level:
    com.smartinvest: INFO
    org.springframework.security: WARN
```

### 6.4 module-user: API Reference

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

### 6.7 module-portfolio: API Reference

```
GET    /api/portfolio/me              Holdings summary (total market value, total P&L, holdings list)
GET    /api/portfolio/me/holdings     Individual holding details with unrealised gain/loss
```

### 6.8 module-plan: API Reference

```
POST   /api/plans                     Create monthly investment plan
GET    /api/plans                     List active plans for current user
GET    /api/plans/{id}                Plan detail (next contribution date, completed orders, total invested)
DELETE /api/plans/{id}                Terminate plan (stops future contributions; does not sell holdings)
```

### 6.9 module-scheduler

```java
@Component
@Slf4j
@RequiredArgsConstructor
public class MonthlyInvestmentScheduler {

    private final InvestmentPlanService planService;
    private final OrderService orderService;

    // Execute monthly plans — runs daily at 01:00 HKT
    @Scheduled(cron = "0 0 1 * * *", zone = "Asia/Hong_Kong")
    public void executeMonthlyPlans() {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Hong_Kong"));

        // Skip weekends
        if (today.getDayOfWeek() == SATURDAY || today.getDayOfWeek() == SUNDAY) {
            return;
        }

        List<InvestmentPlan> duePlans = planService.findPlansDueOn(today);
        log.info("Monthly plan execution: {} plans due on {}", duePlans.size(), today);

        for (InvestmentPlan plan : duePlans) {
            try {
                orderService.executePlan(plan);
            } catch (Exception e) {
                log.error("Plan execution failed: planId={}, error={}",
                    plan.getId(), e.getMessage(), e);
            }
        }
    }

    // Simulate NAV updates — runs weekdays at 15:00 HKT
    @Scheduled(cron = "0 0 15 * * MON-FRI", zone = "Asia/Hong_Kong")
    public void simulateNavUpdate() {
        log.info("NAV simulation update triggered");
        // Apply small random delta to each fund NAV (±0.5%) for demo realism
    }
}
```

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

```tsx
// src/components/RiskGauge.tsx
interface Props {
  productRiskLevel: number;  // orange ▼ above bar
  userRiskLevel: number;     // green  ▲ below bar
}

const SEGMENT_COLORS = ['#9CA3AF','#1E3A5F','#3B82F6','#EAB308','#F97316','#EF4444'];

export const RiskGauge: React.FC<Props> = ({ productRiskLevel, userRiskLevel }) => (
  <div className="w-full">
    <div className="flex gap-0.5 relative mb-6">
      {SEGMENT_COLORS.map((color, i) => (
        <div key={i} className="flex-1 h-5 rounded-sm relative" style={{ backgroundColor: color }}>
          {i === productRiskLevel && (
            <span className="absolute -top-5 left-1/2 -translate-x-1/2 text-xs">▼</span>
          )}
          {i === userRiskLevel && (
            <span className="absolute -bottom-5 left-1/2 -translate-x-1/2 text-xs text-green-600">▲</span>
          )}
        </div>
      ))}
    </div>
    <div className="flex justify-between text-xs text-gray-500 mt-4">
      <span>Product risk level</span>
      <span>Your risk tolerance</span>
    </div>
    <p className={`text-sm mt-3 flex items-center gap-1 ${productRiskLevel <= userRiskLevel ? 'text-green-600' : 'text-amber-600'}`}>
      {productRiskLevel <= userRiskLevel
        ? '✓ This fund is within your risk tolerance level.'
        : '⚠ This fund exceeds your risk tolerance level.'}
    </p>
  </div>
);
```

**NavChart** — 3M/6M/1Y/3Y/5Y toggle (User Guide p.7, p.12):

```tsx
// src/components/NavChart.tsx
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { useQuery } from '@tanstack/react-query';

const PERIODS = ['3M', '6M', '1Y', '3Y', '5Y'];

export const NavChart: React.FC<{ fundId: string; chartLabel: string }> = ({ fundId, chartLabel }) => {
  const [period, setPeriod] = useState('3M');
  const { data = [] } = useQuery({
    queryKey: ['nav-history', fundId, period],
    queryFn: () => fundApi.getNavHistory(fundId, period),
  });

  const chartData = useMemo(() => {
    if (!data.length) return [];
    const base = data[0].nav;
    return data.map(d => ({
      date: d.navDate,
      pct: +((( d.nav - base) / base) * 100).toFixed(2),
    }));
  }, [data]);

  return (
    <div className="w-full">
      <p className="text-xs text-gray-500 mb-2">{chartLabel}</p>
      <div className="flex gap-4 mb-3">
        {PERIODS.map(p => (
          <button key={p} onClick={() => setPeriod(p)}
            className={`text-sm font-medium pb-1 ${period === p
              ? 'text-red-600 border-b-2 border-red-600'
              : 'text-gray-400'}`}>
            {p}
          </button>
        ))}
      </div>
      <ResponsiveContainer width="100%" height={180}>
        <LineChart data={chartData}>
          <XAxis dataKey="date" tick={{ fontSize: 10 }} tickLine={false} />
          <YAxis tick={{ fontSize: 10 }} tickFormatter={v => `${v}%`} width={45} />
          <Tooltip formatter={v => [`${v}%`, 'Return']} />
          <Line type="monotone" dataKey="pct" stroke="#3B82F6" dot={false} strokeWidth={1.5} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
};
```

**AllocationForm** — percentage inputs must total exactly 100% (User Guide p.18):

```tsx
// src/components/AllocationForm.tsx
export const AllocationForm: React.FC = () => {
  const { selectedFunds, setAllocations } = usePortfolioStore();
  const [pcts, setPcts] = useState<Record<string, number>>(
    Object.fromEntries(selectedFunds.map(f => [f.id, 0]))
  );

  const total = Object.values(pcts).reduce((s, v) => s + v, 0);
  const valid = Math.abs(total - 100) < 0.01;

  return (
    <div className="px-4">
      {selectedFunds.map(fund => (
        <div key={fund.id} className="py-3 border-b">
          <p className="text-sm font-medium">{fund.name}</p>
          <p className="text-xs text-gray-500 mb-2">Risk level {fund.riskLevel}</p>
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-600">Fund allocation</span>
            <div className="flex items-center gap-1">
              <input type="number" min={0} max={100}
                value={pcts[fund.id] || ''}
                onChange={e => setPcts(p => ({ ...p, [fund.id]: +e.target.value }))}
                className="w-14 text-right border rounded px-2 py-1 text-sm" />
              <span className="text-sm">%</span>
            </div>
          </div>
        </div>
      ))}
      <p className={`text-right mt-3 font-medium text-sm ${valid ? 'text-green-600' : 'text-gray-400'}`}>
        {total}% of 100% allocated
      </p>
      <button disabled={!valid} onClick={() => setAllocations(pcts)}
        className={`w-full mt-4 py-3 rounded-lg font-semibold text-sm transition-colors ${
          valid ? 'bg-red-600 text-white active:bg-red-700'
                : 'bg-gray-100 text-gray-400 cursor-not-allowed'}`}>
        Continue
      </button>
    </div>
  );
};
```

### 7.5 Mobile-First CSS Configuration

```js
// tailwind.config.js
export default {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        'si-red':    '#DB0011',   // Smart Invest primary action
        'si-dark':   '#1A1A1A',
        'si-gray':   '#6B7280',
        'si-light':  '#F5F5F5',
        'si-border': '#E5E7EB',
      },
      fontFamily: {
        sans: ['"Univers Next"', '"Helvetica Neue"', 'sans-serif'],
      },
      screens: {
        // Only mobile breakpoints
        'sm': '390px',
        'md': '430px',
      },
    },
  },
};
```

```html
<!-- index.html — enforce mobile viewport -->
<meta name="viewport" content="width=device-width, initial-scale=1.0,
      maximum-scale=1.0, user-scalable=no" />
```

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

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "smart-invest-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "smart-invest-public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  tags = { Name = "smart-invest-private-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "smart-invest-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group — EC2
resource "aws_security_group" "ec2" {
  name   = "smart-invest-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]   # restrict to your IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group — RDS (only reachable from EC2)
resource "aws_security_group" "rds" {
  name   = "smart-invest-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
}
```

### 8.3 EC2 Module

```hcl
# modules/ec2/main.tf
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.small"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.ec2_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user_data.sh", {
    db_secret_arn = var.db_secret_arn
    aws_region    = var.region
    app_jar_s3    = var.app_jar_s3_path
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = { Name = "smart-invest-app-server" }
}

# Elastic IP for stable address
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = { Name = "smart-invest-eip" }
}
```

```bash
# modules/ec2/user_data.sh
#!/bin/bash
set -e

# Install dependencies
yum update -y
yum install -y java-21-amazon-corretto-headless nginx

# Download application JAR from S3
aws s3 cp ${app_jar_s3} /opt/smart-invest/app.jar

# Retrieve database credentials from Secrets Manager
DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id ${db_secret_arn} \
  --region ${aws_region} \
  --query SecretString --output text)

DB_URL=$(echo $DB_SECRET | python3 -c "import json,sys; s=json.load(sys.stdin); print(f\"jdbc:postgresql://{s['host']}:{s['port']}/{s['dbname']}\")")
DB_USER=$(echo $DB_SECRET | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['username'])")
DB_PASS=$(echo $DB_SECRET | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['password'])")

# Create systemd service
cat > /etc/systemd/system/smart-invest.service <<EOF
[Unit]
Description=Smart Invest Application
After=network.target

[Service]
Type=simple
User=ec2-user
Environment="SPRING_DATASOURCE_URL=$DB_URL"
Environment="SPRING_DATASOURCE_USERNAME=$DB_USER"
Environment="SPRING_DATASOURCE_PASSWORD=$DB_PASS"
Environment="AWS_REGION=${aws_region}"
Environment="SPRING_PROFILES_ACTIVE=prod"
ExecStart=/usr/bin/java -Xms256m -Xmx768m -jar /opt/smart-invest/app.jar
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx as reverse proxy with HTTPS
cat > /etc/nginx/conf.d/smart-invest.conf <<'EOF'
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # API requests → Spring Boot
    location /api/ {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF

systemctl daemon-reload
systemctl enable smart-invest
systemctl start smart-invest
systemctl enable nginx
systemctl start nginx
```

### 8.4 RDS Module

```hcl
# modules/rds/main.tf
resource "aws_db_subnet_group" "main" {
  name       = "smart-invest-db-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier           = "smart-invest-db"
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "smartinvest"
  username             = "smartadmin"
  manage_master_user_password = true   # credentials in Secrets Manager

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  multi_az               = false
  publicly_accessible    = false
  deletion_protection    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "smart-invest-db-final-snapshot"

  tags = { Name = "smart-invest-postgres" }
}
```

### 8.5 S3 + CloudFront Module

```hcl
# modules/s3-cloudfront/main.tf
resource "aws_s3_bucket" "frontend" {
  bucket = "smart-invest-frontend-${var.account_id}"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "smart-invest-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"   # US/Europe/Asia — lowest cost

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-smart-invest-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-smart-invest-frontend"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # SPA fallback — all 404s → index.html (React Router handles routing)
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

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

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main, develop]

jobs:
  backend:
    name: Backend Build & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java 25
        uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build and Test
        run: mvn -B clean verify --file backend/pom.xml

      - name: Upload test reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: surefire-reports
          path: backend/**/target/surefire-reports/

  frontend:
    name: Frontend Build & Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        working-directory: frontend
        run: npm ci

      - name: Type check
        working-directory: frontend
        run: npm run type-check

      - name: Lint
        working-directory: frontend
        run: npm run lint

      - name: Build
        working-directory: frontend
        run: npm run build

  terraform-validate:
    name: Terraform Validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.x
      - run: terraform -chdir=infrastructure init -backend=false
      - run: terraform -chdir=infrastructure validate
```

### 9.2 CD — Deploy on Merge to Main

```yaml
# .github/workflows/cd.yml
name: CD

on:
  push:
    branches: [main]

env:
  AWS_REGION: us-east-1

jobs:
  deploy-backend:
    name: Deploy Backend to EC2
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java 25
        uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build JAR
        run: mvn -B clean package -DskipTests --file backend/pom.xml

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ env.AWS_REGION }}

      - name: Upload JAR to S3
        run: |
          aws s3 cp backend/app/target/smart-invest-app.jar \
            s3://${{ secrets.ARTIFACT_BUCKET }}/smart-invest-app-${{ github.sha }}.jar
          # Also update the "latest" pointer
          aws s3 cp backend/app/target/smart-invest-app.jar \
            s3://${{ secrets.ARTIFACT_BUCKET }}/smart-invest-app.jar

      - name: Deploy to EC2 via SSM
        run: |
          aws ssm send-command \
            --instance-ids ${{ secrets.EC2_INSTANCE_ID }} \
            --document-name "AWS-RunShellScript" \
            --parameters '{
              "commands": [
                "aws s3 cp s3://${{ secrets.ARTIFACT_BUCKET }}/smart-invest-app.jar /opt/smart-invest/app.jar",
                "sudo systemctl restart smart-invest",
                "sleep 15",
                "sudo systemctl is-active smart-invest"
              ]
            }' \
            --output text

  deploy-frontend:
    name: Deploy Frontend to S3 + CloudFront
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Build
        working-directory: frontend
        env:
          VITE_API_BASE_URL: ${{ secrets.API_BASE_URL }}
        run: |
          npm ci
          npm run build

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ env.AWS_REGION }}

      - name: Sync to S3
        working-directory: frontend
        run: |
          aws s3 sync dist/ s3://${{ secrets.FRONTEND_BUCKET }}/ \
            --delete \
            --cache-control "public, max-age=31536000, immutable"
          aws s3 cp dist/index.html s3://${{ secrets.FRONTEND_BUCKET }}/index.html \
            --cache-control "no-cache"

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CF_DISTRIBUTION_ID }} \
            --paths "/*"
```

---

## 10. Deployment Guide

### 10.1 First-Time Deployment Checklist

```
Pre-requisites:
  ☐ AWS account with $200 credits activated
  ☐ IAM user created with AdministratorAccess (for initial setup only)
  ☐ AWS CLI configured (aws configure)
  ☐ Terraform ≥ 1.9 installed
  ☐ Java 25 + Maven installed
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
| 5    | `module-portfolio`: holdings calculation, unrealised P&L, total market value                 | ✓ Holdings view                 |
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
│   ├── pom.xml                      Root Maven POM (Java 25)
│   ├── app/                         Spring Boot launcher
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

*Document maintained as part of the `smart-invest` repository. All infrastructure and application code is version-controlled. Refer to individual module READMEs for implementation details.*
