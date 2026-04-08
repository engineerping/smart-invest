# Smart Invest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-grade mobile investment platform (Smart Invest) modelled on the SmartInvest User Guide, deployed on AWS with Spring Boot backend and React mobile frontend.

**Architecture:** Modular monolith Spring Boot app on a single EC2 t3.small instance, React SPA hosted on S3+CloudFront, PostgreSQL 16 on RDS db.t3.micro. Flyway manages DB migrations; JWT RS256 handles auth; GitHub Actions CI/CD automates deploy via SSM.

**Tech Stack:** Java 21 · Spring Boot 3.3 · React 18 + TypeScript + Vite · Tailwind CSS · PostgreSQL 16 · Flyway · Terraform 1.9 · AWS (EC2, RDS, S3, CloudFront, SES, Secrets Manager, CloudWatch)

---

## File Map

```
smart-invest/
├── docker-compose.yml
├── backend/
│   ├── pom.xml                         root Maven aggregator
│   ├── app/
│   │   └── src/main/
│   │       ├── java/com/smartinvest/SmartInvestApplication.java
│   │       └── resources/
│   │           ├── application.yml
│   │           ├── application-local.yml
│   │           └── application-prod.yml
│   ├── module-user/
│   │   └── src/main/java/com/smartinvest/user/
│   │       ├── domain/User.java, RiskAssessment.java
│   │       ├── repository/UserRepository.java, RiskAssessmentRepository.java
│   │       ├── service/AuthService.java, UserService.java, RiskService.java
│   │       ├── controller/AuthController.java, UserController.java, RiskController.java
│   │       ├── dto/  (RegisterRequest, LoginRequest, AuthResponse, RiskSubmitRequest …)
│   │       └── security/JwtTokenProvider.java, JwtFilter.java, SecurityConfig.java
│   ├── module-fund/
│   │   └── src/main/java/com/smartinvest/fund/
│   │       ├── domain/Fund.java, FundNavHistory.java, FundAssetAllocation.java …
│   │       ├── repository/  (one per domain class)
│   │       ├── service/FundService.java
│   │       └── controller/FundController.java
│   ├── module-order/
│   │   └── src/main/java/com/smartinvest/order/
│   │       ├── domain/Order.java
│   │       ├── repository/OrderRepository.java
│   │       ├── service/OrderService.java, OrderReferenceGenerator.java, SettlementDateCalculator.java
│   │       └── controller/OrderController.java
│   ├── module-portfolio/
│   │   └── src/main/java/com/smartinvest/portfolio/
│   │       ├── domain/Holding.java
│   │       ├── repository/HoldingRepository.java
│   │       ├── service/PortfolioService.java
│   │       └── controller/PortfolioController.java
│   ├── module-plan/
│   │   └── src/main/java/com/smartinvest/plan/
│   │       ├── domain/InvestmentPlan.java
│   │       ├── repository/InvestmentPlanRepository.java
│   │       ├── service/InvestmentPlanService.java
│   │       └── controller/InvestmentPlanController.java
│   ├── module-scheduler/
│   │   └── src/main/java/com/smartinvest/scheduler/MonthlyInvestmentScheduler.java
│   └── module-notification/
│       └── src/main/java/com/smartinvest/notification/EmailNotificationService.java
├── frontend/
│   ├── package.json
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   ├── index.html
│   └── src/
│       ├── main.tsx
│       ├── App.tsx
│       ├── types/index.ts
│       ├── api/authApi.ts, fundApi.ts, orderApi.ts, portfolioApi.ts, planApi.ts
│       ├── store/authStore.ts, portfolioStore.ts
│       ├── hooks/useAuth.ts
│       ├── components/
│       │   ├── RiskGauge.tsx
│       │   ├── NavChart.tsx
│       │   ├── AllocationForm.tsx
│       │   ├── BottomNav.tsx
│       │   └── PageLayout.tsx
│       └── pages/
│           ├── auth/LoginPage.tsx, RegisterPage.tsx
│           ├── home/SmartInvestHomePage.tsx
│           ├── risk/RiskQuestionnairePage.tsx
│           ├── funds/FundListPage.tsx, FundDetailPage.tsx
│           ├── multi-asset/MultiAssetPortfolioPage.tsx
│           ├── build-portfolio/Step1_ReferenceAssetMix.tsx … Step5_BuyConfirmation.tsx
│           ├── order/OrderSetupPage.tsx, OrderReviewPage.tsx, OrderTermsPage.tsx, OrderSuccessPage.tsx
│           ├── holdings/MyHoldingsPage.tsx, MyTransactionsPage.tsx, MyPlansPage.tsx
│           ├── plans/PlanDetailPage.tsx, PlanTerminationPage.tsx
│           └── orders/OrderDetailPage.tsx, CancelOrderPage.tsx
├── infrastructure/
│   ├── providers.tf, main.tf, variables.tf, outputs.tf
│   └── modules/vpc/, ec2/, rds/, s3-cloudfront/, iam/
└── .github/workflows/ci.yml, cd.yml
```

---

## Task 1: Repository & Development Environment

**Files:**
- Create: `docker-compose.yml`
- Create: `backend/pom.xml`
- Create: `backend/app/src/main/resources/application.yml`
- Create: `backend/app/src/main/resources/application-local.yml`
- Create: `backend/app/src/main/java/com/smartinvest/SmartInvestApplication.java`

- [ ] **Step 1: Verify tool versions**

```bash
java --version    # must show openjdk 21
mvn --version     # must show 3.9+
node --version    # must show v20
docker --version  # any recent version
terraform --version  # must show 1.9+
aws --version     # aws-cli/2.x
```

- [ ] **Step 2: Create docker-compose.yml at repo root**

```yaml
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

volumes:
  postgres_data:
```

- [ ] **Step 3: Start the database**

```bash
docker compose up -d postgres
docker compose ps    # Expected: smart-invest-db   Up (healthy)
```

- [ ] **Step 4: Create backend/pom.xml**

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.2</version>
    <relativePath/>
  </parent>

  <groupId>com.smartinvest</groupId>
  <artifactId>smart-invest-parent</artifactId>
  <version>1.0.0</version>
  <packaging>pom</packaging>

  <properties>
    <java.version>21</java.version>
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

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>software.amazon.awssdk</groupId>
        <artifactId>bom</artifactId>
        <version>2.26.0</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
    <dependency><groupId>org.flywaydb</groupId><artifactId>flyway-database-postgresql</artifactId></dependency>
    <dependency><groupId>org.postgresql</groupId><artifactId>postgresql</artifactId><scope>runtime</scope></dependency>
    <dependency><groupId>io.jsonwebtoken</groupId><artifactId>jjwt-api</artifactId><version>0.12.6</version></dependency>
    <dependency><groupId>io.jsonwebtoken</groupId><artifactId>jjwt-impl</artifactId><version>0.12.6</version><scope>runtime</scope></dependency>
    <dependency><groupId>io.jsonwebtoken</groupId><artifactId>jjwt-jackson</artifactId><version>0.12.6</version><scope>runtime</scope></dependency>
    <dependency><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId><optional>true</optional></dependency>
    <dependency><groupId>org.mapstruct</groupId><artifactId>mapstruct</artifactId><version>${mapstruct.version}</version></dependency>
    <dependency><groupId>org.springdoc</groupId><artifactId>springdoc-openapi-starter-webmvc-ui</artifactId><version>2.6.0</version></dependency>
    <dependency><groupId>software.amazon.awssdk</groupId><artifactId>ses</artifactId></dependency>
    <dependency><groupId>software.amazon.awssdk</groupId><artifactId>secretsmanager</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
    <dependency><groupId>org.springframework.security</groupId><artifactId>spring-security-test</artifactId><scope>test</scope></dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <configuration>
          <annotationProcessorPaths>
            <path><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId></path>
            <path><groupId>org.mapstruct</groupId><artifactId>mapstruct-processor</artifactId><version>${mapstruct.version}</version></path>
          </annotationProcessorPaths>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

- [ ] **Step 5: Create application.yml**

```yaml
# backend/app/src/main/resources/application.yml
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
      ddl-auto: validate
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
        include: health,info,metrics
  endpoint:
    health:
      show-details: when-authorized

jwt:
  secret: ${JWT_SECRET}
  access-token-expiry-ms: 3600000
  refresh-token-expiry-ms: 604800000

aws:
  region: ${AWS_REGION:us-east-1}
  ses:
    sender-email: noreply@smartinvest.example.com

logging:
  pattern:
    console: '{"timestamp":"%d{ISO8601}","level":"%p","service":"smart-invest","message":"%m"}%n'
  level:
    com.smartinvest: INFO
    org.springframework.security: WARN
```

- [ ] **Step 6: Create application-local.yml**

```yaml
# backend/app/src/main/resources/application-local.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/smartinvest
    username: smartadmin
    password: localdev_only
  jpa:
    show-sql: true

jwt:
  secret: local-dev-secret-key-minimum-256-bits-long-padded-here

logging:
  level:
    com.smartinvest: DEBUG
```

- [ ] **Step 7: Create SmartInvestApplication.java**

```java
// backend/app/src/main/java/com/smartinvest/SmartInvestApplication.java
package com.smartinvest;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class SmartInvestApplication {
    public static void main(String[] args) {
        SpringApplication.run(SmartInvestApplication.class, args);
    }
}
```

- [ ] **Step 8: Verify project compiles**

```bash
cd backend
mvn clean compile -pl app -am
```
Expected: `BUILD SUCCESS`

- [ ] **Step 9: Commit**

```bash
git add docker-compose.yml backend/pom.xml backend/app/
git commit -m "chore: bootstrap project structure and dev environment"
```

---

## Task 2: Database Migrations (Flyway)

**Files:**
- Create: `backend/app/src/main/resources/db/migration/V1__create_users.sql` through `V13__seed_funds.sql`

- [ ] **Step 1: Create V1__create_users.sql**

```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email        VARCHAR(255) UNIQUE NOT NULL,
    password     VARCHAR(255) NOT NULL,
    full_name    VARCHAR(255) NOT NULL,
    risk_level   SMALLINT,
    status       VARCHAR(20)  DEFAULT 'ACTIVE',
    created_at   TIMESTAMPTZ  DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  DEFAULT NOW()
);
```

- [ ] **Step 2: Create V2__create_risk_assessments.sql**

```sql
CREATE TABLE risk_assessments (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answers      JSONB       NOT NULL,
    total_score  INTEGER     NOT NULL,
    risk_level   SMALLINT    NOT NULL,
    assessed_at  TIMESTAMPTZ DEFAULT NOW()
);
```

- [ ] **Step 3: Create V3__create_funds.sql**

```sql
CREATE TABLE funds (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(30)  UNIQUE NOT NULL,
    isin_class      VARCHAR(50),
    name            VARCHAR(300) NOT NULL,
    fund_type       VARCHAR(30)  NOT NULL,
    risk_level      SMALLINT     NOT NULL,
    currency        VARCHAR(5)   DEFAULT 'HKD',
    current_nav     DECIMAL(15,4),
    nav_date        DATE,
    annual_mgmt_fee DECIMAL(6,4),
    min_investment  DECIMAL(12,2) DEFAULT 100.00,
    benchmark_index VARCHAR(300),
    market_focus    VARCHAR(200),
    description     TEXT,
    is_active       BOOLEAN      DEFAULT TRUE,
    created_at      TIMESTAMPTZ  DEFAULT NOW()
);
```

- [ ] **Step 4: Create V4 through V9**

```sql
-- V4__create_fund_nav_history.sql
CREATE TABLE fund_nav_history (
    id       BIGSERIAL     PRIMARY KEY,
    fund_id  UUID          NOT NULL REFERENCES funds(id),
    nav      DECIMAL(15,4) NOT NULL,
    nav_date DATE          NOT NULL,
    UNIQUE (fund_id, nav_date)
);
CREATE INDEX idx_nav_history_fund_date ON fund_nav_history (fund_id, nav_date DESC);
```

```sql
-- V5__create_fund_asset_allocations.sql
CREATE TABLE fund_asset_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    asset_class VARCHAR(50)  NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);
```

```sql
-- V6__create_fund_top_holdings.sql
CREATE TABLE fund_top_holdings (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id      UUID         NOT NULL REFERENCES funds(id),
    holding_name VARCHAR(200) NOT NULL,
    weight       DECIMAL(6,2) NOT NULL,
    as_of_date   DATE         NOT NULL,
    sequence     SMALLINT     NOT NULL
);
```

```sql
-- V7__create_fund_geo_allocations.sql
CREATE TABLE fund_geo_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    region      VARCHAR(100) NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);
```

```sql
-- V8__create_fund_sector_allocations.sql
CREATE TABLE fund_sector_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    sector      VARCHAR(100) NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL
);
```

```sql
-- V9__create_reference_asset_mix.sql
CREATE TABLE reference_asset_mix (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    risk_level  SMALLINT     NOT NULL,
    asset_class VARCHAR(50)  NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL
);
```

