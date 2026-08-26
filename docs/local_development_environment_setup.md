# Smart Invest — Local Development Environment Setup

> This guide helps new users set up the complete Smart Invest development environment on their local machine, including the database, backend, and frontend, with seed data pre-loaded.

---

## 1. Prerequisites

Ensure the following software is installed before starting:

| Software | Version | Notes |
|----------|---------|-------|
| Java | 21 | Required by Spring Boot. Use [SDKMAN](https://sdkman.io/) to manage multiple versions |
| Maven | 3.9+ | Backend build tool |
| Node.js | 20+ | Frontend runtime |
| npm | 10+ | Package manager (bundled with Node.js) |
| Docker | Latest | Runs local PostgreSQL and RabbitMQ |

**Verify installations:**
```bash
java -version    # Should show Java 21.x
mvn -version     # Should show Maven 3.9+
node -v          # Should show v20.x or higher
docker --version # Should show latest version
```

---

## 2. Start PostgreSQL Database

Smart Invest uses PostgreSQL 16 as its database. For local development, start it via Docker (no `docker-compose.yml` needed).

### Start the database
```bash
docker run -d --name smart-invest-db \
  --restart unless-stopped \
  -p 5432:5432 \
  -e POSTGRES_DB=smartinvest \
  -e POSTGRES_USER=smartadmin \
  -e POSTGRES_PASSWORD=localdev_only \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:16-alpine
```

This will:
- Pull the `postgres:16-alpine` image (if not already present)
- Start a container named `smart-invest-db`
- Map container port 5432 to localhost:5432
- Create the `smartinvest` database

**Connection details:**
| Setting | Value |
|---------|-------|
| Host | localhost |
| Port | 5432 |
| Database | smartinvest |
| Username | smartadmin |
| Password | localdev_only |

### Verify database is running
```bash
docker ps
# You should see smart-invest-db with status "Up" or "healthy"
```

### Stop the database
```bash
docker stop smart-invest-db
```
> Note: `stop` stops the container but does NOT delete persistent data (stored in the `postgres_data` volume). To delete all data, run `docker rm -v smart-invest-db`.

---

## 3. Build and Start the Backend

The backend is a multi-module Maven project made up of 6 microservices: `common`, `user-service`, `fund-service`, `order-service`, `notification-worker`, and `api-gateway`.

### 3.1 Initial Build (required on first run)

```bash
cd backend
mvn install -DskipTests
```

This compiles and installs all 6 modules (including the shared `common` module) into your local Maven repository so each service can resolve its dependencies.

### 3.2 Start the services

Run each service in its own terminal. The entry point is `api-gateway` on port 8080.

```bash
cd backend

# user-service — owns the database; Flyway runs automatically on startup (21 migrations)
mvn spring-boot:run -pl user-service

# fund-service
mvn spring-boot:run -pl fund-service

# order-service
mvn spring-boot:run -pl order-service

# notification-worker (consumes RabbitMQ messages)
mvn spring-boot:run -pl notification-worker

# api-gateway — entry point (http://localhost:8080)
mvn spring-boot:run -pl api-gateway
```

**Notes:**
- `-pl <service>` — Runs only the named Maven module
- `mvn spring-boot:run` — Preferred over `java -jar` in development because it skips packaging, supports hot reload, and automatically includes unpackaged resources
- Set `SPRING_PROFILES_ACTIVE=local` (and `JWT_SECRET`) as environment variables when a service's `application-local.yml` requires them
- `order-service` → `notification-worker` messaging needs RabbitMQ (see below)

### 3.3 Verify backend started successfully

Wait 20~40 seconds. When you see this in the logs, startup is complete:

```
Started SmartInvestApplication in X.XXX seconds
```

You can also hit the health endpoint through the gateway:
```bash
curl http://localhost:8080/actuator/health
# Should return {"status":"UP"}
```

### 3.4 Seed data — auto-loaded by Flyway

**No manual script execution is needed!** When `user-service` starts, Flyway automatically:
1. Scans the SQL migration files in `backend/user-service/src/main/resources/db/migration/`
2. Executes all unapplied migrations in order (currently 21 total: V1–V21)
3. Loads all seed data (funds, NAV history, demo user, holdings, etc.)

**Current migration files:**
| Migration | Description |
|-----------|-------------|
| V1~V13 | Schema definitions |
| V14 | 11 seed funds |
| V15 | Demo user (demo@smartinvest.com) + demo data |
| V16 | Seed NAV + demo data |
| V17 | Full NAV history (~329 trading days × 11 funds) |
| V18 | Fund asset/sector/geo allocations + top 10 holdings |
| V19 | Demo orders |
| V20 | Demo plans |
| V21 | Notifications table |

### 3.5 Stop the backend
```bash
kill $(lsof -ti :8080) && echo "Backend server stopped"
```

---

## 4. Start RabbitMQ (optional, for order → notification flow)

`order-service` publishes events to RabbitMQ, and `notification-worker` consumes them. If you are not testing those flows, you can skip this step.

```bash
docker run -d --name smart-invest-rabbitmq \
  -p 5672:5672 -p 15672:15672 \
  rabbitmq:3.13-management-alpine
```

Management UI: http://localhost:15672 (guest/guest).

---

## 5. Start the Frontend

### 5.1 Install dependencies
```bash
cd frontend
npm install
```

### 5.2 Start the dev server
```bash
npm run dev
```

Vite will output the access address:
```
VITE v8.0.3  ready in XXX ms
➜  Local:   http://localhost:5173/
➜  Network: http://192.168.x.x:5173/
```

### 5.3 Stop the frontend
```bash
lsof -ti:5173 | xargs kill
```

---

## 6. Verify Seed Data

### 6.1 Browser verification

1. Open browser to: http://localhost:5173
2. Log in with demo credentials:
   - **Email:** demo@smartinvest.com
   - **Password:** Demo1234!

After login you should see:
- **Home page** — Fund category cards
- **My Holdings** — Three fund positions, total market value ~HKD 96,523.25
- **Fund List** — 11 funds with current NAVs
- **My Investment Plans** — One active monthly recurring plan

### 6.2 API verification (optional)

With the backend running, open a new terminal:

```bash
# Verify fund list with NAV (routed through api-gateway)
curl http://localhost:8080/api/funds

# Verify demo user portfolio summary (requires JWT token — see below)
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/portfolio/me/summary
```

**Obtain JWT token:**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@smartinvest.com","password":"Demo1234!"}'
# Response contains an accessToken field
```

---

## 7. Build & Deployment Scripts

The `scripts/` directory in the project root contains utilities for image building and K3S deployment (not needed for local development):

- `build-images.sh` / `build-amd64.sh` — build Docker images on the x86_64 build machine
- `deploy-k3s.sh` — deploy to the K3S cluster
- `setup-db.sh` — prepare PostgreSQL on the build machine
- `deploy-rabbitmq.sh`, `deploy-monitoring.sh`, `k3s-dashboard-token.sh`, `cloudwatch-setup.sh`

See `infrastructure/deployment-guide.md` for the full deployment workflow.

---

## 8. Troubleshooting

### Q1: `JWT_SECRET` placeholder error on startup
```
Could not resolve placeholder 'JWT_SECRET' in value "${JWT_SECRET}"
```
**Fix:** Make sure the environment variable is set in the startup command:
```bash
JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl user-service
```

### Q2: Database connection error
```
URL must start with 'jdbc'
```
**Fix:** Ensure `SPRING_PROFILES_ACTIVE=local` is set, which loads the local database connection from `application-local.yml`.

### Q3: Flyway migration fails
If you see errors like:
```
Migration VXX__xxx.sql failed
```
**Fix:**
1. Stop the backend first
2. Check which migrations already ran:
   ```bash
   docker exec smart-invest-db psql -U smartadmin -d smartinvest \
     -c "SELECT version FROM flyway_schema_history ORDER BY installed_rank;"
   ```
3. To reset the database completely:
   ```bash
   docker rm -v smart-invest-db   # removes the container and its data volume
   # Restart the DB, then restart user-service — Flyway will re-run all migrations from scratch
   ```

### Q4: Frontend page is blank or shows "No routes matched"
**Fix:** Make sure you're navigating to the correct route. Frontend routes:
- `/` — Home
- `/login` — Login
- `/funds` — Fund list
- `/funds/:id` — Fund detail
- `/holdings` — My holdings
- `/plans` — My investment plans
- `/multi-asset` — Multi-asset portfolios
- `/build-portfolio` — Custom portfolio builder

### Q5: Port already in use
```bash
# Port 8080 (api-gateway)
kill $(lsof -ti :8080)

# Port 5173 (frontend)
kill $(lsof -ti :5173)

# Port 5432 (database)
docker stop smart-invest-db
```

---

## 9. Quick Start — All-in-One Commands

Run these in sequence to get everything running:

```bash
# 1. Start database
docker run -d --name smart-invest-db \
  --restart unless-stopped -p 5432:5432 \
  -e POSTGRES_DB=smartinvest -e POSTGRES_USER=smartadmin \
  -e POSTGRES_PASSWORD=localdev_only \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:16-alpine

# 2. Build backend (first time only)
cd backend
mvn install -DskipTests

# 3. Start services (each in its own terminal window)
mvn spring-boot:run -pl user-service      # runs Flyway migrations
mvn spring-boot:run -pl fund-service
mvn spring-boot:run -pl order-service
mvn spring-boot:run -pl notification-worker
mvn spring-boot:run -pl api-gateway       # entry point http://localhost:8080

# 4. Start frontend (in a new terminal window)
cd frontend && npm install && npm run dev

# 5. Open http://localhost:5173
# Login: demo@smartinvest.com / Demo1234!

# —— To stop ——
# Services: Ctrl+C in each terminal
# Frontend: lsof -ti:5173 | xargs kill
# Database: docker stop smart-invest-db
```

---

## 10. Project Structure Overview

```
smart-invest/
├── backend/                  # Spring Boot backend (multi-module Maven)
│   ├── common/              # Shared library
│   ├── user-service/        # Auth + users + risk; Flyway migrations (V1~V21)
│   ├── fund-service/        # Fund data
│   ├── order-service/       # Orders
│   ├── notification-worker/ # RabbitMQ consumer
│   └── api-gateway/         # Spring Cloud Gateway (entry point)
├── frontend/                # React frontend
│   └── src/
│       ├── pages/           # Page components
│       ├── components/     # Shared components
│       ├── api/             # API client
│       └── types/           # TypeScript type definitions
├── infrastructure/          # Terraform IaC + Helm charts
│   ├── terraform/           # VPC, EC2, S3, CloudFront, WAF
│   └── helm/                # umbrella chart + sub-charts
├── docs/                    # Documentation
├── scripts/                 # Build & deployment scripts
└── .github/workflows/       # CI/CD (cd-k3s.yml)
```
