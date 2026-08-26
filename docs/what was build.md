# Smart Invest — What Was Built

---

## 1. Project Overview

Smart Invest is an investment platform built with **Java 21 + Spring Boot 3.3** on the backend and **React 18 + TypeScript + Vite** on the frontend. The backend has evolved from a multi-module Maven monolith into a micro-service architecture, deployed on AWS with **Terraform (IaC) + Kubernetes (K3S) + Helm**. Flyway manages database migrations, the front-end uses Tailwind CSS to design the mobile UI, and JWT (RS256) handles authentication.

**Tech Stack:**

- Backend: Java 21, Spring Boot 3.3 microservices, Spring Cloud Gateway, JPA/Hibernate, Flyway, JWT (RS256)
- Frontend: React 18, TypeScript, Vite, Tailwind CSS, React Router 6, TanStack Query
- Database: PostgreSQL 16 (K3S StatefulSet + PVC)
- Messaging: RabbitMQ · Cache: Redis
- Orchestration: Kubernetes (K3S) + Helm · IaC: Terraform
- Auth: JWT RS256 asymmetric signing

---

## 2. Backend Module Structure

6 Maven modules:

| Module                 | Purpose                                                       |
| ---------------------- | ------------------------------------------------------------- |
| `common`               | Shared library — JWT utils, DTOs, common exceptions/config    |
| `user-service`         | User management, authentication, risk assessment; owns the DB |
| `fund-service`         | Fund data, NAV history, asset allocation, holdings            |
| `order-service`        | Order management (T+2 settlement)                             |
| `notification-worker`  | RabbitMQ consumer, email notifications                        |
| `api-gateway`          | Spring Cloud Gateway — entry point on :8080                    |

---

## 3. Database Schema (21 Flyway Migrations, V1–V21)

All migrations live in `backend/user-service/src/main/resources/db/migration/` (user-service owns the database).

### Schema (V1–V13)

- `V1` — `users` table
- `V2` — `risk_assessments` table
- `V3` — `funds` table
- `V4` — `fund_nav_history` table (daily NAV records)
- `V5` — `fund_asset_allocations` table (by asset class: equity/bond/cash)
- `V6` — `fund_top_holdings` table (top 10 holdings per fund)
- `V7` — `fund_geo_allocations` table (by region)
- `V8` — `fund_sector_allocations` table (by GICS industry)
- `V9` — `reference_asset_mix` table (target allocations by risk level)
- `V10` — `user_portfolios` table
- `V11` — `orders` table (subscriptions/redemptions, T+2 settlement auto-calculated)
- `V12` — `investment_plans` table (monthly recurring plans)
- `V13` — `holdings` table (position summaries)

### Seed Data (V14–V20)

- `V14` — 11 funds (SI-MM-01 money market, SI-BI-01/02 bond indices, SI-EI-01/02/03 equity indices, SI-MA-01~05 multi-asset portfolios)
- `V15` — Demo user (demo@smartinvest.com / Demo1234!) + initial demo data
- `V16` — Seed NAV + demo data
- `V17` — Full NAV history 2025-01-02 to 2026-04-07 (~329 trading days × 11 funds ≈ 3,619 rows)
- `V18` — Fund asset/sector/geo allocations + top 10 holdings data
- `V19` — Demo orders
- `V20` — Demo investment plans

### Schema (V21)

- `V21` — `notifications` table

---

## 4. API Endpoints

> All requests enter through `api-gateway` (:8080), which routes `/api/*` to the service that owns it.

### Auth (`/api/auth`)

| Method | Path                 | Description        |
| ------ | -------------------- | ------------------ |
| POST   | `/api/auth/login`    | Login, returns JWT |
| POST   | `/api/auth/register` | Register new user  |

### Users (`/api/users`)

| Method | Path                    | Description          |
| ------ | ----------------------- | -------------------- |
| GET    | `/api/users/me`         | Current user profile |
| GET    | `/api/users/risk-level` | User's risk level    |

### Funds (`/api/funds`)

| Method | Path                                | Description                |
| ------ | ----------------------------------- | -------------------------- |
| GET    | `/api/funds`                        | Fund list with current NAV |
| GET    | `/api/funds/{id}`                   | Fund detail                |
| GET    | `/api/funds/{id}/nav-history`       | NAV history for charts     |
| GET    | `/api/funds/{id}/top-holdings`      | Top 10 holdings            |
| GET    | `/api/funds/{id}/sector-allocation` | Sector allocation          |
| GET    | `/api/funds/{id}/geo-allocation`    | Geographic allocation      |
| GET    | `/api/funds/{id}/asset-allocation`  | Asset class allocation     |

### Orders (`/api/orders`)

| Method | Path             | Description                          |
| ------ | ---------------- | ------------------------------------ |
| POST   | `/api/orders`    | Create subscription/redemption order |
| GET    | `/api/orders/my` | My transaction history               |

### Portfolio (`/api/portfolio`)

| Method | Path                        | Description                  |
| ------ | --------------------------- | ---------------------------- |
| GET    | `/api/portfolio/me`         | All holdings                 |
| GET    | `/api/portfolio/me/summary` | Summary (total market value) |