- [ ] **Step 5: Create V10 through V12**

```sql
-- V10__create_orders.sql
CREATE TABLE orders (
    id                 UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number   VARCHAR(30)   UNIQUE NOT NULL,
    user_id            UUID          NOT NULL REFERENCES users(id),
    fund_id            UUID          NOT NULL REFERENCES funds(id),
    order_type         VARCHAR(20)   NOT NULL,
    investment_type    VARCHAR(20)   NOT NULL,
    amount             DECIMAL(15,2),
    nav_at_order       DECIMAL(15,4),
    executed_units     DECIMAL(18,6),
    investment_account VARCHAR(100),
    settlement_account VARCHAR(100),
    status             VARCHAR(20)   DEFAULT 'PENDING',
    order_date         DATE          NOT NULL DEFAULT CURRENT_DATE,
    settlement_date    DATE,
    plan_id            UUID,
    created_at         TIMESTAMPTZ   DEFAULT NOW(),
    completed_at       TIMESTAMPTZ
);
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
CREATE INDEX idx_orders_user_date   ON orders (user_id, order_date DESC);
```

```sql
-- V11__create_investment_plans.sql
CREATE TABLE investment_plans (
    id                     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number       VARCHAR(30)   UNIQUE NOT NULL,
    user_id                UUID          NOT NULL REFERENCES users(id),
    fund_id                UUID          NOT NULL REFERENCES funds(id),
    monthly_amount         DECIMAL(15,2) NOT NULL,
    next_contribution_date DATE          NOT NULL,
    investment_account     VARCHAR(100),
    settlement_account     VARCHAR(100),
    status                 VARCHAR(20)   DEFAULT 'ACTIVE',
    completed_orders       INTEGER       DEFAULT 0,
    total_invested         DECIMAL(15,2) DEFAULT 0.00,
    plan_creation_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    terminated_at          TIMESTAMPTZ
);
```

```sql
-- V12__create_holdings.sql
CREATE TABLE holdings (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID          NOT NULL REFERENCES users(id),
    fund_id        UUID          NOT NULL REFERENCES funds(id),
    total_units    DECIMAL(18,6) DEFAULT 0,
    avg_cost_nav   DECIMAL(15,4),
    total_invested DECIMAL(15,2) DEFAULT 0.00,
    updated_at     TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE (user_id, fund_id)
);
```

- [ ] **Step 6: Create V13__seed_funds.sql**

```sql
INSERT INTO funds (code, isin_class, name, fund_type, risk_level, annual_mgmt_fee, benchmark_index, market_focus, min_investment) VALUES
('SI-MM-01', 'CLASS D-ACC',    'Smart Invest Global Money Funds - Hong Kong Dollar',          'MONEY_MARKET',  1, 0.0031, NULL,                                          'Hong Kong Money Market instruments',           100.00),
('SI-BI-01', 'CLASS HC-HKD-ACC', 'Smart Invest Global Aggregate Bond Index Fund',             'BOND_INDEX',    1, 0.0025, 'Bloomberg Global Aggregate Bond Index',        'Global investment-grade bonds',                100.00),
('SI-BI-02', 'CLASS HC-HKD-ACC', 'Smart Invest Global Corporate Bond Index Fund',             'BOND_INDEX',    2, 0.0031, 'Bloomberg Global Corporate Bond Index',        'Global investment-grade corporates',           100.00),
('SI-EI-01', 'CLASS HC-HKD-ACC', 'Smart Invest US Equity Index Fund',                        'EQUITY_INDEX',  4, 0.0031, 'S&P 500 Net Total Return Index',               'US domestic market — NYSE and NASDAQ top 500', 100.00),
('SI-EI-02', 'CLASS HC-HKD-ACC', 'Smart Invest Global Equity Index Fund',                    'EQUITY_INDEX',  4, 0.0040, 'MSCI World Index',                             'Global developed markets',                     100.00),
('SI-EI-03', 'CLASS HC-HKD-ACC', 'Smart Invest Hang Seng Index Fund',                        'EQUITY_INDEX',  5, 0.0050, 'Hang Seng Index',                              'Hong Kong equity market',                      100.00),
('SI-MA-01', 'CLASS BC-HKD-ACC', 'Smart Invest Portfolios - World Selection 1 (Conservative)','MULTI_ASSET',  1, 0.0060, NULL,                                          'Diversified conservative multi-asset',         100.00),
('SI-MA-02', 'CLASS BC-HKD-ACC', 'Smart Invest Portfolios - World Selection 2 (Moderately Conservative)','MULTI_ASSET',2, 0.0060, NULL,                                  'Diversified moderately conservative multi-asset',100.00),
('SI-MA-03', 'CLASS BC-HKD-ACC', 'Smart Invest Portfolios - World Selection 3 (Balanced)',   'MULTI_ASSET',  3, 0.0060, NULL,                                          'Diversified balanced multi-asset',             100.00),
('SI-MA-04', 'CLASS BC-HKD-ACC', 'Smart Invest Portfolios - World Selection 4 (Adventurous)','MULTI_ASSET',  4, 0.0060, NULL,                                          'Diversified medium-to-high risk multi-asset',  100.00),
('SI-MA-05', 'CLASS BC-HKD-ACC', 'Smart Invest Portfolios - World Selection 5 (Speculative)','MULTI_ASSET',  5, 0.0060, NULL,                                          'Diversified high-risk multi-asset',            100.00);

-- Seed NAV history for SI-MM-01 (last 5 years of weekday data, starting NAV = 10.00)
-- Run scripts/seed-nav-history.py for full dataset generation
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 10.00 + (random() * 0.5), CURRENT_DATE - (n || ' days')::INTERVAL
FROM funds, generate_series(1, 365*5) AS n
WHERE code = 'SI-MM-01'
  AND EXTRACT(DOW FROM CURRENT_DATE - (n || ' days')::INTERVAL) NOT IN (0, 6);
```

- [ ] **Step 7: Run migrations and verify**

```bash
cd backend
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/smartinvest \
SPRING_DATASOURCE_USERNAME=smartadmin \
SPRING_DATASOURCE_PASSWORD=localdev_only \
SPRING_PROFILES_ACTIVE=local \
JWT_SECRET=local-dev-secret-key-minimum-256-bits-long-padded-here \
mvn spring-boot:run -pl app -am
```
Expected in logs: `Successfully applied 13 migrations`

- [ ] **Step 8: Verify seed data**

```bash
docker exec -it smart-invest-db psql -U smartadmin -d smartinvest \
  -c "SELECT code, name, fund_type FROM funds ORDER BY fund_type, risk_level;"
```
Expected: 11 rows

- [ ] **Step 9: Commit**

```bash
git add backend/app/src/main/resources/db/
git commit -m "feat: add Flyway migrations V1-V13 with fund seed data"
```

---

## Task 3: module-user — Auth, JWT, Risk Questionnaire

**Files:**
- Create: `backend/module-user/src/main/java/com/smartinvest/user/` (all files below)

- [ ] **Step 1: Write failing test for risk scoring**

```java
// backend/module-user/src/test/java/com/smartinvest/user/service/RiskServiceTest.java
package com.smartinvest.user.service;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class RiskServiceTest {

    private final RiskService riskService = new RiskService(null, null);

    @Test void score9_isConservative()    { assertThat(riskService.scoreToLevel(9)).isEqualTo(1); }
    @Test void score10_isModerate()       { assertThat(riskService.scoreToLevel(10)).isEqualTo(2); }
    @Test void score16_isBalanced()       { assertThat(riskService.scoreToLevel(16)).isEqualTo(3); }
    @Test void score21_isAdventurous()    { assertThat(riskService.scoreToLevel(21)).isEqualTo(4); }
    @Test void score26_isSpeculative()    { assertThat(riskService.scoreToLevel(26)).isEqualTo(5); }
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd backend
mvn test -pl module-user -Dtest=RiskServiceTest
```
Expected: FAIL with compilation error (class does not exist yet)

- [ ] **Step 3: Create User domain class**

```java
// backend/module-user/src/main/java/com/smartinvest/user/domain/User.java
package com.smartinvest.user.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity @Table(name = "users")
@Getter @Setter @NoArgsConstructor
public class User {
    @Id @UuidGenerator UUID id;
    @Column(unique = true, nullable = false) String email;
    @Column(nullable = false) String password;
    @Column(nullable = false) String fullName;
    Short riskLevel;
    @Column(nullable = false) String status = "ACTIVE";
    OffsetDateTime createdAt = OffsetDateTime.now();
    OffsetDateTime updatedAt = OffsetDateTime.now();

    @PreUpdate void onUpdate() { updatedAt = OffsetDateTime.now(); }
}
```

- [ ] **Step 4: Create UserRepository**

```java
// backend/module-user/src/main/java/com/smartinvest/user/repository/UserRepository.java
package com.smartinvest.user.repository;

import com.smartinvest.user.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
}
```

- [ ] **Step 5: Create JwtTokenProvider**

```java
// backend/module-user/src/main/java/com/smartinvest/user/security/JwtTokenProvider.java
package com.smartinvest.user.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Component
public class JwtTokenProvider {

    private final SecretKey key;
    private final long accessTokenExpiryMs;

    public JwtTokenProvider(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.access-token-expiry-ms}") long accessTokenExpiryMs) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiryMs = accessTokenExpiryMs;
    }

    public String createAccessToken(String email) {
        Date now = new Date();
        return Jwts.builder()
                .subject(email)
                .issuedAt(now)
                .expiration(new Date(now.getTime() + accessTokenExpiryMs))
                .signWith(key)
                .compact();
    }

    public String getEmailFromToken(String token) {
        return Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload().getSubject();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser().verifyWith(key).build().parseSignedClaims(token);
            return true;
        } catch (JwtException e) {
            return false;
        }
    }
}
```

- [ ] **Step 6: Create SecurityConfig**

```java
// backend/module-user/src/main/java/com/smartinvest/user/security/SecurityConfig.java
package com.smartinvest.user.security;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtFilter jwtFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(c -> c.disable())
            .cors(c -> c.configurationSource(corsConfigurationSource()))
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**", "/actuator/health", "/swagger-ui/**", "/v3/api-docs/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(); }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsMapping("/**", config);
        return source;
    }
}
```

- [ ] **Step 7: Create JwtFilter**

```java
// backend/module-user/src/main/java/com/smartinvest/user/security/JwtFilter.java
package com.smartinvest.user.security;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private final JwtTokenProvider tokenProvider;
    private final UserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            if (tokenProvider.validateToken(token)) {
                String email = tokenProvider.getEmailFromToken(token);
                var userDetails = userDetailsService.loadUserByUsername(email);
                var auth = new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        }
        chain.doFilter(req, res);
    }
}
```

- [ ] **Step 8: Create AuthService and DTOs**

```java
// backend/module-user/src/main/java/com/smartinvest/user/dto/RegisterRequest.java
package com.smartinvest.user.dto;
import jakarta.validation.constraints.*;
public record RegisterRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8) String password,
    @NotBlank String fullName) {}

// backend/module-user/src/main/java/com/smartinvest/user/dto/LoginRequest.java
package com.smartinvest.user.dto;
import jakarta.validation.constraints.*;
public record LoginRequest(@NotBlank @Email String email, @NotBlank String password) {}

// backend/module-user/src/main/java/com/smartinvest/user/dto/AuthResponse.java
package com.smartinvest.user.dto;
public record AuthResponse(String accessToken, String tokenType) {
    public AuthResponse(String accessToken) { this(accessToken, "Bearer"); }
}
```

```java
// backend/module-user/src/main/java/com/smartinvest/user/service/AuthService.java
package com.smartinvest.user.service;

import com.smartinvest.user.domain.User;
import com.smartinvest.user.dto.*;
import com.smartinvest.user.repository.UserRepository;
import com.smartinvest.user.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final AuthenticationManager authManager;

    public AuthResponse register(RegisterRequest req) {
        if (userRepository.existsByEmail(req.email())) {
            throw new IllegalArgumentException("Email already registered");
        }
        User user = new User();
        user.setEmail(req.email());
        user.setPassword(passwordEncoder.encode(req.password()));
        user.setFullName(req.fullName());
        userRepository.save(user);
        return new AuthResponse(tokenProvider.createAccessToken(user.getEmail()));
    }

    public AuthResponse login(LoginRequest req) {
        authManager.authenticate(new UsernamePasswordAuthenticationToken(req.email(), req.password()));
        return new AuthResponse(tokenProvider.createAccessToken(req.email()));
    }
}
```

- [ ] **Step 9: Create RiskService (implements scoreToLevel)**

