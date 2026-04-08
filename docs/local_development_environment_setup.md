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
| Docker | Latest | Runs local PostgreSQL database |
| Python | 3.10+ | Optional, for supplementary data scripts |

**Verify installations:**
```bash
java -version    # Should show Java 21.x
mvn -version     # Should show Maven 3.9+
node -v          # Should show v20.x or higher
docker --version # Should show latest version
```

---

## 2. Start PostgreSQL Database

Smart Invest uses PostgreSQL 16 as its database. For local development, start it via Docker.

### Start the database
```bash
cd /path/to/smart-invest   # Project root
docker compose up -d postgres
```

This will:
- Pull the `postgres:16-alpine` image (if not already present)
- Start a container named `smart-invest-db`
- Map container port 5432 to localhost:5432
- Create the `smartinvest` database

**Connection details (configured in `docker-compose.yml`):**
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
docker compose down
```
> Note: `down` stops and removes the container but does NOT delete persistent data (stored in Docker Volumes).

---

## 3. Build and Start the Backend

### 3.1 Initial Build (required on first run)

Smart Invest uses a multi-module Maven structure. Sub-modules must be installed to the local Maven repository before the main `app` module can resolve them.

```bash
#### Option 3.1.1: single line command
cd backend && mvn install -DskipTests && cd app && mvn spring-boot:run -Dspring-boot.run.profiles=local 2>&1 | tail -40;

#### Or
#### Option 3.1.2: step-by-step command
cd backend
mvn install -DskipTests
```

### 3.2 Start the backend
```bash
cd backend
SPRING_PROFILES_ACTIVE=local JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl app
```

**Startup arguments explained:**
- `SPRING_PROFILES_ACTIVE=local` — Activates `application-local.yml`, which contains local database connection settings
- `JWT_SECRET=...` — JWT signing secret. Required — the app will fail to start without it
- `-pl app` — Runs only the `app` module
- `mvn spring-boot:run` — Preferred over `java -jar` in development because it skips packaging, supports hot reload, and automatically includes unpackaged resources

### 3.3 Verify backend started successfully

Wait 20~40 seconds. When you see this in the logs, startup is complete:

```
Started SmartInvestApplication in X.XXX seconds
```

You can also hit the health endpoint:
```bash
curl http://localhost:8080/actuator/health
# Should return {"status":"UP"}
```

### 3.4 Seed data — auto-loaded by Flyway

**No manual script execution is needed!** When Spring Boot starts, Flyway automatically:
1. Scans the SQL migration files in `backend/app/src/main/resources/db/migration/`
2. Executes all unapplied migrations in order (currently 17 total)
3. Loads all seed data (funds, NAV history, demo user, holdings, etc.)

**Current migration files:**
| Migration | Description |
|-----------|-------------|
| V1~V12 | Schema definitions |
| V13 | 11 seed funds |
| V14 | Demo user (demo@smartinvest.com) + initial holdings |
| V15 | Backfill current NAV for all funds |
| V16 | Full NAV history (~329 trading days × 11 funds) |
| V17 | Fund asset/sector/geo allocations + top 10 holdings |

### 3.5 Stop the backend
```bash
kill $(lsof -ti :8080) && echo "Backend server stopped"
```

---

## 4. Start the Frontend

### 4.1 Install dependencies
```bash
cd frontend
npm install
```

### 4.2 Start the dev server
```bash
npm run dev
```

Vite will output the access address:
```
VITE v8.0.3  ready in XXX ms
➜  Local:   http://localhost:5173/
➜  Network: http://192.168.x.x:5173/
```

### 4.3 Stop the frontend
```bash
lsof -ti:5173 | xargs kill
```

---

## 5. Verify Seed Data

### 5.1 Browser verification

1. Open browser to: http://localhost:5173
2. Log in with demo credentials:
   - **Email:** demo@smartinvest.com
   - **Password:** Demo1234!

After login you should see:
- **Home page** — Fund category cards
- **My Holdings** — Three fund positions, total market value ~HKD 96,523.25
- **Fund List** — 11 funds with current NAVs
- **My Investment Plans** — One active monthly recurring plan

### 5.2 API verification (optional)

With the backend running, open a new terminal:

```bash
# Verify fund list with NAV
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

## 6. Supplementary Scripts

The `scripts/` directory in the project root contains additional utilities:

### Create demo user (usually not needed manually)
```bash
./scripts/create-demo-user.sh
```
> This script recreates the demo user account. Not needed if V14 migration ran successfully — seed data is already present.

### Seed additional NAV history (optional)
```bash
./scripts/seed-nav-history.py
```
> This script populates a longer span (5 years) of NAV history for chart display. Current V16 already includes data from 2025-01-02 to 2026-04-07 (~329 trading days), which is sufficient for most use cases.

---

## 7. Troubleshooting

### Q1: `JWT_SECRET` placeholder error on startup
```
Could not resolve placeholder 'JWT_SECRET' in value "${JWT_SECRET}"
```
**Fix:** Make sure the environment variable is set in the startup command:
```bash
JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl app
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
   docker compose down -v   # -v removes all data volumes
   docker compose up -d postgres
   # Restart backend — Flyway will re-run all migrations from scratch
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
# Port 8080 (backend)
kill $(lsof -ti :8080)

# Port 5173 (frontend)
kill $(lsof -ti :5173)

# Port 5432 (database)
docker compose stop postgres
```

---

## 8. Quick Start — All-in-One Commands

Run these in sequence to get everything running:

```bash
# 1. Start database
cd /path/to/smart-invest
docker compose up -d postgres

# 2. Wait 5 seconds
sleep 5

# 3. Build backend (first time only)
cd backend
mvn install -DskipTests

# 4. Start backend
SPRING_PROFILES_ACTIVE=local JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl app &
BACKEND_PID=$!

# 5. Wait for backend to start (~30 seconds)
sleep 30

# 6. Start frontend (in a new terminal window)
cd frontend && npm install && npm run dev

# 7. Open http://localhost:5173
# Login: demo@smartinvest.com / Demo1234!

# —— To stop ——
# Backend: kill $BACKEND_PID
# Frontend: lsof -ti:5173 | xargs kill
# Database: docker compose down
```

---

## 9. Project Structure Overview

```
smart-invest/
├── backend/                  # Spring Boot backend (multi-module Maven)
│   ├── app/                 # Main application module
│   │   └── src/main/resources/
│   │       ├── application-local.yml   # Local configuration
│   │       └── db/migration/           # Flyway migrations (V1~V17)
│   ├── module-user/         # User authentication module
│   ├── module-fund/         # Fund data module
│   ├── module-order/        # Order module
│   ├── module-portfolio/    # Portfolio module
│   ├── module-plan/         # Investment plan module
│   ├── module-scheduler/    # Scheduled jobs module
│   └── module-notification/ # Notification module
├── frontend/                # React frontend
│   └── src/
│       ├── pages/           # Page components
│       ├── components/     # Shared components
│       ├── api/             # API client
│       └── types/           # TypeScript type definitions
├── docs/                    # Documentation
│   └── local_development_environment_setup.md  # This document
├── scripts/                 # Utility scripts
└── docker-compose.yml       # Docker database configuration
```
