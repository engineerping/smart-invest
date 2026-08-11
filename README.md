# 🚀 Smart Invest — Full-Stack Investment Platform on AWS + K3S

> **A DevOps Showcase: Terraform-managed AWS infrastructure + Helm-deployed microservices on K3S**

[![Java](https://img.shields.io/badge/Java-21-orange)](https://openjdk.org/projects/jdk/21/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.3-brightgreen)](https://spring.io/projects/spring-boot)
[![React](https://img.shields.io/badge/React-18-61DAFB)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6)](https://www.typescriptlang.org/)
[![K3S](https://img.shields.io/badge/K3S-v1.36-FFC107)](https://k3s.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.9+-844FBA)](https://www.terraform.io/)
[![Helm](https://img.shields.io/badge/Helm-3.x-0F1689)](https://helm.sh/)
[![AWS](https://img.shields.io/badge/AWS-ap--southeast--1-FF9900)](https://aws.amazon.com/)

---

## 📋 Table of Contents

- [Architecture](#-architecture)
- [AWS Services Used](#-aws-services-used)
- [Infrastructure as Code (Terraform)](#-infrastructure-as-code-terraform)
- [Application Deployments (Helm)](#-application-deployments-helm)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Microservices Overview](#-microservices-overview)
- [Deployment Workflow](#-deployment-workflow)
- [Local Development](#-local-development)
- [Demo Credentials](#-demo-credentials)

---

## 🏗 Architecture

Smart Invest is deployed on a **single AWS EC2 instance running K3S** (lightweight Kubernetes), with **CloudFront CDN + S3** serving the frontend globally. All stateful middleware (PostgreSQL, RabbitMQ) runs as K3S workloads — zero dependency on AWS managed services (RDS, Amazon MQ, ElastiCache), keeping costs minimal.

```
                              ┌─────────────────────────────────────────────────────┐
                              │                    AWS Cloud                         │
                              │                                                     │
  🌍 Global Users             │  ┌──────────────────────────────────────────────┐   │
      │                       │  │             CloudFront CDN                    │   │
      ▼                       │  │  ┌─────────────────────────────────────────┐ │   │
┌──────────┐                  │  │  │          WAF (Web ACL)                   │ │   │
│  HTTPS   │                  │  │  │    SQL Injection / XSS / Rate Limit      │ │   │
└────┬─────┘                  │  │  └────────────┬────────────────────────────┘ │   │
     │                        │  │               │                               │   │
     │                        │  └───────────────┼───────────────────────────────┘   │
     │                        │                  │                                   │
     │         ┌──────────────┼──────────────────┼──────────────────┐               │
     │         │              │                  │                  │               │
     │         ▼              │                  ▼                  │               │
     │   ┌──────────┐         │  ┌──────────────────────────────┐  │               │
     │   │   S3     │         │  │      EC2 (t3.medium)         │  │               │
     │   │  Static  │         │  │    ap-southeast-1 (SG)       │  │               │
     │   │  Assets  │         │  │  ┌────────────────────────┐  │  │               │
     │   └──────────┘         │  │  │   K3S (Kubernetes)     │  │  │               │
     │                        │  │  │                        │  │  │               │
     │   /assets/* → S3       │  │  │  ┌──────────────────┐  │  │  │               │
     │   /*        → S3       │  │  │  │ Traefik Ingress  │  │  │  │               │
     │                        │  │  │  │  (K3S built-in)  │  │  │  │               │
     │                        │  │  │  └────────┬─────────┘  │  │  │               │
     │                        │  │  │           │             │  │  │               │
     │                        │  │  │  ┌────────┴─────────┐  │  │  │               │
     │   /api/* ──────────────┼──┼──┼─→│  API Gateway     │  │  │  │               │
     │                        │  │  │  │  (Spring Cloud)  │  │  │  │               │
     │                        │  │  │  │  Port 8080       │  │  │  │               │
     │                        │  │  │  └──┬──┬──┬──┬─────┘  │  │  │               │
     │                        │  │  │     │  │  │  │         │  │  │               │
     │                        │  │  │  ┌──┘  │  │  └─────────┐  │  │               │
     │                        │  │  │  │     │  │            │  │  │               │
     │                        │  │  │  ▼     ▼  ▼            ▼  │  │               │
     │                        │  │  │ ┌────┐┌────┐┌────┐┌────┐│  │               │
     │                        │  │  │ │User││Fund││Ord ││Noti││  │               │
     │                        │  │  │ │Svc ││Svc ││Svc ││Wkr ││  │               │
     │                        │  │  │ │8081││8082││8083││8084││  │               │
     │                        │  │  │ └────┘└──┬─┘└──┬─┘└────┘│  │               │
     │                        │  │  │         │     │         │  │               │
     │                        │  │  │         ▼     ▼         │  │               │
     │                        │  │  │  ┌────────┐ ┌────────┐  │  │               │
     │                        │  │  │  │PostgreSQL│RabbitMQ │  │  │               │
     │                        │  │  │  │(Stateful│(Deploy  │  │  │               │
     │                        │  │  │  │ Set+PVC)│ +PVC)   │  │  │               │
     │                        │  │  │  └────────┘ └────────┘  │  │               │
     │                        │  │  │                        │  │  │               │
     │                        │  │  └────────────────────────┘  │  │               │
     │                        │  │                             │  │               │
     │                        │  │  ┌──────────────────────┐   │  │               │
     │                        │  │  │ IAM Role             │   │  │               │
     │                        │  │  │ ├─ SES (Email)       │   │  │               │
     │                        │  │  │ ├─ ECR (Registry)    │   │  │               │
     │                        │  │  │ └─ Secrets Manager   │   │  │               │
     │                        │  │  └──────────────────────┘   │  │               │
     │                        │  └──────────────────────────────┘  │               │
     │                        │                                     │               │
     │                        └─────────────────────────────────────┘               │
     └─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

| Path Pattern | Route | Description |
|-------------|-------|-------------|
| `/assets/*`, `/`, `*.html` | **S3** | Static frontend (React SPA) served via CloudFront CDN |
| `/api/*` | **EC2 → Traefik → API Gateway** | All backend API requests proxied through K3S Ingress |

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Single EC2 + K3S** vs EKS | Cost-efficient (~$35/mo vs $73+/mo for EKS control plane alone); K3S is production-grade lightweight Kubernetes |
| **Self-hosted DB/MQ** vs RDS/AmazonMQ | All middleware runs as K3S workloads with PVC persistence — zero managed-service cost |
| **CloudFront + S3** for frontend | Global edge caching, free tier eligible (1TB transfer/mo), SPA-friendly error handling |
| **Umbrella Helm Chart** | One-command deploy of 9 components; each sub-chart independently versioned and upgradeable |
| **IAM Role** not Access Keys | EC2 gets temporary credentials via Instance Profile — no secrets in code, auto-rotation |

---

## ☁️ AWS Services Used

| Service | Purpose | Why This Service |
|---------|---------|------------------|
| **EC2** (t3.medium) | K3S compute node — runs all microservices + middleware | Burstable instance, 2vCPU/4GB RAM, perfect for moderate workloads |
| **Elastic IP** | Fixed public IPv4 for EC2 | IP persists across reboots — critical for CloudFront origin and DNS |
| **S3** | Frontend static asset storage | Durable, scalable, free tier (5GB), integrates natively with CloudFront |
| **CloudFront** | Global CDN + HTTPS termination | Edge caching (450+ POPs), free tier (1TB/mo), SPA custom error pages |
| **WAF** (Web ACL) | Web application firewall | SQL injection, XSS, rate limiting — attached to CloudFront at no extra cost |
| **IAM** (Role + Policies) | EC2 identity & permissions | Instance Profile grants EC2 access to SES, ECR, Secrets Manager — no hardcoded keys |
| **Security Groups** | Stateful firewall for EC2 | Restrict ingress to HTTP(80), SSH(22), K3S API(6443) |
| **CloudWatch** | Infrastructure metrics (CPU, disk, network) | Built-in EC2 metrics at 5-min granularity — no agent required |
| **SES** | Email notifications (future) | IAM policy attached — ready for transactional email when needed |
| **Secrets Manager** | Secret storage (future) | IAM policy attached — ready for DB passwords, API keys rotation |

---

## 🏗 Infrastructure as Code (Terraform)

All AWS resources are provisioned and managed by Terraform. The configuration follows the **live/modules** pattern — environment instances in `live/` call reusable modules in `modules/`.

### Terraform-Managed Infrastructure

| Module | Resources | Key Configuration |
|--------|-----------|-------------------|
| **networking** | `aws_security_group`, `aws_vpc` (data), `aws_subnet` (data) | HTTP:80, SSH:22, K3S API:6443 ingress rules |
| **compute** | `aws_instance`, `aws_eip` | t3.medium, 30GB gp3 EBS, Amazon Linux 2023, EIP attached |
| **iam** | `aws_iam_role`, `aws_iam_instance_profile`, `aws_iam_role_policy_attachment` × 3 | SES FullAccess, ECR FullAccess, SecretsManager ReadWrite |
| **cdn** | `aws_s3_bucket`, `aws_cloudfront_distribution`, `aws_cloudfront_origin_access_control`, `aws_s3_bucket_policy` | OAC (not public S3), dual-origin (S3 + EC2), SPA error handling, WAF association |

### Terraform Project Structure

```
infrastructure/terraform/
├── live/prod/                  # Production environment
│   ├── main.tf                 # Terraform core + AWS Providers (ap-southeast-1 + us-east-1)
│   ├── root.tf                 # Root module — orchestrates all sub-modules (DAG)
│   ├── variables.tf            # Input variables with defaults
│   ├── outputs.tf              # Outputs (EC2 IP, CloudFront domain, S3 bucket)
│   └── terraform.tfvars        # Actual configuration values
└── modules/                    # Reusable Terraform modules
    ├── networking/             # Security groups, VPC/subnet queries
    ├── compute/                # EC2 instance + Elastic IP
    ├── iam/                    # IAM role, policies, instance profile
    └── cdn/                    # S3 bucket, CloudFront distribution, WAF
```

### Terraform Outputs (Post-Deploy)

| Output | Example Value |
|--------|--------------|
| `ec2_public_ip` | `46.137.250.243` |
| `ec2_ssh_command` | `ssh ec2-user@46.137.250.243` |
| `cloudfront_domain` | `d2hoqnqufe8qq0.cloudfront.net` |
| `s3_bucket_name` | `smart-invest-frontend-service-prod-bucket-name` |
| `website_url` | `https://d2hoqnqufe8qq0.cloudfront.net` |

---

## ⎈ Application Deployments (Helm)

All application workloads are deployed to K3S via a **single Umbrella Helm Chart** — one command deploys the entire system.

### Helm-Deployed Services (Umbrella Chart)

| Chart | Type | Workload | Port | Image |
|-------|------|----------|------|-------|
| **api-gateway** | Microservice (self-written) | Deployment (2 replicas) | 8080 | `gongchengship/smart-invest-api-gateway` |
| **user-service** | Microservice (self-written) | Deployment (2 replicas) | 8081 | `gongchengship/smart-invest-user-service` |
| **fund-service** | Microservice (self-written) | Deployment (2 replicas) | 8082 | `gongchengship/smart-invest-fund-service` |
| **order-service** | Microservice (self-written) | Deployment (2 replicas) | 8083 | `gongchengship/smart-invest-order-service` |
| **notification-worker** | Background Worker (self-written) | Deployment (2 replicas) | 8084 | `gongchengship/smart-invest-notification-worker` |
| **frontend** | SPA (self-written) | Deployment (2 replicas) | 80 | `gongchengship/smart-invest-frontend` |
| **postgresql** | Database (self-written) | StatefulSet (1 replica) | 5432 | `postgres:16-alpine` |
| **rabbitmq** | Message Queue (self-written) | Deployment (1 replica) | 5672/15672 | `rabbitmq:3.13-management-alpine` |
| **redis** | Cache (Bitnami) | Deployment — _disabled by default_ | 6379 | `bitnami/redis` |

### Helm Project Structure

```
infrastructure/helm/
├── charts/                          # 9 sub-charts (independently deployable)
│   ├── api-gateway/                 # Spring Cloud Gateway
│   ├── user-service/                # Auth + User management
│   ├── fund-service/                # Fund data + Portfolio
│   ├── order-service/               # Order + Settlement
│   ├── notification-worker/         # Async notification consumer
│   ├── frontend/                    # React SPA (nginx)
│   ├── postgresql/                  # StatefulSet + Headless Service + PVC
│   ├── rabbitmq/                    # Deployment + PVC + ClusterIP
│   └── redis/                       # Deployment + PVC (optional, Bitnami)
└── umbrella/                        # Aggregator chart (one-command deploy)
    ├── Chart.yaml                   # 9 dependencies declared
    ├── values.yaml                  # Default configuration
    ├── values-prod.yaml             # Production overrides (2 replicas, 1.1.0 tag)
    └── templates/
        ├── ingress.yaml             # Traefik routing (/ → frontend, /api → gateway)
        ├── secret.yaml              # K8S Secret (DB password, JWT key, RabbitMQ password)
        └── rabbitmq-ready-hook.yaml # Pre-install Hook: wait for RabbitMQ readiness
```

### K3S Internal Service Discovery

| Service | Cluster DNS |
|---------|------------|
| PostgreSQL | `postgresql.smart-invest.svc.cluster.local:5432` |
| RabbitMQ | `rabbitmq.smart-invest.svc.cluster.local:5672` |
| API Gateway | `api-gateway.smart-invest.svc.cluster.local:8080` |
| User Service | `user-service.smart-invest.svc.cluster.local:8081` |
| Fund Service | `fund-service.smart-invest.svc.cluster.local:8082` |
| Order Service | `order-service.smart-invest.svc.cluster.local:8083` |

---

## 💻 Tech Stack

### Backend (Microservices)

| Technology | Version | Purpose |
|-----------|---------|---------|
| **Java** | 21 | Runtime — virtual threads, pattern matching, sealed classes |
| **Spring Boot** | 3.3 | Application framework — auto-configuration, actuator, validation |
| **Spring Cloud Gateway** | 2023.x | API Gateway — route-based forwarding, JWT authentication, rate limiting |
| **Spring Data JPA** | 3.3 | ORM — entity mapping, repository pattern, lazy loading |
| **Spring AMQP** | 3.3 | RabbitMQ integration — async messaging between services |
| **Flyway** | 10.x | Database migration — 17 versioned SQL migrations, seed data |
| **PostgreSQL** | 16 | Relational database — ACID transactions, JSONB, full-text search |
| **RabbitMQ** | 3.13 | Message broker — order events, settlement notifications |
| **JWT (RS256)** | — | Authentication — asymmetric signing, stateless sessions |
| **JUnit 5 + Mockito** | 5.x | Testing — unit tests, integration tests, mock beans |

### Frontend (SPA)

| Technology | Version | Purpose |
|-----------|---------|---------|
| **React** | 18 | UI library — concurrent features, hooks, suspense |
| **TypeScript** | 5.x | Type safety — interfaces, generics, strict mode |
| **Vite** | 5.x | Build tool — instant HMR, ESBuild, rollup |
| **Tailwind CSS** | 3.x | Utility-first CSS — responsive mobile-first design |
| **React Router** | 6.x | Client-side routing — lazy loading, route guards |
| **TanStack Query** | 5.x | Server state — caching, refetching, optimistic updates |
| **Axios** | 1.x | HTTP client — interceptors, request/response transformation |
| **i18next** | 24.x | Internationalization — en-US, zh-CN support |

### DevOps & Infrastructure

| Technology | Version | Purpose |
|-----------|---------|---------|
| **Terraform** | 1.9+ | Infrastructure as Code — declarative AWS resource management |
| **Helm** | 3.x | Kubernetes package manager — templated deployments, umbrella charts |
| **K3S** | v1.36 | Lightweight Kubernetes — single-binary, built-in Traefik + CoreDNS |
| **Docker** | 29.x | Container runtime — multi-stage builds, alpine-based images |
| **containerd** | 2.3 | K3S container runtime — ctr/crictl image management |
| **GitHub Actions** | — | CI/CD — build, test, deploy pipelines (planned) |
| **AWS CloudWatch** | — | Monitoring — EC2 metrics, logs, alarms |

---

## 📁 Project Structure

```
smart-invest/
├── backend/                              # Java microservices (Maven multi-module)
│   ├── pom.xml                           # Parent POM (Spring Boot 3.3, Java 21)
│   ├── common/                           # Shared library (DTOs, events, JWT, security)
│   ├── api-gateway/                      # Spring Cloud Gateway (port 8080)
│   ├── user-service/                     # User + Auth service (port 8081)
│   ├── fund-service/                     # Fund + Portfolio service (port 8082)
│   ├── order-service/                    # Order + Settlement service (port 8083)
│   └── notification-worker/              # Async notification consumer (port 8084)
│
├── frontend/                             # React SPA (TypeScript + Vite)
│   ├── src/pages/                        # Route pages (auth, funds, holdings, portfolio, plans)
│   ├── src/components/                   # Reusable UI components
│   ├── Dockerfile                        # Multi-stage nginx + dist
│   └── nginx.conf                        # SPA-friendly nginx config
│
├── infrastructure/                       # 🔧 DevOps Core — IaC + Helm
│   ├── terraform/                        # Terraform IaC
│   │   ├── live/prod/                    # Production environment instance
│   │   └── modules/                      # Reusable modules (networking, compute, iam, cdn)
│   └── helm/                             # Helm Charts
│       ├── charts/                       # 9 sub-charts (6 microservices + 3 middleware)
│       └── umbrella/                     # Aggregator chart (one-command deploy)
│
├── scripts/                              # Operations scripts
│   ├── deploy.sh                         # Full deployment orchestration
│   ├── deploy-k3s.sh                     # K3S installation
│   ├── build-images.sh                   # Docker image build
│   ├── build-amd64.sh                    # Cross-arch build (arm64 → amd64)
│   ├── deploy-monitoring.sh              # Prometheus + Grafana setup
│   ├── deploy-rabbitmq.sh                # RabbitMQ standalone deploy
│   ├── cloudwatch-setup.sh               # CloudWatch agent + alarms
│   └── k3s-dashboard-token.sh            # K3S dashboard access token
│
├── docs/                                 # Architecture & design documents
│   ├── what was build.md                 # Project feature documentation
│   └── superpowers/specs/                # Architecture specs & plans
│
├── doc-K8S/                              # Kubernetes learning notes (Chinese)
├── doc-design/                           # Product design & analysis docs
└── doc-manually/                         # Manual operations guides
```

---

## 🔬 Microservices Overview

### Service Communication

```
                    ┌─────────────┐
                    │  Frontend   │  React SPA (browser)
                    │  (nginx)    │
                    └──────┬──────┘
                           │ HTTP /api/*
                           ▼
                    ┌─────────────┐
                    │ API Gateway │  Spring Cloud Gateway
                    │  Port 8080  │  ├─ JWT authentication
                    └──┬──┬──┬───┘  ├─ Route forwarding
                       │  │  │      └─ Rate limiting
          ┌────────────┘  │  └────────────┐
          ▼               ▼               ▼
   ┌──────────┐   ┌──────────────┐   ┌──────────┐
   │  User    │   │  Fund        │   │  Order   │
   │  Service │   │  Service     │   │  Service │
   │  :8081   │   │  :8082       │   │  :8083   │
   └────┬─────┘   └──────┬───────┘   └────┬─────┘
        │                │                │
        │         ┌──────┘       ┌────────┘
        │         │              │
        ▼         ▼              ▼         RabbitMQ (AMQP)
   ┌────────┐         ┌─────────────┐         │
   │PostgreSQL│       │  RabbitMQ   │◄────────┘
   │  :5432  │       │  :5672      │
   └────────┘         └──────┬──────┘
                                    │ consume
                                    ▼
                            ┌──────────────┐
                            │ Notification │  Async Worker
                            │   Worker     │  Email notifications
                            │   :8084      │
                            └──────────────┘
```

### Service Boundaries

| Service | Responsibilities | Key Dependencies |
|---------|-----------------|------------------|
| **API Gateway** | Request routing, JWT validation, rate limiting | All downstream services |
| **User Service** | Registration, login, JWT issuance, risk assessment | PostgreSQL |
| **Fund Service** | Fund CRUD, NAV history, portfolio, investment plans | PostgreSQL, Order Service (REST) |
| **Order Service** | Subscription/redemption orders, T+2 settlement scheduling | PostgreSQL, RabbitMQ (publish) |
| **Notification Worker** | Consume order events, send email notifications | RabbitMQ (consume), SES |
| **PostgreSQL** | Relational data — 15 tables, 17 Flyway migrations | PVC (persistent storage) |
| **RabbitMQ** | Async messaging — order created, settlement completed | PVC (persistent storage) |

---

## 🚀 Deployment Workflow

### Architecture: Three Machines, Three Roles

```
┌─────────────────┐      ┌──────────────────────┐      ┌──────────────────────┐
│  Mac (arm64)    │      │  Ubuntu (x86_64)      │      │  AWS EC2 (x86_64)    │
│  Developer      │      │  Image Builder        │      │  K3S Runtime         │
│                 │      │                       │      │                      │
│  • Terraform    │      │  • Docker build       │      │  • K3S (containerd)  │
│  • Helm (CLI)   │ rsync│  • docker save        │ scp  │  • ctr image import  │
│  • Maven (jar)  │─────►│    (amd64 images)     │─────►│  • Helm install       │
│  • npm (dist)   │ scp  │                       │      │  • PostgreSQL/RabbitMQ│
│  • git          │      │                       │      │  • Traefik Ingress   │
└─────────────────┘      └──────────────────────┘      └──────────────────────┘
```

### Full Deployment Sequence

```bash
# 1. Terraform: provision/manage AWS infrastructure
cd infrastructure/terraform/live/prod
terraform init && terraform plan && terraform apply

# 2. Build: compile Java + frontend (Mac)
cd backend && mvn -q -pl common,user-service,fund-service,order-service,notification-worker,api-gateway -am package -DskipTests
cd frontend && npm run build

# 3. Sync: transfer to x86_64 build machine
rsync -avz --exclude 'node_modules' --exclude 'target' --exclude '.terraform' \
  ~/coding/smart-invest/ builder@192.168.x.x:~/coding/smart-invest/

# 4. Package: build Docker images (Ubuntu x86_64)
for svc in user-service fund-service order-service notification-worker api-gateway frontend; do
  docker build --platform linux/amd64 -t gongchengship/smart-invest-$svc:1.0.0 .
done

# 5. Transfer: images to EC2 via SCP
docker save gongchengship/smart-invest-* -o /tmp/images.tar
scp -i key.pem /tmp/images.tar ec2-user@<EC2_IP>:/tmp/
ssh ec2-user@<EC2_IP> "sudo k3s ctr image import /tmp/images.tar"

# 6. Deploy: Helm install to K3S
cd infrastructure/helm/umbrella
helm dependency update
helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --atomic --timeout 600s

# 7. Publish: frontend to S3 + CloudFront
aws s3 sync frontend/dist/ s3://<bucket>/ --delete
aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"

# 8. Verify
curl https://d2hoqnqufe8qq0.cloudfront.net/api/actuator/health
```

---

## 🛠 Local Development

### Prerequisites

- Java 21 + Maven 3.9+
- Node.js 20 + npm 10+
- Docker (for PostgreSQL + RabbitMQ)
- Terraform 1.9+
- Helm 3.x
- kubectl (configured for K3S cluster)

### Quick Start (Backend + Frontend)

```bash
# Terminal 1: Start infrastructure (Docker)
docker run -d --name postgres -p 5432:5432 \
  -e POSTGRES_DB=smartinvest -e POSTGRES_USER=smartadmin -e POSTGRES_PASSWORD=localdev_only \
  postgres:16-alpine

# Terminal 2: Start backend
cd backend
mvn -pl app spring-boot:run
# App runs at http://localhost:8080

# Terminal 3: Start frontend
cd frontend
npm install && npm run dev
# Dev server at http://localhost:5173
```

---

## 🔑 Demo Credentials

| Field | Value |
|-------|-------|
| **URL** | `https://d2hoqnqufe8qq0.cloudfront.net` |
| **Email** | `demo@smartinvest.com` |
| **Password** | `Demo1234!` |