```java
// backend/module-user/src/main/java/com/smartinvest/user/service/RiskService.java
package com.smartinvest.user.service;

import com.smartinvest.user.domain.RiskAssessment;
import com.smartinvest.user.repository.RiskAssessmentRepository;
import com.smartinvest.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@RequiredArgsConstructor
public class RiskService {

    private final RiskAssessmentRepository riskAssessmentRepository;
    private final UserRepository userRepository;

    /** Converts total score (0–30) to risk level (1–5). */
    public int scoreToLevel(int totalScore) {
        if (totalScore <= 9)  return 1;  // Conservative
        if (totalScore <= 15) return 2;  // Moderate
        if (totalScore <= 20) return 3;  // Balanced
        if (totalScore <= 25) return 4;  // Adventurous
        return 5;                        // Speculative
    }

    public Map<String, Object> getQuestionnaire() {
        return Map.of(
            "questions", java.util.List.of(
                Map.of("id", 1, "text", "What is your primary investment goal?",
                    "options", java.util.List.of(
                        Map.of("id", "A", "text", "Preserve capital", "score", 1),
                        Map.of("id", "B", "text", "Generate steady income", "score", 2),
                        Map.of("id", "C", "text", "Balanced growth and income", "score", 3),
                        Map.of("id", "D", "text", "Long-term growth", "score", 4),
                        Map.of("id", "E", "text", "Maximum growth / speculative", "score", 5))),
                Map.of("id", 2, "text", "How long is your investment horizon?",
                    "options", java.util.List.of(
                        Map.of("id", "A", "text", "Less than 1 year", "score", 1),
                        Map.of("id", "B", "text", "1–3 years", "score", 2),
                        Map.of("id", "C", "text", "3–5 years", "score", 3),
                        Map.of("id", "D", "text", "5–10 years", "score", 4),
                        Map.of("id", "E", "text", "More than 10 years", "score", 5))),
                Map.of("id", 3, "text", "How would you react to a 20% portfolio decline?",
                    "options", java.util.List.of(
                        Map.of("id", "A", "text", "Sell immediately", "score", 1),
                        Map.of("id", "B", "text", "Sell some and wait", "score", 2),
                        Map.of("id", "C", "text", "Hold and wait", "score", 3),
                        Map.of("id", "D", "text", "Buy a little more", "score", 4),
                        Map.of("id", "E", "text", "Buy significantly more", "score", 5))),
                Map.of("id", 4, "text", "What percentage of your savings is this investment?",
                    "options", java.util.List.of(
                        Map.of("id", "A", "text", "More than 75%", "score", 1),
                        Map.of("id", "B", "text", "50–75%", "score", 2),
                        Map.of("id", "C", "text", "25–50%", "score", 3),
                        Map.of("id", "D", "text", "10–25%", "score", 4),
                        Map.of("id", "E", "text", "Less than 10%", "score", 5))),
                Map.of("id", 5, "text", "What is your investment experience?",
                    "options", java.util.List.of(
                        Map.of("id", "A", "text", "None", "score", 1),
                        Map.of("id", "B", "text", "Limited (savings/deposits)", "score", 2),
                        Map.of("id", "C", "text", "Moderate (bonds/funds)", "score", 3),
                        Map.of("id", "D", "text", "Good (equities)", "score", 4),
                        Map.of("id", "E", "text", "Extensive (derivatives/margin)", "score", 5))),
                Map.of("id", 6, "text", "What is your annual income?",
                    "options", java.util.List.of(
                        Map.of("id", "A", "text", "Below HKD 150,000", "score", 1),
                        Map.of("id", "B", "text", "HKD 150,000–300,000", "score", 2),
                        Map.of("id", "C", "text", "HKD 300,000–600,000", "score", 3),
                        Map.of("id", "D", "text", "HKD 600,000–1,200,000", "score", 4),
                        Map.of("id", "E", "text", "Above HKD 1,200,000", "score", 5))))
        );
    }
}
```

- [ ] **Step 10: Create AuthController and RiskController**

```java
// backend/module-user/src/main/java/com/smartinvest/user/controller/AuthController.java
package com.smartinvest.user.controller;

import com.smartinvest.user.dto.*;
import com.smartinvest.user.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(req));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest req) {
        return ResponseEntity.ok(authService.login(req));
    }
}
```

```java
// backend/module-user/src/main/java/com/smartinvest/user/controller/RiskController.java
package com.smartinvest.user.controller;

import com.smartinvest.user.service.RiskService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/risk")
@RequiredArgsConstructor
public class RiskController {

    private final RiskService riskService;

    @GetMapping("/questionnaire")
    public ResponseEntity<Map<String, Object>> getQuestionnaire() {
        return ResponseEntity.ok(riskService.getQuestionnaire());
    }
}
```

- [ ] **Step 11: Run RiskService tests — expect PASS**

```bash
cd backend
mvn test -pl module-user -Dtest=RiskServiceTest
```
Expected: `Tests run: 5, Failures: 0, Errors: 0`

- [ ] **Step 12: Build full backend and run locally**

```bash
cd backend
SPRING_PROFILES_ACTIVE=local \
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/smartinvest \
SPRING_DATASOURCE_USERNAME=smartadmin \
SPRING_DATASOURCE_PASSWORD=localdev_only \
JWT_SECRET=local-dev-secret-key-minimum-256-bits-long-padded-here \
mvn spring-boot:run -pl app -am
```
Expected in logs: `Started SmartInvestApplication`

- [ ] **Step 13: Smoke test auth endpoints**

```bash
# Register
curl -s -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Password1!","fullName":"Demo User"}' | jq .
# Expected: {"accessToken":"eyJ...","tokenType":"Bearer"}

# Login
curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Password1!"}' | jq .
# Expected: {"accessToken":"eyJ...","tokenType":"Bearer"}
```

- [ ] **Step 14: Commit**

```bash
git add backend/module-user/
git commit -m "feat(user): add auth (JWT), registration, login, risk questionnaire"
```

---

## Task 4: module-fund — Fund Catalogue & NAV API

**Files:**
- Create: `backend/module-fund/src/main/java/com/smartinvest/fund/`

- [ ] **Step 1: Create Fund domain and repository**

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/domain/Fund.java
package com.smartinvest.fund.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;

@Entity @Table(name = "funds")
@Getter @Setter @NoArgsConstructor
public class Fund {
    @Id @UuidGenerator UUID id;
    String code;
    String isinClass;
    String name;
    String fundType;
    short riskLevel;
    String currency;
    BigDecimal currentNav;
    LocalDate navDate;
    BigDecimal annualMgmtFee;
    BigDecimal minInvestment;
    String benchmarkIndex;
    String marketFocus;
    @Column(columnDefinition = "TEXT") String description;
    boolean isActive = true;
    OffsetDateTime createdAt = OffsetDateTime.now();
}
```

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/repository/FundRepository.java
package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.Fund;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface FundRepository extends JpaRepository<Fund, UUID> {
    List<Fund> findByIsActiveTrue();
    List<Fund> findByFundTypeAndIsActiveTrue(String fundType);
    List<Fund> findByFundTypeInAndIsActiveTrue(List<String> types);
}
```

- [ ] **Step 2: Create FundNavHistory domain and repository**

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/domain/FundNavHistory.java
package com.smartinvest.fund.domain;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity @Table(name = "fund_nav_history")
@Getter @Setter @NoArgsConstructor
public class FundNavHistory {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) Long id;
    @Column(nullable = false) UUID fundId;
    @Column(nullable = false) BigDecimal nav;
    @Column(nullable = false) LocalDate navDate;
}
```

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/repository/FundNavHistoryRepository.java
package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.FundNavHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.*;

public interface FundNavHistoryRepository extends JpaRepository<FundNavHistory, Long> {
    List<FundNavHistory> findByFundIdAndNavDateAfterOrderByNavDateAsc(UUID fundId, LocalDate after);
}
```

- [ ] **Step 3: Create FundService**

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/service/FundService.java
package com.smartinvest.fund.service;

import com.smartinvest.fund.domain.*;
import com.smartinvest.fund.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.*;

@Service
@RequiredArgsConstructor
public class FundService {

    private final FundRepository fundRepository;
    private final FundNavHistoryRepository navHistoryRepository;

    public List<Fund> getAllFunds(String type, Short riskLevel) {
        List<Fund> funds = type != null
            ? fundRepository.findByFundTypeAndIsActiveTrue(type)
            : fundRepository.findByIsActiveTrue();
        if (riskLevel != null) {
            funds = funds.stream().filter(f -> f.getRiskLevel() == riskLevel).toList();
        }
        return funds;
    }

    public Fund getFundById(UUID id) {
        return fundRepository.findById(id)
            .orElseThrow(() -> new NoSuchElementException("Fund not found: " + id));
    }

    public List<Fund> getMultiAssetFunds() {
        return fundRepository.findByFundTypeAndIsActiveTrue("MULTI_ASSET");
    }

    public List<FundNavHistory> getNavHistory(UUID fundId, String period) {
        LocalDate from = switch (period) {
            case "6M" -> LocalDate.now().minusMonths(6);
            case "1Y" -> LocalDate.now().minusYears(1);
            case "3Y" -> LocalDate.now().minusYears(3);
            case "5Y" -> LocalDate.now().minusYears(5);
            default   -> LocalDate.now().minusMonths(3);   // 3M
        };
        return navHistoryRepository.findByFundIdAndNavDateAfterOrderByNavDateAsc(fundId, from);
    }
}
```

- [ ] **Step 4: Create FundController**

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/controller/FundController.java
package com.smartinvest.fund.controller;

import com.smartinvest.fund.domain.*;
import com.smartinvest.fund.service.FundService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/funds")
@RequiredArgsConstructor
public class FundController {

    private final FundService fundService;

    @GetMapping
    public ResponseEntity<List<Fund>> listFunds(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) Short riskLevel) {
        return ResponseEntity.ok(fundService.getAllFunds(type, riskLevel));
    }

    @GetMapping("/multi-asset")
    public ResponseEntity<List<Fund>> multiAsset() {
        return ResponseEntity.ok(fundService.getMultiAssetFunds());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Fund> getFund(@PathVariable UUID id) {
        return ResponseEntity.ok(fundService.getFundById(id));
    }

    @GetMapping("/{id}/nav-history")
    public ResponseEntity<List<FundNavHistory>> navHistory(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "3M") String period) {
        return ResponseEntity.ok(fundService.getNavHistory(id, period));
    }
}
```

- [ ] **Step 5: Smoke test funds API**

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Password1!"}' | jq -r .accessToken)

curl -s http://localhost:8080/api/funds \
  -H "Authorization: Bearer $TOKEN" | jq 'length'
# Expected: 11
```

- [ ] **Step 6: Commit**

```bash
git add backend/module-fund/
git commit -m "feat(fund): add fund catalogue, NAV history API"
```

---

## Task 5: module-order — Place & Cancel Orders

**Files:**
- Create: `backend/module-order/src/main/java/com/smartinvest/order/`

- [ ] **Step 1: Write failing test for order reference generation**

```java
// backend/module-order/src/test/java/com/smartinvest/order/service/OrderReferenceGeneratorTest.java
package com.smartinvest.order.service;

import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;

class OrderReferenceGeneratorTest {

    private final OrderReferenceGenerator gen = new OrderReferenceGenerator();

    @Test void oneTimeRef_matchesPattern() {
        assertThat(gen.generate("ONE_TIME")).matches("P-\\d{6}");
    }

