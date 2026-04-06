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

### Local Development

```bash
# Start PostgreSQL
docker compose up -d postgres

# Run backend
cd backend
mvn spring-boot:run -pl app -am

# Run frontend
cd frontend
npm run dev
```

### Deploy to AWS

```bash
cd infrastructure
terraform init
terraform apply -var="admin_cidr=$(curl -s ifconfig.me)/32" \
                -var="key_pair_name=your-key-pair" \
                -var="account_id=$(aws sts get-caller-identity --query Account --output text)"

# Deploy
./scripts/deploy.sh
```

## Repository Structure

```
backend/           Spring Boot application (modular monolith)
frontend/          React TypeScript SPA
infrastructure/    Terraform IaC (VPC, EC2, RDS, S3, CloudFront)
.github/workflows/ CI/CD pipelines
scripts/           Deployment and utility scripts
```