### Plans (`/api/plans`)

| Method | Path         | Description                   |
| ------ | ------------ | ----------------------------- |
| GET    | `/api/plans` | My investment plans           |
| POST   | `/api/plans` | Create monthly recurring plan |
| DELETE | `/{id}`      | Terminate plan                |

---

## 5. Frontend Pages

```
src/pages/
├── auth/
│   ├── LoginPage.tsx              # Login
│   └── RegisterPage.tsx           # Registration
├── funds/
│   ├── FundListPage.tsx           # Fund list with NAV
│   ├── FundDetailPage.tsx         # Fund detail (Overview/Holdings/Risk tabs)
│   └── MultiAssetFundListPage.tsx  # Multi-asset portfolio list
├── holdings/
│   └── MyHoldingsPage.tsx         # My holdings
├── home/
│   └── SmartInvestHomePage.tsx    # Home page
├── order/
│   └── OrderPage.tsx              # Order placement
├── plans/
│   └── InvestmentPlansPage.tsx    # My investment plans
└── portfolio/
    └── BuildPortfolioPage.tsx     # Custom portfolio (risk level 4-5 only)
```

**Routes:**

- `/` → Home (requires login)
- `/login` → Login page
- `/register` → Registration page
- `/funds` → Fund list
- `/funds/:id` → Fund detail
- `/multi-asset` → Multi-asset portfolios
- `/holdings` → My holdings
- `/plans` → My investment plans
- `/build-portfolio` → Custom portfolio builder
- `/order` → Place order

---

## 6. Seed Data Summary

### 11 Funds

| Code     | Name                                          | Type            | Risk Level |
| -------- | --------------------------------------------- | --------------- | ---------- |
| SI-MM-01 | Smart Invest Global Money Funds - HK Dollar   | Money Market    | 1          |
| SI-BI-01 | Smart Invest Global Aggregate Bond Index Fund | Bond Index      | 2          |
| SI-BI-02 | Smart Invest Global Corporate Bond Index Fund | Corporate Bond  | 3          |
| SI-EI-01 | Smart Invest US Equity Index Fund             | Equity (US)     | 4          |
| SI-EI-02 | Smart Invest Global Equity Index Fund         | Equity (Global) | 4          |
| SI-EI-03 | Smart Invest Hang Seng Index Fund             | Equity (HSI)    | 4          |
| SI-MA-01 | World Selection 1 (Conservative)              | Multi-Asset     | 1          |
| SI-MA-02 | World Selection 2 (Moderately Conservative)   | Multi-Asset     | 2          |
| SI-MA-03 | World Selection 3 (Balanced)                  | Multi-Asset     | 3          |
| SI-MA-04 | World Selection 4 (Adventurous)               | Multi-Asset     | 4          |
| SI-MA-05 | World Selection 5 (Speculative)               | Multi-Asset     | 5          |

### Demo User Holdings

- Smart Invest Global Money Funds: 5,000 units, HKD 50,113.50
- Smart Invest Global Aggregate Bond Index Fund: 3,000 units, HKD 42,407.70
- Smart Invest US Equity Index Fund: 150 units, HKD 4,002.05
- **Total Market Value: HKD 96,523.25**

### Investment Plan

- PLAN-20260115-001: HKD 1,000/month into SI-EI-01, 3 orders completed

---

## 7. Architecture & Deployment

The backend is split into 6 Maven modules (5 services + `common`), each with its own Dockerfile, deployed as containers in a single-node **K3S** cluster on an AWS EC2 `t3.medium` (ap-southeast-1, Singapore).

| Service               | Port | Role                                              |
| --------------------- | ---- | ------------------------------------------------- |
| `api-gateway`         | 8080 | Spring Cloud Gateway, routes `/api/*` to services |
| `user-service`        | 8081 | Auth + users + risk; owns Flyway migrations        |
| `fund-service`        | 8082 | Fund catalogue + NAV history                       |
| `order-service`       | 8083 | Orders + T+2 settlement                            |
| `notification-worker` | 8084 | RabbitMQ consumer, email notifications             |
| `frontend`            | 80   | React SPA (nginx)                                  |

Stateful services run **in-cluster** (no RDS/MQ/ElastiCache): `postgresql` (StatefulSet + PVC), `rabbitmq` (Deployment + PVC), and `redis` (Deployment + PVC, default disabled).

Deployment is fully IaC + Helm:
- **Terraform** (`infrastructure/terraform`) provisions VPC, EC2, S3, CloudFront + WAF.
- **Helm umbrella chart** (`infrastructure/helm/umbrella`) installs all services with `helm upgrade --install smart-invest . --namespace smart-invest`.
- **CI/CD** — single workflow `.github/workflows/cd-k3s.yml` (manual `workflow_dispatch`).
- Images are built as `gongchengship/smart-invest-<service>:1.0.0` (Mac arm64 → Ubuntu x86_64 build machine → `k3s ctr image import`).

See `infrastructure/deployment-guide.md` for the full step-by-step record.

```bash
cd frontend
npm run dev
# http://localhost:5173
# Demo: demo@smartinvest.com / Demo1234!
```