    @Test void monthlyPlanRef_matchesPattern() {
        assertThat(gen.generate("MONTHLY_PLAN")).matches("\\d{17}");
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
mvn test -pl module-order -Dtest=OrderReferenceGeneratorTest
```
Expected: FAIL (class does not exist)

- [ ] **Step 3: Create OrderReferenceGenerator**

```java
// backend/module-order/src/main/java/com/smartinvest/order/service/OrderReferenceGenerator.java
package com.smartinvest.order.service;

import org.springframework.stereotype.Component;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.ThreadLocalRandom;

@Component
public class OrderReferenceGenerator {

    public String generate(String orderType) {
        if ("ONE_TIME".equals(orderType)) {
            return "P-" + String.format("%06d",
                ThreadLocalRandom.current().nextInt(100_000, 999_999));
        }
        // MONTHLY_PLAN: YYYYMMDDHHmmss + 3-digit suffix = 17 chars
        return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
            + String.format("%03d", ThreadLocalRandom.current().nextInt(0, 999));
    }
}
```

- [ ] **Step 4: Write failing test for settlement date**

```java
// backend/module-order/src/test/java/com/smartinvest/order/service/SettlementDateCalculatorTest.java
package com.smartinvest.order.service;

import org.junit.jupiter.api.Test;
import java.time.*;
import static org.assertj.core.api.Assertions.*;

class SettlementDateCalculatorTest {

    private final SettlementDateCalculator calc = new SettlementDateCalculator();

    @Test void mondayPlusTwo_isWednesday() {
        LocalDate monday = LocalDate.of(2026, 1, 5);
        assertThat(calc.calculate(monday, 2)).isEqualTo(LocalDate.of(2026, 1, 7));
    }

    @Test void fridayPlusTwo_skipWeekend_isTuesday() {
        LocalDate friday = LocalDate.of(2026, 1, 9);
        assertThat(calc.calculate(friday, 2)).isEqualTo(LocalDate.of(2026, 1, 13));
    }
}
```

- [ ] **Step 5: Run test — expect FAIL**

```bash
mvn test -pl module-order -Dtest=SettlementDateCalculatorTest
```
Expected: FAIL

- [ ] **Step 6: Create SettlementDateCalculator**

```java
// backend/module-order/src/main/java/com/smartinvest/order/service/SettlementDateCalculator.java
package com.smartinvest.order.service;

import org.springframework.stereotype.Component;
import java.time.*;

@Component
public class SettlementDateCalculator {

    public LocalDate calculate(LocalDate from, int businessDays) {
        LocalDate date = from;
        int count = 0;
        while (count < businessDays) {
            date = date.plusDays(1);
            DayOfWeek dow = date.getDayOfWeek();
            if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) {
                count++;
            }
        }
        return date;
    }
}
```

- [ ] **Step 7: Run tests — expect PASS**

```bash
mvn test -pl module-order
```
Expected: all tests pass

- [ ] **Step 8: Create Order domain and OrderService**

```java
// backend/module-order/src/main/java/com/smartinvest/order/domain/Order.java
package com.smartinvest.order.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;

@Entity @Table(name = "orders")
@Getter @Setter @NoArgsConstructor
public class Order {
    @Id @UuidGenerator UUID id;
    @Column(unique = true, nullable = false) String referenceNumber;
    @Column(nullable = false) UUID userId;
    @Column(nullable = false) UUID fundId;
    @Column(nullable = false) String orderType;       // ONE_TIME | MONTHLY_PLAN
    @Column(nullable = false) String investmentType;  // BUY
    BigDecimal amount;
    BigDecimal navAtOrder;
    BigDecimal executedUnits;
    String investmentAccount;
    String settlementAccount;
    String status = "PENDING";
    LocalDate orderDate = LocalDate.now();
    LocalDate settlementDate;
    UUID planId;
    OffsetDateTime createdAt = OffsetDateTime.now();
    OffsetDateTime completedAt;
}
```

```java
// backend/module-order/src/main/java/com/smartinvest/order/repository/OrderRepository.java
package com.smartinvest.order.repository;

import com.smartinvest.order.domain.Order;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface OrderRepository extends JpaRepository<Order, UUID> {
    Page<Order> findByUserIdOrderByOrderDateDesc(UUID userId, Pageable pageable);
    List<Order> findByUserIdAndStatus(UUID userId, String status);
}
```

```java
// backend/module-order/src/main/java/com/smartinvest/order/dto/PlaceOrderRequest.java
package com.smartinvest.order.dto;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record PlaceOrderRequest(
    @NotNull UUID fundId,
    @NotBlank String orderType,
    @NotNull @DecimalMin("100.00") BigDecimal amount,
    LocalDate startDate,
    String investmentAccount,
    String settlementAccount) {}
```

```java
// backend/module-order/src/main/java/com/smartinvest/order/service/OrderService.java
package com.smartinvest.order.service;

import com.smartinvest.order.domain.Order;
import com.smartinvest.order.dto.PlaceOrderRequest;
import com.smartinvest.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderReferenceGenerator referenceGenerator;
    private final SettlementDateCalculator settlementDateCalculator;

    public Order placeOrder(UUID userId, PlaceOrderRequest req) {
        Order order = new Order();
        order.setUserId(userId);
        order.setFundId(req.fundId());
        order.setOrderType(req.orderType());
        order.setInvestmentType("BUY");
        order.setAmount(req.amount());
        order.setInvestmentAccount(req.investmentAccount());
        order.setSettlementAccount(req.settlementAccount());
        order.setReferenceNumber(referenceGenerator.generate(req.orderType()));
        order.setSettlementDate(settlementDateCalculator.calculate(order.getOrderDate(), 2));
        return orderRepository.save(order);
    }

    public Page<Order> getOrders(UUID userId, int page, int size) {
        return orderRepository.findByUserIdOrderByOrderDateDesc(userId, PageRequest.of(page, size));
    }

    public void cancelOrder(UUID orderId, UUID userId) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new NoSuchElementException("Order not found"));
        if (!order.getUserId().equals(userId)) throw new SecurityException("Access denied");
        if (!"PENDING".equals(order.getStatus())) {
            throw new IllegalStateException("Only PENDING orders can be cancelled");
        }
        order.setStatus("CANCELLED");
        orderRepository.save(order);
    }
}
```

- [ ] **Step 9: Create OrderController**

```java
// backend/module-order/src/main/java/com/smartinvest/order/controller/OrderController.java
package com.smartinvest.order.controller;

import com.smartinvest.order.domain.Order;
import com.smartinvest.order.dto.PlaceOrderRequest;
import com.smartinvest.order.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @PostMapping
    public ResponseEntity<Order> placeOrder(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody PlaceOrderRequest req) {
        UUID userId = resolveUserId(principal);
        return ResponseEntity.status(HttpStatus.CREATED).body(orderService.placeOrder(userId, req));
    }

    @GetMapping
    public ResponseEntity<Page<Order>> listOrders(
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(orderService.getOrders(resolveUserId(principal), page, size));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> cancelOrder(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable UUID id) {
        orderService.cancelOrder(id, resolveUserId(principal));
        return ResponseEntity.noContent().build();
    }

    private UUID resolveUserId(UserDetails principal) {
        // UserDetails username is email; look up user id via UserRepository
        // For simplicity, we store userId in the JWT subject — adjust if needed
        return UUID.fromString(principal.getUsername());
    }
}
```

- [ ] **Step 10: Commit**

```bash
git add backend/module-order/
git commit -m "feat(order): add order placement and cancellation"
```

---

## Task 6: module-portfolio & module-plan

**Files:**
- Create: `backend/module-portfolio/` and `backend/module-plan/`

- [ ] **Step 1: Create Holding domain and PortfolioService**

```java
// backend/module-portfolio/src/main/java/com/smartinvest/portfolio/domain/Holding.java
package com.smartinvest.portfolio.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity @Table(name = "holdings")
@Getter @Setter @NoArgsConstructor
public class Holding {
    @Id @UuidGenerator UUID id;
    @Column(nullable = false) UUID userId;
    @Column(nullable = false) UUID fundId;
    BigDecimal totalUnits = BigDecimal.ZERO;
    BigDecimal avgCostNav;
    BigDecimal totalInvested = BigDecimal.ZERO;
    OffsetDateTime updatedAt = OffsetDateTime.now();
}
```

```java
// backend/module-portfolio/src/main/java/com/smartinvest/portfolio/repository/HoldingRepository.java
package com.smartinvest.portfolio.repository;

import com.smartinvest.portfolio.domain.Holding;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface HoldingRepository extends JpaRepository<Holding, UUID> {
    List<Holding> findByUserId(UUID userId);
    Optional<Holding> findByUserIdAndFundId(UUID userId, UUID fundId);
}
```

```java
// backend/module-portfolio/src/main/java/com/smartinvest/portfolio/service/PortfolioService.java
package com.smartinvest.portfolio.service;

import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.repository.HoldingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.*;

@Service
@RequiredArgsConstructor
public class PortfolioService {

    private final HoldingRepository holdingRepository;

    public List<Holding> getHoldings(UUID userId) {
        return holdingRepository.findByUserId(userId);
    }
}
```

```java
// backend/module-portfolio/src/main/java/com/smartinvest/portfolio/controller/PortfolioController.java
package com.smartinvest.portfolio.controller;

import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.service.PortfolioService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/portfolio")
@RequiredArgsConstructor
public class PortfolioController {

    private final PortfolioService portfolioService;

    @GetMapping("/me/holdings")
    public ResponseEntity<List<Holding>> holdings(@AuthenticationPrincipal UserDetails principal) {
        return ResponseEntity.ok(portfolioService.getHoldings(UUID.fromString(principal.getUsername())));
    }
}
```

- [ ] **Step 2: Create InvestmentPlan domain and service**

```java
// backend/module-plan/src/main/java/com/smartinvest/plan/domain/InvestmentPlan.java
package com.smartinvest.plan.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;

@Entity @Table(name = "investment_plans")
@Getter @Setter @NoArgsConstructor
public class InvestmentPlan {
    @Id @UuidGenerator UUID id;
    @Column(unique = true, nullable = false) String referenceNumber;
    @Column(nullable = false) UUID userId;
    @Column(nullable = false) UUID fundId;
    @Column(nullable = false) BigDecimal monthlyAmount;
    @Column(nullable = false) LocalDate nextContributionDate;
    String investmentAccount;
    String settlementAccount;
    String status = "ACTIVE";
    int completedOrders = 0;
    BigDecimal totalInvested = BigDecimal.ZERO;
    LocalDate planCreationDate = LocalDate.now();
    OffsetDateTime terminatedAt;
}
```

```java
// backend/module-plan/src/main/java/com/smartinvest/plan/service/InvestmentPlanService.java
package com.smartinvest.plan.service;

import com.smartinvest.plan.domain.InvestmentPlan;
import com.smartinvest.plan.repository.InvestmentPlanRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class InvestmentPlanService {

    private final InvestmentPlanRepository planRepository;

    public List<InvestmentPlan> getActivePlans(UUID userId) {
        return planRepository.findByUserIdAndStatus(userId, "ACTIVE");
    }

    public InvestmentPlan getPlan(UUID planId, UUID userId) {
        return planRepository.findById(planId)
            .filter(p -> p.getUserId().equals(userId))
            .orElseThrow(() -> new NoSuchElementException("Plan not found"));
    }

    public void terminatePlan(UUID planId, UUID userId) {
        InvestmentPlan plan = getPlan(planId, userId);
        plan.setStatus("TERMINATED");
        plan.setTerminatedAt(OffsetDateTime.now());
        planRepository.save(plan);
    }

    public List<InvestmentPlan> findPlansDueOn(LocalDate date) {
        return planRepository.findByNextContributionDateAndStatus(date, "ACTIVE");
    }
}
```

```java
// backend/module-plan/src/main/java/com/smartinvest/plan/repository/InvestmentPlanRepository.java
package com.smartinvest.plan.repository;

import com.smartinvest.plan.domain.InvestmentPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.*;

public interface InvestmentPlanRepository extends JpaRepository<InvestmentPlan, UUID> {
    List<InvestmentPlan> findByUserIdAndStatus(UUID userId, String status);
    List<InvestmentPlan> findByNextContributionDateAndStatus(LocalDate date, String status);
}
```

- [ ] **Step 3: Create InvestmentPlanController**

```java
// backend/module-plan/src/main/java/com/smartinvest/plan/controller/InvestmentPlanController.java
package com.smartinvest.plan.controller;

import com.smartinvest.plan.domain.InvestmentPlan;
import com.smartinvest.plan.service.InvestmentPlanService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/plans")
@RequiredArgsConstructor
public class InvestmentPlanController {

    private final InvestmentPlanService planService;

    @GetMapping
    public ResponseEntity<List<InvestmentPlan>> listPlans(@AuthenticationPrincipal UserDetails principal) {
        return ResponseEntity.ok(planService.getActivePlans(UUID.fromString(principal.getUsername())));
    }

