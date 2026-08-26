# Smart Invest

A production-grade mobile investment platform built with Spring Boot microservices and React, deployed on AWS with **Terraform (IaC) + Kubernetes (K3S) + Helm**.

## Live Demo

- **Frontend (CloudFront):** `https://d2hoqnqufe8qq0.cloudfront.net` (see `infrastructure/terraform/live/prod/outputs.tf`)
- **API:** same distribution, `/api/*` → api-gateway

## Features

- **Individual Fund Investment** — Money Market, Bond Index, Equity Index funds
- **Multi-Asset Portfolios** — 5 risk levels (Conservative to Speculative)
- **Build Your Own Portfolio** — Custom fund allocation (Risk Level 4–5 only)
- **Monthly Investment Plans** — Automated recurring investments
- **Order Management** — Place, track, and cancel orders
- **Risk Profiling** — 6-question risk assessment

## Tech Stack

| Layer          | Technology                                                        |
| -------------- | ----------------------------------------------------------------- |
| Frontend       | React 18 + TypeScript + Vite + Tailwind CSS                       |
| Backend        | Java 21 + Spring Boot 3.3 microservices + Spring Cloud Gateway    |
| Database       | PostgreSQL 16 (K3S StatefulSet + PVC)                             |
| Message Queue  | RabbitMQ (K3S Deployment + PVC)                                   |
| Cache          | Redis (K3S Deployment + PVC, default disabled)                    |
| Orchestration  | Kubernetes (K3S single node) + Helm umbrella chart                |
| Infrastructure | Terraform + AWS EC2 (t3.medium) + S3 + CloudFront + WAF           |
| CI/CD          | GitHub Actions (`cd-k3s.yml`, manual `workflow_dispatch`)         |
| Monitoring     | Amazon CloudWatch                                                 |

## Architecture

```
Internet → CloudFront (S3 SPA) + WAF
              │ /api/*
              ▼
        EC2 (t3.medium) ── K3S single node ── Traefik Ingress
              │
              ├── api-gateway         (Spring Cloud Gateway, :8080)
              ├── user-service        (:8081, owns Flyway migrations)
              ├── fund-service        (:8082)
              ├── order-service       (:8083)
              ├── notification-worker (:8084, RabbitMQ consumer)
              └── postgresql / rabbitmq / redis (in-cluster, PVC-backed)
```

The full deployment record is in `infrastructure/deployment-guide.md` and `infrastructure/README.md`.

## Getting Started

### Prerequisites

- Java 21, Maven 3.9+
- Node.js 20, npm
- Docker (for local PostgreSQL / RabbitMQ)

### Run locally

```bash
# === PostgreSQL (Docker) ===
docker run -d --name smart-invest-db \
  --restart unless-stopped -p 5432:5432 \
  -e POSTGRES_DB=smartinvest -e POSTGRES_USER=smartadmin \
  -e POSTGRES_PASSWORD=localdev_only \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:16-alpine

# === RabbitMQ (order → notification flow) ===
docker run -d --name smart-invest-rabbitmq \
  -p 5672:5672 -p 15672:15672 rabbitmq:3.13-management-alpine

# === Backend (6 Maven modules) ===
# Build all modules first, then start each service (entry point is api-gateway :8080)
cd backend && mvn install -DskipTests
mvn spring-boot:run -pl user-service
mvn spring-boot:run -pl fund-service
mvn spring-boot:run -pl order-service
mvn spring-boot:run -pl notification-worker
mvn spring-boot:run -pl api-gateway

# Note: Flyway runs automatically when user-service starts
# (21 migrations in backend/user-service/src/main/resources/db/migration/).

# === Frontend ===
cd frontend && npm run dev;   # http://localhost:5173

# === Use ===
# 1. Login with demo account
demo@smartinvest.com
password:Demo1234!
```

### Deploy to AWS (IaC + K8S + Helm)

```bash
# 1. Terraform provisions EC2 + S3 + CloudFront + WAF (see infrastructure/deployment-guide.md)
cd infrastructure/terraform/live/prod
cp terraform.tfvars.example terraform.tfvars   # fill in your AWS values
terraform init && terraform apply

# 2. Build images (Mac → Ubuntu x86_64 build machine → k3s ctr import)
#    Full flow: infrastructure/deployment-guide.md

# 3. Helm deploy all services
cd infrastructure/helm/umbrella
helm dependency update
helm upgrade --install smart-invest . --namespace smart-invest --create-namespace \
  --atomic --timeout 600s

# 4. GitHub Actions secrets for cd-k3s.yml (manual workflow_dispatch):
DOCKER_USERNAME, DOCKER_PASSWORD, ASUS_SERVER, ASUS_SSH_PASSWORD
```

## Repository Structure

```
backend/           Spring Boot microservices (common + 5 services + api-gateway)
frontend/          React TypeScript SPA
infrastructure/    Terraform IaC (VPC, EC2, S3, CloudFront, WAF) + Helm charts
.github/workflows/ CI/CD (cd-k3s.yml)
scripts/           Build and deployment scripts (build-images, deploy-k3s, setup-db, ...)
```

## What Was Built

### Backend (6 Maven modules)

| Module               | Description                                                                                     |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| `common`             | Shared library — JWT utils, DTOs, common exceptions/config                                       |
| `user-service`       | User management, JWT auth (RS256), risk assessment; owns the database (21 Flyway migrations V1–V21) |
| `fund-service`       | Fund catalogue, NAV history, asset/geo/sector allocation, holdings                               |
| `order-service`      | Order placement, T+2 settlement date, order reference generation (P-XXXXXX), cancellation       |
| `notification-worker`| RabbitMQ consumer, email notifications (SES stub in dev)                                        |
| `api-gateway`        | Spring Cloud Gateway — entry point on :8080, routes `/api/*` to the services above              |

### Frontend (React + TypeScript)

- Auth: Login, Register pages
- Home: fund category cards
- Funds: list (filter by type), detail with NavChart + RiskGauge
- Order: 4-step flow — Setup → Review → Terms → Success
- Holdings: MyHoldingsPage, MyTransactionsPage
- Components: PageLayout, RiskGauge, NavChart

### Infrastructure (Terraform + Helm)

- Terraform modules: networking (VPC/subnets/SG), compute (EC2 t3.medium), iam, cdn (S3 + CloudFront + WAF)
- Helm: 9 sub-charts (5 microservices + frontend + postgresql + rabbitmq + redis) + umbrella chart
- K3S single-node cluster on EC2 (ap-southeast-1), Traefik ingress, local-path-provisioner

### CI/CD

- `.github/workflows/cd-k3s.yml` — manual `workflow_dispatch`: build jars + frontend, push Docker images, SSH to build machine, `helm upgrade --install smart-invest`
