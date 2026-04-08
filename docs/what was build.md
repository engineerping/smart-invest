# Smart Invest — What Was Built

---

## 1. Project Overview

Smart Invest is an investment platform built with **Java 21 + Spring Boot 3.3** on the backend and **React 18 + TypeScript + Vite** on the frontend. o keep costs within $200, the project prototype adopts a multi-module Maven monolithic architecture on the server side, which will be upgraded to a micro-service architecture in actual development. Flyway for database migrations, The front-end uses Tailwind CSS to design the mobile UI, and JWT (RS256) for authentication.

**Tech Stack:**

- Backend: Java 21, Spring Boot 3.3, JPA/Hibernate, PostgreSQL 16, Flyway, JWT (RS256)
- Frontend: React 18, TypeScript, Vite, Tailwind CSS, React Router 6, TanStack Query
- Database: PostgreSQL 16 (Docker)
- Auth: JWT RS256 asymmetric signing

---

## 2. Backend Module Structure

8 Maven modules:

| Module                | Purpose                                              |
| --------------------- | ---------------------------------------------------- |
| `module-user`         | User management, authentication, risk assessment     |
| `module-fund`         | Fund data, NAV history, holding information          |
| `module-order`        | Order management (T+2 settlement)                    |
| `module-portfolio`    | User portfolio valuation                             |
| `module-plan`         | Recurring investment plans                           |
| `module-scheduler`    | Scheduled jobs (monthly plan execution)              |
| `module-notification` | Notification service                                 |
| `app`                 | Spring Boot main application, aggregates all modules |

---

## 3. Database Schema (17 Flyway Migrations)

### Users & Auth

- `V1` — Users table (`users`), phone/email registration, salted password hashing
- `V2` — Risk assessments table (`risk_assessments`), stores user risk tolerance levels

### Fund Core

- `V3` — Funds table (`funds`), name, code, risk level, management fee, min investment
- `V4` — Fund NAV history table (`fund_nav_history`), daily NAV records

### Fund Analytics

- `V5` — Asset allocations table (`fund_asset_allocations`), by asset class (equity/bond/cash)
- `V6` — Top holdings table (`fund_top_holdings`), top 10 holdings per fund with weights
- `V7` — Geographic allocations table (`fund_geo_allocations`), by region (N. America/Europe/Asia)
- `V8` — Sector allocations table (`fund_sector_allocations`), by GICS industry

### Investment

- `V9` — Reference asset mix table (`reference_asset_mix`), target allocations by risk level
- `V10` — Orders table (`orders`), subscriptions/redemptions, T+2 settlement auto-calculated
- `V11` — Investment plans table (`investment_plans`), monthly recurring plans
- `V12` — Holdings table (`holdings`), real-time position summaries

### Seed Data

- `V13` — 11 funds (SI-MM-01 money market, SI-BI-01/02 bond indices, SI-EI-01/02/03 equity indices, SI-MA-01~05 multi-asset portfolios)
- `V14` — Demo user (demo@smartinvest.com / Demo1234!) + initial holdings
- `V15` — Backfill `funds.current_nav` from latest NAV history
- `V16` — Full NAV history 2025-01-02 to 2026-04-07 (~329 trading days × 11 funds ≈ 3,619 rows)
- `V17` — Fund asset/sector/geo allocations + top 10 holdings data

---

## 4. API Endpoints

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

 

```bash
cd frontend
npm run dev
# http://localhost:5173
# Demo: demo@smartinvest.com / Demo1234!
```