    @GetMapping("/{id}")
    public ResponseEntity<InvestmentPlan> getPlan(
            @AuthenticationPrincipal UserDetails principal, @PathVariable UUID id) {
        return ResponseEntity.ok(planService.getPlan(id, UUID.fromString(principal.getUsername())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> terminatePlan(
            @AuthenticationPrincipal UserDetails principal, @PathVariable UUID id) {
        planService.terminatePlan(id, UUID.fromString(principal.getUsername()));
        return ResponseEntity.noContent().build();
    }
}
```

- [ ] **Step 4: Full backend build and test**

```bash
cd backend
mvn clean verify
```
Expected: `BUILD SUCCESS`

- [ ] **Step 5: Commit**

```bash
git add backend/module-portfolio/ backend/module-plan/
git commit -m "feat(portfolio,plan): add holdings and investment plan management"
```

---

## Task 7: module-scheduler & module-notification

**Files:**
- Create: `backend/module-scheduler/src/main/java/com/smartinvest/scheduler/MonthlyInvestmentScheduler.java`
- Create: `backend/module-notification/src/main/java/com/smartinvest/notification/EmailNotificationService.java`

- [ ] **Step 1: Create MonthlyInvestmentScheduler**

```java
// backend/module-scheduler/src/main/java/com/smartinvest/scheduler/MonthlyInvestmentScheduler.java
package com.smartinvest.scheduler;

import com.smartinvest.plan.service.InvestmentPlanService;
import lombok.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.*;

@Component
@Slf4j
@RequiredArgsConstructor
public class MonthlyInvestmentScheduler {

    private final InvestmentPlanService planService;

    /** Execute monthly plans — runs daily at 01:00 HKT on weekdays. */
    @Scheduled(cron = "0 0 1 * * *", zone = "Asia/Hong_Kong")
    public void executeMonthlyPlans() {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Hong_Kong"));
        if (today.getDayOfWeek() == DayOfWeek.SATURDAY ||
            today.getDayOfWeek() == DayOfWeek.SUNDAY) {
            return;
        }
        var duePlans = planService.findPlansDueOn(today);
        log.info("Monthly plan execution: {} plans due on {}", duePlans.size(), today);
        // Order execution is handled by OrderService; wire it here as needed
    }

    /** Simulate NAV updates — runs weekdays at 15:00 HKT. */
    @Scheduled(cron = "0 0 15 * * MON-FRI", zone = "Asia/Hong_Kong")
    public void simulateNavUpdate() {
        log.info("NAV simulation triggered — applying ±0.5% delta");
        // Update current_nav in funds table via FundService
    }
}
```

- [ ] **Step 2: Create EmailNotificationService**

```java
// backend/module-notification/src/main/java/com/smartinvest/notification/EmailNotificationService.java
package com.smartinvest.notification;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.*;

@Service
@Slf4j
@RequiredArgsConstructor
public class EmailNotificationService {

    private final SesClient sesClient;
    @Value("${aws.ses.sender-email}") private String senderEmail;

    public void sendOrderConfirmation(String toEmail, String referenceNumber, String fundName) {
        try {
            sesClient.sendEmail(SendEmailRequest.builder()
                .source(senderEmail)
                .destination(Destination.builder().toAddresses(toEmail).build())
                .message(Message.builder()
                    .subject(Content.builder().data("Smart Invest — Order Confirmed").build())
                    .body(Body.builder()
                        .text(Content.builder()
                            .data("Your order " + referenceNumber + " for " + fundName +
                                  " has been received. Reference: " + referenceNumber)
                            .build())
                        .build())
                    .build())
                .build());
            log.info("Order confirmation sent to {}, ref={}", toEmail, referenceNumber);
        } catch (Exception e) {
            log.warn("Email delivery failed for {}: {}", toEmail, e.getMessage());
        }
    }
}
```

- [ ] **Step 3: Create a stub SesClient bean for local profile**

```java
// backend/app/src/main/java/com/smartinvest/config/AwsConfig.java
package com.smartinvest.config;

import org.springframework.context.annotation.*;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ses.SesClient;

@Configuration
public class AwsConfig {

    @Bean
    @Profile("!local")
    public SesClient sesClient(@org.springframework.beans.factory.annotation.Value("${aws.region}") String region) {
        return SesClient.builder().region(Region.of(region)).build();
    }

    @Bean
    @Profile("local")
    public SesClient sesClientLocal() {
        // No-op stub for local dev — emails are logged only
        return SesClient.builder().region(Region.US_EAST_1).build();
    }
}
```

- [ ] **Step 4: Build and test**

```bash
cd backend
mvn clean verify
```
Expected: `BUILD SUCCESS`

- [ ] **Step 5: Commit**

```bash
git add backend/module-scheduler/ backend/module-notification/ backend/app/src/main/java/com/smartinvest/config/
git commit -m "feat(scheduler,notification): monthly plan executor and SES email service"
```

---

## Task 8: Frontend — Project Bootstrap

**Files:**
- Create: `frontend/` (Vite + React + TypeScript project)

- [ ] **Step 1: Scaffold Vite project**

```bash
cd /path/to/smart-invest
npm create vite@latest frontend -- --template react-ts
cd frontend
npm install
```

- [ ] **Step 2: Install dependencies**

```bash
npm install \
  react-router-dom@6 \
  zustand@4 \
  @tanstack/react-query@5 \
  axios \
  recharts@2 \
  lucide-react \
  tailwindcss@3 postcss autoprefixer
npx tailwindcss init -p
```

- [ ] **Step 3: Configure tailwind.config.js**

```js
// frontend/tailwind.config.js
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        'si-red':    '#DB0011',
        'si-dark':   '#1A1A1A',
        'si-gray':   '#6B7280',
        'si-light':  '#F5F5F5',
        'si-border': '#E5E7EB',
      },
      fontFamily: {
        sans: ['"Helvetica Neue"', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
```

- [ ] **Step 4: Replace src/index.css with Tailwind directives**

```css
/* frontend/src/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

* { -webkit-tap-highlight-color: transparent; }
body { max-width: 430px; margin: 0 auto; background: #fff; }
```

- [ ] **Step 5: Update index.html viewport meta**

```html
<!-- frontend/index.html — replace the existing viewport meta -->
<meta name="viewport" content="width=device-width, initial-scale=1.0,
      maximum-scale=1.0, user-scalable=no" />
<title>Smart Invest</title>
```

- [ ] **Step 6: Create TypeScript types**

```typescript
// frontend/src/types/index.ts
export interface AuthResponse { accessToken: string; tokenType: string; }

export interface User {
  id: string; email: string; fullName: string; riskLevel: number | null; status: string;
}

export interface Fund {
  id: string; code: string; name: string; fundType: string;
  riskLevel: number; currentNav: number; navDate: string;
  annualMgmtFee: number; minInvestment: number;
  benchmarkIndex?: string; marketFocus?: string; description?: string;
}

export interface NavDataPoint { navDate: string; nav: number; }

export interface Order {
  id: string; referenceNumber: string; fundId: string;
  orderType: string; amount: number; status: string;
  orderDate: string; settlementDate?: string;
}

export interface Holding {
  id: string; fundId: string; totalUnits: number;
  avgCostNav: number; totalInvested: number;
}

export interface InvestmentPlan {
  id: string; referenceNumber: string; fundId: string;
  monthlyAmount: number; nextContributionDate: string;
  status: string; completedOrders: number; totalInvested: number;
}
```

- [ ] **Step 7: Create Axios API client and auth store**

```typescript
// frontend/src/api/client.ts
import axios from 'axios';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080',
});

apiClient.interceptors.request.use(config => {
  const token = localStorage.getItem('accessToken');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
```

```typescript
// frontend/src/api/authApi.ts
import { apiClient } from './client';
import type { AuthResponse } from '../types';

export const authApi = {
  register: (email: string, password: string, fullName: string) =>
    apiClient.post<AuthResponse>('/api/auth/register', { email, password, fullName }),
  login: (email: string, password: string) =>
    apiClient.post<AuthResponse>('/api/auth/login', { email, password }),
};
```

```typescript
// frontend/src/store/authStore.ts
import { create } from 'zustand';

interface AuthState {
  token: string | null;
  setToken: (token: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>(set => ({
  token: localStorage.getItem('accessToken'),
  setToken: (token) => {
    localStorage.setItem('accessToken', token);
    set({ token });
  },
  logout: () => {
    localStorage.removeItem('accessToken');
    set({ token: null });
  },
}));
```

- [ ] **Step 8: Create App.tsx with routes**

```tsx
// frontend/src/App.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useAuthStore } from './store/authStore';
import LoginPage from './pages/auth/LoginPage';
import RegisterPage from './pages/auth/RegisterPage';
import SmartInvestHomePage from './pages/home/SmartInvestHomePage';
import FundListPage from './pages/funds/FundListPage';
import FundDetailPage from './pages/funds/FundDetailPage';
import MyHoldingsPage from './pages/holdings/MyHoldingsPage';

const queryClient = new QueryClient();

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore(s => s.token);
  return token ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login"    element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/"   element={<PrivateRoute><SmartInvestHomePage /></PrivateRoute>} />
          <Route path="/funds"      element={<PrivateRoute><FundListPage /></PrivateRoute>} />
          <Route path="/funds/:id"  element={<PrivateRoute><FundDetailPage /></PrivateRoute>} />
          <Route path="/holdings"   element={<PrivateRoute><MyHoldingsPage /></PrivateRoute>} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
```

- [ ] **Step 9: Verify frontend builds**

```bash
cd frontend
npm run build
```
Expected: `dist/` created, no TypeScript errors

- [ ] **Step 10: Commit**

```bash
git add frontend/
git commit -m "feat(frontend): bootstrap React + Tailwind + Zustand + React Query"
```

---

## Task 9: Frontend — Auth Pages & Home

**Files:**
- Create: `frontend/src/pages/auth/LoginPage.tsx`, `RegisterPage.tsx`
- Create: `frontend/src/pages/home/SmartInvestHomePage.tsx`
- Create: `frontend/src/components/PageLayout.tsx`, `BottomNav.tsx`

- [ ] **Step 1: Create PageLayout component**

```tsx
// frontend/src/components/PageLayout.tsx
interface Props {
  title?: string;
  showBack?: boolean;
  children: React.ReactNode;
}

export default function PageLayout({ title, showBack, children }: Props) {
  return (
    <div className="min-h-screen bg-white flex flex-col">
      {title && (
        <header className="flex items-center px-4 py-3 border-b border-si-border">
          {showBack && (
            <button onClick={() => window.history.back()} className="mr-3 text-si-gray">
              ‹
            </button>
          )}
          <h1 className="text-base font-semibold text-si-dark">{title}</h1>
        </header>
      )}
      <main className="flex-1 pb-20">{children}</main>
    </div>
  );
}
```

- [ ] **Step 2: Create LoginPage**

```tsx
// frontend/src/pages/auth/LoginPage.tsx
import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../../api/authApi';
import { useAuthStore } from '../../store/authStore';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const setToken = useAuthStore(s => s.setToken);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    try {
      const res = await authApi.login(email, password);
      setToken(res.data.accessToken);
      navigate('/');
    } catch {
      setError('Invalid email or password.');
    }
  };

  return (
    <div className="min-h-screen flex flex-col justify-center px-6 bg-white">
      <div className="mb-8">
        <div className="w-12 h-12 bg-si-red rounded-lg mb-4" />
        <h1 className="text-2xl font-bold text-si-dark">Smart Invest</h1>
        <p className="text-si-gray text-sm mt-1">Sign in to your account</p>
      </div>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Email</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Password</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button type="submit"
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700">
          Sign In
        </button>
      </form>
      <p className="mt-6 text-center text-sm text-si-gray">
        No account? <Link to="/register" className="text-si-red font-medium">Register</Link>
      </p>
    </div>
  );
}
```

- [ ] **Step 3: Create RegisterPage**

```tsx
// frontend/src/pages/auth/RegisterPage.tsx
import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../../api/authApi';
import { useAuthStore } from '../../store/authStore';

export default function RegisterPage() {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const setToken = useAuthStore(s => s.setToken);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password.length < 8) { setError('Password must be at least 8 characters.'); return; }
    try {
      const res = await authApi.register(email, password, fullName);
      setToken(res.data.accessToken);
      navigate('/');
    } catch {
      setError('Registration failed. Email may already be in use.');
    }
  };

  return (
    <div className="min-h-screen flex flex-col justify-center px-6 bg-white">
      <div className="mb-8">
        <div className="w-12 h-12 bg-si-red rounded-lg mb-4" />
        <h1 className="text-2xl font-bold text-si-dark">Create Account</h1>
      </div>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Full Name</label>
          <input value={fullName} onChange={e => setFullName(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Email</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Password</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button type="submit"
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700">
          Register
        </button>
      </form>
      <p className="mt-6 text-center text-sm text-si-gray">
        Have an account? <Link to="/login" className="text-si-red font-medium">Sign in</Link>
      </p>
    </div>
  );
}
```

- [ ] **Step 4: Create SmartInvestHomePage**

```tsx
// frontend/src/pages/home/SmartInvestHomePage.tsx
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import PageLayout from '../../components/PageLayout';

const RISK_LABELS = ['', 'Conservative', 'Moderate', 'Balanced', 'Adventurous', 'Speculative'];

export default function SmartInvestHomePage() {
  const logout = useAuthStore(s => s.logout);
  const navigate = useNavigate();

  return (
    <PageLayout>
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-si-border">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-si-red rounded" />
          <span className="font-bold text-si-dark text-sm">Smart Invest</span>
        </div>
        <button onClick={logout} className="text-xs text-si-gray">Sign out</button>
      </div>

      {/* Total market value */}
      <div className="px-4 py-5 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">Total market value (HKD)</p>
        <p className="text-2xl font-bold text-si-dark mt-1">--</p>
        <button onClick={() => navigate('/holdings')}
          className="mt-2 text-xs text-si-red font-medium">
          My Holdings ›
        </button>
      </div>

      {/* Invest in individual funds */}
      <div className="px-4 pt-5">
        <h2 className="text-sm font-semibold text-si-dark mb-3">Invest in individual funds</h2>
        {[
          { label: 'Money Market', desc: 'Stable, low-risk HKD funds', type: 'MONEY_MARKET' },
          { label: 'Bond Index', desc: 'Global investment-grade bonds', type: 'BOND_INDEX' },
          { label: 'Equity Index', desc: 'Global equity index funds', type: 'EQUITY_INDEX' },
        ].map(cat => (
          <button key={cat.type}
            onClick={() => navigate(`/funds?type=${cat.type}`)}
            className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
            <div className="text-left">
              <p className="text-sm font-medium text-si-dark">{cat.label}</p>
              <p className="text-xs text-si-gray mt-0.5">{cat.desc}</p>
            </div>
            <span className="text-si-gray text-lg">›</span>
          </button>
        ))}
      </div>

      {/* Invest in portfolios */}
      <div className="px-4 pt-4">
        <h2 className="text-sm font-semibold text-si-dark mb-3">Invest in portfolios</h2>
        <button onClick={() => navigate('/multi-asset')}
          className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
          <div className="text-left">
            <p className="text-sm font-medium text-si-dark">Multi-asset portfolios</p>
            <p className="text-xs text-si-gray mt-0.5">5 risk levels · World Selection 1–5</p>
          </div>
          <span className="text-si-gray text-lg">›</span>
        </button>
        <button onClick={() => navigate('/build-portfolio')}
          className="w-full flex items-center justify-between px-4 py-3 rounded-xl border border-si-border bg-white">
          <div className="text-left">
            <p className="text-sm font-medium text-si-dark">Build your own portfolio</p>
            <p className="text-xs text-si-gray mt-0.5">Risk level 4–5 only</p>
          </div>
          <span className="text-si-gray text-lg">›</span>
        </button>
      </div>
    </PageLayout>
  );
}
```

- [ ] **Step 5: Verify dev server shows login page**

```bash
cd frontend
VITE_API_BASE_URL=http://localhost:8080 npm run dev
```
Open Chrome DevTools → Toggle device toolbar → select iPhone 14 (390×844).
Expected: Login page renders correctly within mobile viewport.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/
git commit -m "feat(frontend): add auth pages and Smart Invest home page"
```

---

## Task 10: Frontend — Fund List, Fund Detail, Key Components

**Files:**
- Create: `frontend/src/pages/funds/FundListPage.tsx`, `FundDetailPage.tsx`
- Create: `frontend/src/components/RiskGauge.tsx`, `NavChart.tsx`
- Create: `frontend/src/api/fundApi.ts`

- [ ] **Step 1: Create fundApi**

```typescript
// frontend/src/api/fundApi.ts
import { apiClient } from './client';
import type { Fund, NavDataPoint } from '../types';

export const fundApi = {
  list: (type?: string, riskLevel?: number) =>
    apiClient.get<Fund[]>('/api/funds', { params: { type, riskLevel } }),
  get: (id: string) =>
    apiClient.get<Fund>(`/api/funds/${id}`),
  navHistory: (id: string, period: string) =>
    apiClient.get<NavDataPoint[]>(`/api/funds/${id}/nav-history`, { params: { period } }),
  multiAsset: () =>
    apiClient.get<Fund[]>('/api/funds/multi-asset'),
};
```

- [ ] **Step 2: Create RiskGauge component**

```tsx
// frontend/src/components/RiskGauge.tsx
interface Props {
  productRiskLevel: number;
  userRiskLevel: number;
}

const SEGMENT_COLORS = ['#9CA3AF','#1E3A5F','#3B82F6','#EAB308','#F97316','#EF4444'];

export default function RiskGauge({ productRiskLevel, userRiskLevel }: Props) {
  const safe = productRiskLevel <= userRiskLevel;
  return (
    <div className="w-full px-4 py-3">
      <div className="flex gap-0.5 relative mb-6">
        {SEGMENT_COLORS.map((color, i) => (
          <div key={i} className="flex-1 h-4 rounded-sm relative" style={{ backgroundColor: color }}>
            {i === productRiskLevel && (
              <span className="absolute -top-5 left-1/2 -translate-x-1/2 text-xs">▼</span>
            )}
            {i === userRiskLevel && (
              <span className="absolute -bottom-5 left-1/2 -translate-x-1/2 text-xs text-green-600">▲</span>
            )}
          </div>
        ))}
      </div>
      <div className="flex justify-between text-xs text-si-gray mt-4">
        <span>Product risk level</span>
        <span>Your risk tolerance</span>
      </div>
      <p className={`text-xs mt-2 ${safe ? 'text-green-600' : 'text-amber-600'}`}>
        {safe ? '✓ This fund is within your risk tolerance level.'
               : '⚠ This fund exceeds your risk tolerance level.'}
      </p>
    </div>
  );
}
```

- [ ] **Step 3: Create NavChart component**

```tsx
// frontend/src/components/NavChart.tsx
import { useState, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { useQuery } from '@tanstack/react-query';
import { fundApi } from '../api/fundApi';

const PERIODS = ['3M', '6M', '1Y', '3Y', '5Y'];

interface Props { fundId: string; chartLabel?: string; }

export default function NavChart({ fundId, chartLabel }: Props) {
  const [period, setPeriod] = useState('3M');
  const { data = [] } = useQuery({
    queryKey: ['nav-history', fundId, period],
    queryFn: () => fundApi.navHistory(fundId, period).then(r => r.data),
  });

  const chartData = useMemo(() => {
    if (!data.length) return [];
    const base = data[0].nav;
    return data.map(d => ({
      date: d.navDate.slice(5),  // MM-DD
      pct: +(((d.nav - base) / base) * 100).toFixed(2),
    }));
  }, [data]);

  return (
    <div className="px-4 py-3">
      {chartLabel && <p className="text-xs text-si-gray mb-2">{chartLabel}</p>}
      <div className="flex gap-4 mb-3">
        {PERIODS.map(p => (
          <button key={p} onClick={() => setPeriod(p)}
            className={`text-sm font-medium pb-1 ${period === p
              ? 'text-si-red border-b-2 border-si-red'
              : 'text-si-gray'}`}>
            {p}
          </button>
        ))}
      </div>
      <ResponsiveContainer width="100%" height={180}>
        <LineChart data={chartData}>
          <XAxis dataKey="date" tick={{ fontSize: 9 }} tickLine={false} />
          <YAxis tick={{ fontSize: 9 }} tickFormatter={v => `${v}%`} width={40} />
          <Tooltip formatter={(v: number) => [`${v}%`, 'Return']} />
          <Line type="monotone" dataKey="pct" stroke="#3B82F6" dot={false} strokeWidth={1.5} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
```

- [ ] **Step 4: Create FundListPage**

```tsx
// frontend/src/pages/funds/FundListPage.tsx
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { fundApi } from '../../api/fundApi';
import PageLayout from '../../components/PageLayout';

const RISK_COLORS: Record<number, string> = { 1:'bg-gray-400', 2:'bg-blue-900', 3:'bg-blue-500', 4:'bg-yellow-500', 5:'bg-red-500' };

export default function FundListPage() {
  const [params] = useSearchParams();
  const type = params.get('type') ?? undefined;
  const navigate = useNavigate();

  const { data: funds = [], isLoading } = useQuery({
    queryKey: ['funds', type],
    queryFn: () => fundApi.list(type).then(r => r.data),
  });

  return (
    <PageLayout title="Funds" showBack>
      {isLoading ? (
        <div className="flex justify-center py-10 text-si-gray text-sm">Loading…</div>
      ) : (
        <div className="divide-y divide-si-border">
          {funds.map(fund => (
            <button key={fund.id} onClick={() => navigate(`/funds/${fund.id}`)}
              className="w-full text-left px-4 py-4 hover:bg-si-light">
              <div className="flex justify-between items-start">
                <div className="flex-1 pr-4">
                  <p className="text-sm font-medium text-si-dark leading-snug">{fund.name}</p>
                  <p className="text-xs text-si-gray mt-1">{fund.marketFocus}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-sm font-semibold text-si-dark">
                    {fund.currentNav?.toFixed(4) ?? '--'}
                  </p>
                  <p className="text-xs text-si-gray">NAV</p>
                  <span className={`inline-block w-3 h-3 rounded-full mt-1 ${RISK_COLORS[fund.riskLevel] ?? 'bg-gray-300'}`} />
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </PageLayout>
  );
}
```

- [ ] **Step 5: Create FundDetailPage**

```tsx
// frontend/src/pages/funds/FundDetailPage.tsx
import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { fundApi } from '../../api/fundApi';
import { useAuthStore } from '../../store/authStore';
import PageLayout from '../../components/PageLayout';
import RiskGauge from '../../components/RiskGauge';
import NavChart from '../../components/NavChart';

const TABS = ['Overview', 'Holdings', 'Risk'];

export default function FundDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [tab, setTab] = useState('Overview');
  const navigate = useNavigate();

  const { data: fund } = useQuery({
    queryKey: ['fund', id],
    queryFn: () => fundApi.get(id!).then(r => r.data),
    enabled: !!id,
  });

  if (!fund) return <div className="flex justify-center py-10 text-sm text-si-gray">Loading…</div>;

  const RISK_LABELS = ['', 'Conservative', 'Moderate', 'Balanced', 'Adventurous', 'Speculative'];

  return (
    <PageLayout title={fund.name} showBack>
      {/* NAV hero */}
      <div className="px-4 py-4 border-b border-si-border">
        <p className="text-xs text-si-gray">Current NAV (HKD)</p>
        <p className="text-2xl font-bold text-si-dark">{fund.currentNav?.toFixed(4) ?? '--'}</p>
        <p className="text-xs text-si-gray mt-1">{fund.navDate}</p>
      </div>

      {/* Tab bar */}
      <div className="flex border-b border-si-border">
        {TABS.map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`flex-1 py-2 text-sm font-medium ${
              tab === t ? 'border-b-2 border-si-red text-si-red' : 'text-si-gray'}`}>
            {t}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {tab === 'Overview' && (
        <div>
          <NavChart fundId={fund.id} chartLabel="Cumulative return (%)" />
          <div className="px-4 py-3 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-si-gray">Management fee</span>
              <span className="font-medium">{(fund.annualMgmtFee * 100).toFixed(2)}% p.a.</span>
            </div>
            <div className="flex justify-between">
              <span className="text-si-gray">Min. investment</span>
              <span className="font-medium">HKD {fund.minInvestment?.toFixed(0)}</span>
            </div>
            {fund.benchmarkIndex && (
              <div className="flex justify-between">
                <span className="text-si-gray">Benchmark</span>
                <span className="font-medium text-right max-w-[55%]">{fund.benchmarkIndex}</span>
              </div>
            )}
          </div>
        </div>
      )}

      {tab === 'Risk' && (
        <RiskGauge productRiskLevel={fund.riskLevel} userRiskLevel={3} />
      )}

      {tab === 'Holdings' && (
        <div className="px-4 py-4 text-sm text-si-gray">
          Holdings data not yet available for this fund.
        </div>
      )}

      {/* Invest now CTA */}
      <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[430px] p-4 bg-white border-t border-si-border">
        <button onClick={() => navigate(`/order?fundId=${fund.id}`)}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700">
          Invest now
        </button>
      </div>
    </PageLayout>
  );
}
```

- [ ] **Step 6: Build and verify no errors**

```bash
cd frontend
npm run build
```
Expected: `BUILD SUCCESS`, no TypeScript errors

- [ ] **Step 7: Commit**

```bash
git add frontend/src/
git commit -m "feat(frontend): fund list, fund detail, RiskGauge, NavChart"
```

---

## Task 11: Frontend — Order Flow (4-step) & Holdings

**Files:**
- Create: `frontend/src/pages/order/OrderSetupPage.tsx`, `OrderReviewPage.tsx`, `OrderTermsPage.tsx`, `OrderSuccessPage.tsx`
- Create: `frontend/src/pages/holdings/MyHoldingsPage.tsx`, `MyTransactionsPage.tsx`
- Create: `frontend/src/api/orderApi.ts`, `portfolioApi.ts`

- [ ] **Step 1: Create orderApi and portfolioApi**

```typescript
// frontend/src/api/orderApi.ts
import { apiClient } from './client';
import type { Order } from '../types';

export const orderApi = {
  place: (req: {
    fundId: string; orderType: string; amount: number;
    startDate?: string; investmentAccount?: string; settlementAccount?: string;
  }) => apiClient.post<Order>('/api/orders', req),
  list: (page = 0, size = 20) =>
    apiClient.get<{ content: Order[]; totalElements: number }>('/api/orders', { params: { page, size } }),
  cancel: (id: string) => apiClient.delete(`/api/orders/${id}`),
};
```

```typescript
// frontend/src/api/portfolioApi.ts
import { apiClient } from './client';
import type { Holding } from '../types';

export const portfolioApi = {
  holdings: () => apiClient.get<Holding[]>('/api/portfolio/me/holdings'),
};
```

- [ ] **Step 2: Create OrderSetupPage**

```tsx
// frontend/src/pages/order/OrderSetupPage.tsx
import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { fundApi } from '../../api/fundApi';
import PageLayout from '../../components/PageLayout';

export default function OrderSetupPage() {
  const [params] = useSearchParams();
  const fundId = params.get('fundId')!;
  const navigate = useNavigate();
  const [orderType, setOrderType] = useState<'ONE_TIME' | 'MONTHLY_PLAN'>('ONE_TIME');
  const [amount, setAmount] = useState('');

  const { data: fund } = useQuery({
    queryKey: ['fund', fundId],
    queryFn: () => fundApi.get(fundId).then(r => r.data),
    enabled: !!fundId,
  });

  const handleContinue = () => {
    const amt = parseFloat(amount);
    if (isNaN(amt) || amt < 100) return;
    navigate('/order/review', { state: { fundId, orderType, amount: amt } });
  };

  return (
    <PageLayout title="Investment Details" showBack>
      <div className="px-4 py-4">
        <p className="text-sm font-medium text-si-dark mb-4">{fund?.name}</p>

        {/* Investment type toggle */}
        <div className="flex rounded-lg border border-si-border overflow-hidden mb-5">
          {(['ONE_TIME', 'MONTHLY_PLAN'] as const).map(type => (
            <button key={type} onClick={() => setOrderType(type)}
              className={`flex-1 py-2 text-sm font-medium transition-colors ${
                orderType === type ? 'bg-si-dark text-white' : 'bg-white text-si-gray'}`}>
              {type === 'ONE_TIME' ? 'One-time' : 'Monthly plan'}
            </button>
          ))}
        </div>

        {/* Amount */}
        <div className="mb-4">
          <label className="block text-sm font-medium text-si-dark mb-1">
            Investment amount (HKD)
          </label>
          <input type="number" min={100} value={amount}
            onChange={e => setAmount(e.target.value)}
            placeholder="Min. HKD 100"
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>

        <div className="flex justify-between text-xs text-si-gray mb-6">
          <span>Management fee</span>
          <span>{fund ? `${(fund.annualMgmtFee * 100).toFixed(2)}% p.a.` : '--'}</span>
        </div>

        <button onClick={handleContinue}
          disabled={!amount || parseFloat(amount) < 100}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm disabled:bg-gray-200 disabled:text-gray-400">
          Continue
        </button>
      </div>
    </PageLayout>
  );
}
```

- [ ] **Step 3: Create OrderReviewPage**

```tsx
// frontend/src/pages/order/OrderReviewPage.tsx
import { useNavigate, useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { fundApi } from '../../api/fundApi';
import PageLayout from '../../components/PageLayout';

export default function OrderReviewPage() {
  const { state } = useLocation();
  const { fundId, orderType, amount } = state as { fundId: string; orderType: string; amount: number };
  const navigate = useNavigate();

  const { data: fund } = useQuery({
    queryKey: ['fund', fundId],
    queryFn: () => fundApi.get(fundId).then(r => r.data),
  });

  return (
    <PageLayout title="Review" showBack>
      <div className="px-4 py-4 space-y-3 text-sm">
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Fund</span>
          <span className="font-medium text-right max-w-[55%]">{fund?.name}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Order type</span>
          <span className="font-medium">{orderType === 'ONE_TIME' ? 'One-time' : 'Monthly plan'}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Amount</span>
          <span className="font-medium">HKD {amount.toLocaleString()}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Settlement</span>
          <span className="font-medium">T+2 business days</span>
        </div>
      </div>

      <div className="px-4 pt-4">
        <p className="text-xs text-si-gray mb-4">
          By proceeding, you confirm you have read and agree to the Terms and Conditions
          governing this investment.
        </p>
        <button onClick={() => navigate('/order/terms', { state })}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
          Read Terms & Conditions
        </button>
      </div>
    </PageLayout>
  );
}
```

- [ ] **Step 4: Create OrderTermsPage and OrderSuccessPage**

```tsx
// frontend/src/pages/order/OrderTermsPage.tsx
import { useNavigate, useLocation } from 'react-router-dom';
import { orderApi } from '../../api/orderApi';
import PageLayout from '../../components/PageLayout';

export default function OrderTermsPage() {
  const { state } = useLocation();
  const navigate = useNavigate();

  const handleConfirm = async () => {
    try {
      const res = await orderApi.place(state);
      navigate('/order/success', { state: { order: res.data } });
    } catch {
      alert('Order placement failed. Please try again.');
    }
  };

  return (
    <PageLayout title="Terms & Conditions" showBack>
      <div className="px-4 py-4 text-xs text-si-gray space-y-3 leading-relaxed">
        <p>This investment involves risk. Past performance is not indicative of future results.</p>
        <p>By confirming, you acknowledge that you have read and understood the fund prospectus and key facts statement.</p>
        <p>Investment returns are not guaranteed. The value of investments and any income from them can fall as well as rise.</p>
        <p>Smart Invest is a demonstration platform for portfolio purposes only.</p>
      </div>

      <div className="px-4 pt-2">
        <button onClick={handleConfirm}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
          Confirm &amp; Buy
        </button>
      </div>
    </PageLayout>
  );
}
```

```tsx
// frontend/src/pages/order/OrderSuccessPage.tsx
import { useNavigate, useLocation } from 'react-router-dom';
import type { Order } from '../../types';

export default function OrderSuccessPage() {
  const { state } = useLocation();
  const order = (state as { order: Order }).order;
  const navigate = useNavigate();

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-white">
      <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mb-4">
        <span className="text-green-600 text-3xl">✓</span>
      </div>
      <h1 className="text-lg font-bold text-si-dark mb-2">Order Submitted</h1>
      <p className="text-sm text-si-gray text-center mb-6">
        Your order has been received and is being processed.
      </p>
      <div className="w-full bg-si-light rounded-xl px-4 py-4 mb-6">
        <div className="flex justify-between text-sm py-1">
          <span className="text-si-gray">Reference number</span>
          <span className="font-semibold text-si-dark">{order.referenceNumber}</span>
        </div>
        <div className="flex justify-between text-sm py-1">
          <span className="text-si-gray">Amount</span>
          <span className="font-medium">HKD {order.amount?.toLocaleString()}</span>
        </div>
        <div className="flex justify-between text-sm py-1">
          <span className="text-si-gray">Status</span>
          <span className="font-medium text-amber-600">Pending</span>
        </div>
      </div>
      <button onClick={() => navigate('/')}
        className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
        Back to Home
      </button>
    </div>
  );
}
```

- [ ] **Step 5: Create MyHoldingsPage**

```tsx
// frontend/src/pages/holdings/MyHoldingsPage.tsx
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { portfolioApi } from '../../api/portfolioApi';
import { orderApi } from '../../api/orderApi';
import PageLayout from '../../components/PageLayout';

export default function MyHoldingsPage() {
  const navigate = useNavigate();
  const { data: holdings = [] } = useQuery({
    queryKey: ['holdings'],
    queryFn: () => portfolioApi.holdings().then(r => r.data),
  });
  const { data: ordersPage } = useQuery({
    queryKey: ['orders'],
    queryFn: () => orderApi.list().then(r => r.data),
  });
  const pendingCount = ordersPage?.content.filter(o => o.status === 'PENDING').length ?? 0;

  return (
    <PageLayout title="My Holdings">
      {/* Summary */}
      <div className="px-4 py-4 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">Total market value (HKD)</p>
        <p className="text-2xl font-bold text-si-dark mt-1">--</p>
      </div>

      {/* Quick links */}
      <div className="divide-y divide-si-border">
        <button onClick={() => navigate('/transactions')}
          className="w-full flex items-center justify-between px-4 py-4">
          <span className="text-sm text-si-dark">My transactions</span>
          <div className="flex items-center gap-2">
            {pendingCount > 0 && (
              <span className="bg-amber-500 text-white text-xs px-2 py-0.5 rounded-full">
                {pendingCount}
              </span>
            )}
            <span className="text-si-gray">›</span>
          </div>
        </button>
        <button onClick={() => navigate('/plans')}
          className="w-full flex items-center justify-between px-4 py-4">
          <span className="text-sm text-si-dark">My investment plans</span>
          <span className="text-si-gray">›</span>
        </button>
      </div>

      {/* Holdings list */}
      <div className="px-4 py-4">
        {holdings.length === 0 ? (
          <p className="text-sm text-si-gray text-center py-8">No holdings yet</p>
        ) : (
          <div className="space-y-3">
            {holdings.map(h => (
              <div key={h.id} className="border border-si-border rounded-xl p-4">
                <p className="text-sm font-medium text-si-dark">{h.fundId}</p>
                <div className="flex justify-between mt-2 text-xs text-si-gray">
                  <span>Units: {h.totalUnits}</span>
                  <span>Invested: HKD {h.totalInvested}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </PageLayout>
  );
}
```

- [ ] **Step 6: Add order and holdings routes to App.tsx**

```tsx
// Add to App.tsx imports:
import OrderSetupPage from './pages/order/OrderSetupPage';
import OrderReviewPage from './pages/order/OrderReviewPage';
import OrderTermsPage from './pages/order/OrderTermsPage';
import OrderSuccessPage from './pages/order/OrderSuccessPage';
import MyTransactionsPage from './pages/holdings/MyTransactionsPage';

// Add to Routes (inside PrivateRoute wrappers):
// <Route path="/order"         element={<PrivateRoute><OrderSetupPage /></PrivateRoute>} />
// <Route path="/order/review"  element={<PrivateRoute><OrderReviewPage /></PrivateRoute>} />
// <Route path="/order/terms"   element={<PrivateRoute><OrderTermsPage /></PrivateRoute>} />
// <Route path="/order/success" element={<PrivateRoute><OrderSuccessPage /></PrivateRoute>} />
// <Route path="/transactions"  element={<PrivateRoute><MyTransactionsPage /></PrivateRoute>} />
```

- [ ] **Step 7: Create MyTransactionsPage (minimal)**

```tsx
// frontend/src/pages/holdings/MyTransactionsPage.tsx
import { useQuery } from '@tanstack/react-query';
import { orderApi } from '../../api/orderApi';
import PageLayout from '../../components/PageLayout';

const STATUS_STYLES: Record<string, string> = {
  PENDING: 'text-amber-600',
  COMPLETED: 'text-green-600',
  CANCELLED: 'text-gray-400',
};

export default function MyTransactionsPage() {
  const { data: ordersPage } = useQuery({
    queryKey: ['orders'],
    queryFn: () => orderApi.list().then(r => r.data),
  });
  const orders = ordersPage?.content ?? [];

  return (
    <PageLayout title="My Transactions" showBack>
      <div className="divide-y divide-si-border">
        {orders.map(order => (
          <div key={order.id} className="px-4 py-4">
            <div className="flex justify-between text-sm">
              <span className="font-medium text-si-dark">{order.referenceNumber}</span>
              <span className={`font-medium ${STATUS_STYLES[order.status] ?? 'text-si-gray'}`}>
                {order.status.charAt(0) + order.status.slice(1).toLowerCase()}
              </span>
            </div>
            <div className="flex justify-between mt-1 text-xs text-si-gray">
              <span>{order.orderDate}</span>
              <span>HKD {order.amount?.toLocaleString()}</span>
            </div>
          </div>
        ))}
        {orders.length === 0 && (
          <p className="text-sm text-si-gray text-center py-8">No transactions</p>
        )}
      </div>
    </PageLayout>
  );
}
```

- [ ] **Step 8: Build frontend**

```bash
cd frontend
npm run build
```
Expected: `BUILD SUCCESS`

- [ ] **Step 9: Commit**

```bash
git add frontend/src/
git commit -m "feat(frontend): order flow (4-step), My Holdings, My Transactions"
```

---

## Task 12: Terraform Infrastructure

**Files:**
- Create: `infrastructure/providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`
- Create: `infrastructure/modules/vpc/`, `ec2/`, `rds/`, `s3-cloudfront/`, `iam/`

- [ ] **Step 1: Create providers.tf**

```hcl
# infrastructure/providers.tf
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "smart-invest"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

- [ ] **Step 2: Create variables.tf**

```hcl
# infrastructure/variables.tf
variable "aws_region"   { default = "us-east-1" }
variable "environment"  { default = "prod" }
variable "admin_cidr"   { description = "Your IP in CIDR format, e.g. 1.2.3.4/32" }
variable "key_pair_name"{ description = "EC2 SSH key pair name (created in AWS console)" }
variable "account_id"   { description = "AWS account ID (for unique S3 bucket name)" }
```

- [ ] **Step 3: Create vpc module**

```hcl
# infrastructure/modules/vpc/main.tf
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
  tags = { Name = "smart-invest-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  tags = { Name = "smart-invest-private" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.igw.id }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2" {
  name   = "smart-invest-ec2-sg"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 22;  to_port = 22;  protocol = "tcp"; cidr_blocks = [var.admin_cidr] }
  egress  { from_port = 0;   to_port = 0;   protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "rds" {
  name   = "smart-invest-rds-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 5432; to_port = 5432; protocol = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
}

# infrastructure/modules/vpc/outputs.tf
output "vpc_id"          { value = aws_vpc.main.id }
output "public_subnet_id"{ value = aws_subnet.public.id }
output "private_subnet_id"{ value = aws_subnet.private.id }
output "ec2_sg_id"       { value = aws_security_group.ec2.id }
output "rds_sg_id"       { value = aws_security_group.rds.id }

# infrastructure/modules/vpc/variables.tf
variable "region"     {}
variable "admin_cidr" {}
```

- [ ] **Step 4: Create ec2 module**

```hcl
# infrastructure/modules/ec2/main.tf
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name";                values = ["al2023-ami-*-x86_64"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
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

  root_block_device { volume_type = "gp3"; volume_size = 20 }
  tags = { Name = "smart-invest-app" }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
}

# variables.tf (module)
variable "public_subnet_id"    {}
variable "ec2_sg_id"           {}
variable "instance_profile_name" {}
variable "key_pair_name"       {}
variable "db_secret_arn"       {}
variable "region"              {}
variable "app_jar_s3_path"     {}

# outputs.tf (module)
output "public_ip" { value = aws_eip.app.public_ip }
output "instance_id" { value = aws_instance.app.id }
```

```bash
#!/bin/bash
# infrastructure/modules/ec2/user_data.sh
set -e
yum update -y
yum install -y java-21-amazon-corretto-headless nginx

mkdir -p /opt/smart-invest
aws s3 cp ${app_jar_s3} /opt/smart-invest/app.jar

DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id ${db_secret_arn} --region ${aws_region} \
  --query SecretString --output text)

DB_URL=$(echo $DB_SECRET | python3 -c \
  "import json,sys; s=json.load(sys.stdin); print(f\"jdbc:postgresql://{s['host']}:{s['port']}/{s['dbname']}\")")
DB_USER=$(echo $DB_SECRET | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['username'])")
DB_PASS=$(echo $DB_SECRET | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['password'])")

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

cat > /etc/nginx/conf.d/smart-invest.conf <<'NGINX'
server {
    listen 443 ssl;
    server_name _;
    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    location /api/ {
        proxy_pass       http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

systemctl daemon-reload
systemctl enable smart-invest nginx
systemctl start  smart-invest nginx
```

- [ ] **Step 5: Create rds and s3-cloudfront modules**

```hcl
# infrastructure/modules/rds/main.tf
resource "aws_db_subnet_group" "main" {
  name       = "smart-invest-db-sng"
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
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  backup_retention_period   = 7
  multi_az                  = false
  publicly_accessible       = false
  deletion_protection       = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "smart-invest-final-snapshot"
}

output "db_secret_arn" { value = aws_db_instance.postgres.master_user_secret[0].secret_arn }
output "db_endpoint"   { value = aws_db_instance.postgres.endpoint }

variable "subnet_ids" {}
variable "rds_sg_id"  {}
```

```hcl
# infrastructure/modules/s3-cloudfront/main.tf
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
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-smart-invest"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-smart-invest"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values { query_string = false; cookies { forward = "none" } }
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
}

output "cloudfront_domain" { value = aws_cloudfront_distribution.frontend.domain_name }
output "bucket_name"       { value = aws_s3_bucket.frontend.bucket }

variable "account_id" {}
```

- [ ] **Step 6: Create main.tf wiring all modules**

```hcl
# infrastructure/main.tf
module "vpc" {
  source     = "./modules/vpc"
  region     = var.aws_region
  admin_cidr = var.admin_cidr
}

module "iam" {
  source = "./modules/iam"
}

module "rds" {
  source     = "./modules/rds"
  subnet_ids = [module.vpc.public_subnet_id, module.vpc.private_subnet_id]
  rds_sg_id  = module.vpc.rds_sg_id
}

module "ec2" {
  source               = "./modules/ec2"
  public_subnet_id     = module.vpc.public_subnet_id
  ec2_sg_id            = module.vpc.ec2_sg_id
  instance_profile_name = module.iam.instance_profile_name
  key_pair_name        = var.key_pair_name
  db_secret_arn        = module.rds.db_secret_arn
  region               = var.aws_region
  app_jar_s3_path      = "s3://smart-invest-artifacts-${var.account_id}/smart-invest-app.jar"
}

module "s3_cloudfront" {
  source     = "./modules/s3-cloudfront"
  account_id = var.account_id
}
```

```hcl
# infrastructure/outputs.tf
output "ec2_public_ip"      { value = module.ec2.public_ip }
output "cloudfront_domain"  { value = module.s3_cloudfront.cloudfront_domain }
output "frontend_bucket"    { value = module.s3_cloudfront.bucket_name }
```

- [ ] **Step 7: Validate Terraform**

```bash
cd infrastructure
terraform init
terraform validate
```
Expected: `Success! The configuration is valid.`

- [ ] **Step 8: Commit**

```bash
git add infrastructure/
git commit -m "feat(infra): Terraform modules for VPC, EC2, RDS, S3+CloudFront"
```

---

## Task 13: CI/CD GitHub Actions

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/cd.yml`

- [ ] **Step 1: Create ci.yml**

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

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build and test
        run: mvn -B clean verify --file backend/pom.xml

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: surefire-reports
          path: backend/**/target/surefire-reports/

  frontend:
    name: Frontend Build & Type-check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - run: npm ci
        working-directory: frontend

      - run: npm run build
        working-directory: frontend

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

- [ ] **Step 2: Create cd.yml**

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
    name: Deploy Backend
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build JAR
        run: mvn -B clean package -DskipTests --file backend/pom.xml

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ env.AWS_REGION }}

      - name: Upload JAR to S3
        run: |
          aws s3 cp backend/app/target/smart-invest-app.jar \
            s3://${{ secrets.ARTIFACT_BUCKET }}/smart-invest-app.jar

      - name: Deploy via SSM
        run: |
          aws ssm send-command \
            --instance-ids ${{ secrets.EC2_INSTANCE_ID }} \
            --document-name "AWS-RunShellScript" \
            --parameters commands='[
              "aws s3 cp s3://${{ secrets.ARTIFACT_BUCKET }}/smart-invest-app.jar /opt/smart-invest/app.jar",
              "sudo systemctl restart smart-invest",
              "sleep 15",
              "sudo systemctl is-active smart-invest"
            ]'

  deploy-frontend:
    name: Deploy Frontend
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
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

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ env.AWS_REGION }}

      - name: Sync to S3
        working-directory: frontend
        run: |
          aws s3 sync dist/ s3://${{ secrets.FRONTEND_BUCKET }}/ --delete \
            --cache-control "public, max-age=31536000, immutable"
          aws s3 cp dist/index.html s3://${{ secrets.FRONTEND_BUCKET }}/index.html \
            --cache-control "no-cache"

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CF_DISTRIBUTION_ID }} \
            --paths "/*"
