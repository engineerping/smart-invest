# Smart Invest

A production-grade mobile investment platform built on AWS, Spring Boot, and React.

## Live Demo

**Frontend:** https://your-cloudfront-distribution.cloudfront.net
**API:** https://api.yourdomain.com (or EC2 IP)

## Features

- **Individual Fund Investment** — Money Market, Bond Index, Equity Index funds
- **Multi-Asset Portfolios** — 5 risk levels (Conservative to Speculative)
- **Build Your Own Portfolio** — Custom fund allocation (Risk Level 4–5 only)
- **Monthly Investment Plans** — Automated recurring investments
- **Order Management** — Place, track, and cancel orders
- **Risk Profiling** — 6-question risk assessment

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18 + TypeScript + Vite + Tailwind CSS |
| Backend | Java 21 + Spring Boot 3.3 + JPA/Hibernate |
| Database | PostgreSQL 16 (RDS db.t3.micro) |
| Infrastructure | Terraform 1.9 + AWS EC2 + S3 + CloudFront |
| CI/CD | GitHub Actions |
| Monitoring | Amazon CloudWatch |

## Architecture

```
Internet → CloudFront (S3 SPA) / HTTPS → EC2 (Spring Boot :8080) → RDS PostgreSQL
```

See `docs/superpowers/plans/` for the full implementation plan.

## Getting Started

### Prerequisites
- Java 21, Maven 3.9+
- Node.js 20, npm
- Docker (for local PostgreSQL)
- AWS CLI configured

### run locally

```bash
# === PostgreSQL (Docker) ===
docker compose up -d postgres;      # Start
docker compose down;                # Stop

# === Backend ===
# Start: (http://localhost:8080)
cd backend && mvn install -DskipTests && cd app && mvn spring-boot:run -Dspring-boot.run.profiles=local 2>&1 | tail -40;

# Note: `mvn install` is needed first because the multi-module project requires sub-modules (domain, infrastructure, etc.)
# to be installed into the local Maven repo before `app` can resolve them. `spring-boot:run` is preferred over
# `java -jar` in dev because it skips packaging, supports hot reload, and includes unpackaged resources automatically.

# === Populate data into DB ===
## When starting Spring Boot — Flyway will automatically detect and execute the SQL file in backend/app/src/main/resources/db.

# Stop: kill the Maven process， or Ctrl+C
kill $(lsof -ti :8080) && echo "Backend server stopped"

# === Frontend ===
cd frontend; npm run dev;              # Start (http://localhost:5173)
lsof -ti:5173 | xargs kill;            # Stop

# === Use ===
# 1. Login with demo account 
demo@smartinvest.com
password:Demo1234!

```

### Deploy to AWS

```bash
cd infrastructure;
terraform init;
terraform apply -var="admin_cidr=$(curl -s ifconfig.me)/32" \
                -var="key_pair_name=your-key-pair" \
                -var="account_id=$(aws sts get-caller-identity --query Account --output text)";

# Deploy
./scripts/deploy.sh;

# 3. Verify
curl https://<ec2-ip>/actuator/health;

# 4. GitHub Secrets needed:
AWS_ACCESS_KEY_ID, 
AWS_SECRET_ACCESS_KEY, 
EC2_INSTANCE_ID, 
ARTIFACT_BUCKET, 
FRONTEND_BUCKET, 
CF_DISTRIBUTION_ID, 
API_BASE_URL
```
# Variable Descriptions
| Variable | Description |
| --- | --- |
| AWS_ACCESS_KEY_ID | AWS API access key ID |
| AWS_SECRET_ACCESS_KEY | AWS API access key |
| EC2_INSTANCE_ID | Your EC2 instance ID for SSH deployment of JAR files |
| ARTIFACT_BUCKET | Name of the S3 bucket storing backend JAR files |
| FRONTEND_BUCKET | Name of the S3 bucket storing frontend build artifacts |
| CF_DISTRIBUTION_ID | CloudFront distribution ID for cache refresh after deployment |
| API_BASE_URL | Backend API address used by frontend calls |


## Repository Structure

```
backend/           Spring Boot application (modular monolith)
frontend/          React TypeScript SPA
infrastructure/    Terraform IaC (VPC, EC2, RDS, S3, CloudFront)
.github/workflows/ CI/CD pipelines
scripts/           Deployment and utility scripts
```
# What Was Built

## Backend (48 Java files)
| Module | Description |
|--------|-------------|
| module-user | JWT auth (RS256), registration/login, BCrypt passwords, 6-question risk questionnaire with 5-level scoring |
| module-fund | Fund catalogue API with filtering, NAV history (3M–5Y), asset allocation, multi-asset endpoint |
| module-order | Order placement, T+2 settlement date calculator (skips weekends), order reference generation (P-XXXXXX / timestamp format), cancellation |
| module-portfolio | Holdings query API |
| module-plan | Monthly investment plan CRUD + termination |
| module-scheduler | @Scheduled cron — daily 01:00 HKT plan execution, weekday 15:00 NAV simulation |
| module-notification | SES email stub (logs in dev) |
| app | Flyway 13 migrations, 11 seed funds, JWT config, AWS config profiles |

## Frontend (16 TypeScript files)
- Auth: Login, Register pages
- Home: SmartInvestHomePage with fund category cards
- Funds: FundListPage (filter by type), FundDetailPage with NavChart + RiskGauge
- Order: 4-step flow — Setup → Review → Terms → Success
- Holdings: MyHoldingsPage, MyTransactionsPage
- Components: PageLayout, RiskGauge, NavChart

## Infrastructure (19 Terraform files)
- VPC (public/private subnets, security groups)
- IAM (EC2 role with SecretsManager, SES, CloudWatch policies)
- EC2 (t3.small, systemd service, Nginx reverse proxy, user_data.sh)
- RDS (PostgreSQL 16 db.t3.micro, automated backups)
- S3+CloudFront (OAC, SPA 404 fallback, CloudFront cert)

## CI/CD
- `.github/workflows/ci.yml` — Maven + npm + Terraform validate on PR
- `.github/workflows/cd.yml` — JAR upload → SSM deploy, frontend sync → CloudFront invalidation

## Scripts
- `scripts/deploy.sh` — full deploy pipeline
- `scripts/seed-nav-history.py` — populate 5 years of NAV data
- `scripts/create-demo-user.sh` — demo account + order
- `scripts/cloudwatch-setup.sh` — CPU and RDS storage alarms