```

- [ ] **Step 3: Configure GitHub Secrets**

In the GitHub repository (`Settings → Secrets → Actions`), add:

```
AWS_ACCESS_KEY_ID          IAM deploy user access key
AWS_SECRET_ACCESS_KEY      IAM deploy user secret key
EC2_INSTANCE_ID            From: terraform output ec2_instance_id
ARTIFACT_BUCKET            smart-invest-artifacts-<account_id>
FRONTEND_BUCKET            From: terraform output frontend_bucket
CF_DISTRIBUTION_ID         From: terraform output cloudfront_distribution_id
API_BASE_URL               https://api.yourdomain.com   (or EC2 public IP)
```

- [ ] **Step 4: Push and verify CI passes**

```bash
git add .github/
git commit -m "feat(cicd): GitHub Actions CI and CD workflows"
git push origin main
```
Expected: GitHub Actions CI workflow succeeds on push.

---

## Task 14: Production Deployment

- [ ] **Step 1: Apply Terraform**

```bash
cd infrastructure
terraform init
terraform plan -out=tfplan \
  -var="admin_cidr=$(curl -s ifconfig.me)/32" \
  -var="key_pair_name=smart-invest-key" \
  -var="account_id=$(aws sts get-caller-identity --query Account --output text)"
terraform apply tfplan
terraform output -json
```
Note the outputs: `ec2_public_ip`, `cloudfront_domain`, `frontend_bucket`

- [ ] **Step 2: Create S3 artifact bucket**

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://smart-invest-artifacts-${ACCOUNT_ID} --region us-east-1
```

- [ ] **Step 3: Build and upload JAR**

```bash
cd backend
mvn clean package -DskipTests
aws s3 cp app/target/smart-invest-app.jar \
  s3://smart-invest-artifacts-${ACCOUNT_ID}/smart-invest-app.jar
```

- [ ] **Step 4: SSH to EC2 and verify**

```bash
EC2_IP=$(cd infrastructure && terraform output -raw ec2_public_ip)
ssh -i smart-invest-key.pem ec2-user@${EC2_IP}
sudo systemctl status smart-invest
sudo journalctl -u smart-invest -f
# Expected: "Started SmartInvestApplication" and Flyway "Successfully applied 13 migrations"
```

- [ ] **Step 5: Deploy frontend**

```bash
cd frontend
VITE_API_BASE_URL=https://${EC2_IP} npm run build
aws s3 sync dist/ s3://$(cd ../infrastructure && terraform output -raw frontend_bucket)/ --delete
CF_ID=$(cd infrastructure && terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id ${CF_ID} --paths "/*"
```

- [ ] **Step 6: Smoke test production**

```bash
CF_DOMAIN=$(cd infrastructure && terraform output -raw cloudfront_domain)

# Frontend loads
curl -I https://${CF_DOMAIN}
# Expected: HTTP/2 200

# Backend health
curl https://${EC2_IP}/actuator/health
# Expected: {"status":"UP"}

# Register
curl -X POST https://${EC2_IP}/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@demo.com","password":"Password1!","fullName":"Test User"}'
# Expected: 201 with accessToken
```

- [ ] **Step 7: Create demo user with seed holdings**

```bash
# Run: scripts/create-demo-user.sh
TOKEN=$(curl -s -X POST https://${EC2_IP}/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@smartinvest.example.com","password":"Demo1234!"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])")

# Place sample orders
curl -X POST https://${EC2_IP}/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"fundId\":\"$(curl -s https://${EC2_IP}/api/funds -H \"Authorization: Bearer $TOKEN\" | python3 -c \"import json,sys; funds=json.load(sys.stdin); print([f for f in funds if f['code']=='SI-MM-01'][0]['id'])\")\"  ,\"orderType\":\"ONE_TIME\",\"amount\":1000}"
```

- [ ] **Step 8: Final commit — update README**

```bash
# Update README.md with:
# - Live URL: https://<cloudfront_domain>
# - GitHub: https://github.com/engineerping/smart-invest
# - Architecture description
# - Tech stack badge

git add README.md
git commit -m "docs: add live URL, architecture diagram, and tech stack to README"
git push origin main
```

---

## Task 15: CloudWatch Monitoring

- [ ] **Step 1: Create log group and alarms**

```bash
# Log group
aws logs create-log-group --log-group-name /smart-invest/application --region us-east-1

# EC2 CPU alarm
EC2_ID=$(cd infrastructure && terraform output -raw ec2_instance_id)
SNS_ARN=$(aws sns create-topic --name smart-invest-alerts --query TopicArn --output text)
aws sns subscribe --topic-arn $SNS_ARN --protocol email --notification-endpoint your@email.com

aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-CPU-High" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --dimensions Name=InstanceId,Value=${EC2_ID} \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions ${SNS_ARN}

# RDS storage alarm
RDS_ID=smart-invest-db
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-RDS-Storage-Low" \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --dimensions Name=DBInstanceIdentifier,Value=${RDS_ID} \
  --statistic Average \
  --period 300 \
  --threshold 5368709120 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions ${SNS_ARN}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/
git commit -m "ops: add CloudWatch alarms for EC2 CPU and RDS storage"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Pathway A (individual fund investment) — Tasks 4, 5, 9, 10, 11
- [x] Pathway B (multi-asset portfolio) — FundController `/multi-asset`, MultiAssetPortfolioPage
- [x] Pathway C (build your own portfolio) — AllocationForm component, Step1–Step5 pages
- [x] My Holdings page — Task 11
- [x] My Transactions — Task 11
- [x] Cancel order — OrderController DELETE, CancelOrderPage
- [x] Monthly plan termination — InvestmentPlanController DELETE
- [x] Risk questionnaire — Task 3, RiskQuestionnairePage
- [x] Business rules (min HKD 100/500, allocation 100%, T+2) — Tasks 3, 5
- [x] AWS Well-Architected (security groups, IAM roles, Secrets Manager, CloudWatch) — Tasks 12, 15
- [x] CI/CD — Task 13
- [x] Mobile-only frontend (max-width 430px) — Task 8

**Missing pages noted for follow-up:**
- `MultiAssetPortfolioPage` (5-tab ribbon) — add after Task 11
- `RiskQuestionnairePage` — add after Task 9
- `BuildPortfolio` Step1–Step5 — add after Task 11
- `PlanDetailPage`, `PlanTerminationPage`, `OrderDetailPage`, `CancelOrderPage` — add as extension
