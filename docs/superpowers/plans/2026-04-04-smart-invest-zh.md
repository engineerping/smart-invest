# Smart Invest 实施计划（中文版）

> **适用于 AI 执行者：** 必须使用子技能：superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务执行本计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 构建生产级移动端投资平台 Smart Invest，参照 Smart Invest 用户指南，使用 Spring Boot 后端 + React 移动端前端，部署于 AWS。

**架构：** 模块化单体 Spring Boot 应用部署于单台 EC2 t3.small；React SPA 托管于 S3+CloudFront；PostgreSQL 16 部署于 RDS db.t3.micro。Flyway 管理数据库迁移；JWT 负责身份认证；GitHub Actions CI/CD 通过 SSM 自动化部署。

**技术栈：** Java 21 · Spring Boot 3.3 · React 18 + TypeScript + Vite · Tailwind CSS · PostgreSQL 16 · Flyway · Terraform 1.9 · AWS（EC2、RDS、S3、CloudFront、SES、Secrets Manager、CloudWatch）

---

## 文件结构

```
smart-invest/
├── docker-compose.yml
├── backend/
│   ├── pom.xml                          Maven 根聚合 POM
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
│   │       ├── dto/（RegisterRequest, LoginRequest, AuthResponse, RiskSubmitRequest 等）
│   │       └── security/JwtTokenProvider.java, JwtFilter.java, SecurityConfig.java
│   ├── module-fund/
│   │   └── src/main/java/com/smartinvest/fund/
│   │       ├── domain/Fund.java, FundNavHistory.java, FundAssetAllocation.java …
│   │       ├── repository/（每个领域类各一个）
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

## 任务 1：仓库与开发环境初始化

**涉及文件：**

- 创建：`docker-compose.yml`

- 创建：`backend/pom.xml`

- 创建：`backend/app/src/main/resources/application.yml`

- 创建：`backend/app/src/main/resources/application-local.yml`

- 创建：`backend/app/src/main/java/com/smartinvest/SmartInvestApplication.java`

- [ ] **步骤 1：验证工具版本**

```bash
java --version    # 必须显示 openjdk 21
mvn --version     # 必须显示 3.9+
node --version    # 必须显示 v20
docker --version  # 任意近期版本
terraform --version  # 必须显示 1.9+
aws --version     # aws-cli/2.x
```

- [ ] **步骤 2：在仓库根目录创建 docker-compose.yml**

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

- [ ] **步骤 3：启动数据库**

```bash
docker compose up -d postgres
docker compose ps    # 预期：smart-invest-db   Up (healthy)
```

- [ ] **步骤 4：创建 backend/pom.xml**

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

- [ ] **步骤 5：创建 application.yml**

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

- [ ] **步骤 6：创建 application-local.yml**

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

- [ ] **步骤 7：创建 SmartInvestApplication.java**

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

- [ ] **步骤 8：验证项目编译成功**

```bash
cd backend
mvn clean compile -pl app -am
```

预期：`BUILD SUCCESS`

- [ ] **步骤 9：提交**

```bash
git add docker-compose.yml backend/pom.xml backend/app/
git commit -m "chore: 初始化项目结构和开发环境"
```

---

## 任务 2：数据库迁移（Flyway）

**涉及文件：**

- 创建：`backend/app/src/main/resources/db/migration/V1__create_users.sql` 至 `V13__seed_funds.sql`

- [ ] **步骤 1：创建 V1__create_users.sql**

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

- [ ] **步骤 2：创建 V2__create_risk_assessments.sql**

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

- [ ] **步骤 3：创建 V3__create_funds.sql**

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

- [ ] **步骤 4：创建 V4 至 V9**

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

-- V5__create_fund_asset_allocations.sql
CREATE TABLE fund_asset_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    asset_class VARCHAR(50)  NOT NULL,
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
    sequence     SMALLINT     NOT NULL
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
CREATE TABLE reference_asset_mix (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    risk_level  SMALLINT     NOT NULL,
    asset_class VARCHAR(50)  NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL
);
```

- [ ] **步骤 5：创建 V10 至 V12**

```sql
-- V10__create_orders.sql
CREATE TABLE orders (
    id                 UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number   VARCHAR(30)   UNIQUE NOT NULL,
    user_id            UUID          NOT NULL REFERENCES users(id),
    fund_id            UUID          NOT NULL REFERENCES funds(id),
    order_type         VARCHAR(20)   NOT NULL,         -- ONE_TIME | MONTHLY_PLAN
    investment_type    VARCHAR(20)   NOT NULL,         -- BUY
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

- [ ] **步骤 6：创建 V13__seed_funds.sql**

```sql
INSERT INTO funds (code, isin_class, name, fund_type, risk_level, annual_mgmt_fee, benchmark_index, market_focus, min_investment) VALUES
('SI-MM-01', 'CLASS D-ACC',    'Smart Invest Global Money Funds - Hong Kong Dollar',             'MONEY_MARKET', 1, 0.0031, NULL,                                          '香港货币市场工具',  100.00),
('SI-BI-01', 'CLASS HC-HKD-ACC','Smart Invest Global Aggregate Bond Index Fund',                'BOND_INDEX',   1, 0.0025, 'Bloomberg Global Aggregate Bond Index',        '全球投资级债券',   100.00),
('SI-BI-02', 'CLASS HC-HKD-ACC','Smart Invest Global Corporate Bond Index Fund',                'BOND_INDEX',   2, 0.0031, 'Bloomberg Global Corporate Bond Index',        '全球投资级企业债', 100.00),
('SI-EI-01', 'CLASS HC-HKD-ACC','Smart Invest US Equity Index Fund',                           'EQUITY_INDEX', 4, 0.0031, 'S&P 500 Net Total Return Index',               '美国股市（纽交所+纳斯达克前500）', 100.00),
('SI-EI-02', 'CLASS HC-HKD-ACC','Smart Invest Global Equity Index Fund',                       'EQUITY_INDEX', 4, 0.0040, 'MSCI World Index',                             '全球发达市场',    100.00),
('SI-EI-03', 'CLASS HC-HKD-ACC','Smart Invest Hang Seng Index Fund',                           'EQUITY_INDEX', 5, 0.0050, 'Hang Seng Index',                              '香港股票市场',    100.00),
('SI-MA-01', 'CLASS BC-HKD-ACC','Smart Invest Portfolios - World Selection 1 (Conservative)',  'MULTI_ASSET',  1, 0.0060, NULL,                                          '多元保守型',      100.00),
('SI-MA-02', 'CLASS BC-HKD-ACC','Smart Invest Portfolios - World Selection 2 (Moderately Conservative)','MULTI_ASSET',2, 0.0060, NULL,                                    '多元稳健偏保守型', 100.00),
('SI-MA-03', 'CLASS BC-HKD-ACC','Smart Invest Portfolios - World Selection 3 (Balanced)',      'MULTI_ASSET',  3, 0.0060, NULL,                                          '多元均衡型',      100.00),
('SI-MA-04', 'CLASS BC-HKD-ACC','Smart Invest Portfolios - World Selection 4 (Adventurous)',   'MULTI_ASSET',  4, 0.0060, NULL,                                          '多元进取型',      100.00),
('SI-MA-05', 'CLASS BC-HKD-ACC','Smart Invest Portfolios - World Selection 5 (Speculative)',   'MULTI_ASSET',  5, 0.0060, NULL,                                          '多元激进型',      100.00);
```

- [ ] **步骤 7：启动应用并验证迁移**

```bash
cd backend
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/smartinvest \
SPRING_DATASOURCE_USERNAME=smartadmin \
SPRING_DATASOURCE_PASSWORD=localdev_only \
SPRING_PROFILES_ACTIVE=local \
JWT_SECRET=local-dev-secret-key-minimum-256-bits-long-padded-here \
mvn spring-boot:run -pl app -am
```

日志中预期输出：`Successfully applied 13 migrations`

- [ ] **步骤 8：验证种子数据**

```bash
docker exec -it smart-invest-db psql -U smartadmin -d smartinvest \
  -c "SELECT code, name, fund_type FROM funds ORDER BY fund_type, risk_level;"
```

预期：11 行数据

- [ ] **步骤 9：提交**

```bash
git add backend/app/src/main/resources/db/
git commit -m "feat: 添加 Flyway V1-V13 迁移及基金种子数据"
```

---

## 任务 3：module-user — 认证、JWT、风险问卷

**涉及文件：** `backend/module-user/src/main/java/com/smartinvest/user/`

- [ ] **步骤 1：编写 RiskService 的失败测试**

```java
// backend/module-user/src/test/java/com/smartinvest/user/service/RiskServiceTest.java
package com.smartinvest.user.service;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class RiskServiceTest {
    private final RiskService riskService = new RiskService(null, null);

    @Test void score9_isConservative()  { assertThat(riskService.scoreToLevel(9)).isEqualTo(1); }
    @Test void score10_isModerate()     { assertThat(riskService.scoreToLevel(10)).isEqualTo(2); }
    @Test void score16_isBalanced()     { assertThat(riskService.scoreToLevel(16)).isEqualTo(3); }
    @Test void score21_isAdventurous()  { assertThat(riskService.scoreToLevel(21)).isEqualTo(4); }
    @Test void score26_isSpeculative()  { assertThat(riskService.scoreToLevel(26)).isEqualTo(5); }
}
```

- [ ] **步骤 2：运行测试 — 预期失败**

```bash
cd backend
mvn test -pl module-user -Dtest=RiskServiceTest
```

预期：编译错误（类尚未存在）

- [ ] **步骤 3：创建 User 领域类**

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

- [ ] **步骤 4：创建 JwtTokenProvider**

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
                .subject(email).issuedAt(now)
                .expiration(new Date(now.getTime() + accessTokenExpiryMs))
                .signWith(key).compact();
    }

    public String getEmailFromToken(String token) {
        return Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload().getSubject();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser().verifyWith(key).build().parseSignedClaims(token);
            return true;
        } catch (JwtException e) { return false; }
    }
}
```

- [ ] **步骤 5：创建 SecurityConfig**

```java
// backend/module-user/src/main/java/com/smartinvest/user/security/SecurityConfig.java
package com.smartinvest.user.security;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.*;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.*;
import java.util.List;

@Configuration @RequiredArgsConstructor
public class SecurityConfig {
    private final JwtFilter jwtFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(c -> c.disable())
            .cors(c -> c.configurationSource(corsConfigurationSource()))
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**", "/actuator/health",
                                 "/swagger-ui/**", "/v3/api-docs/**").permitAll()
                .anyRequest().authenticated())
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean public PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(); }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration cfg) throws Exception {
        return cfg.getAuthenticationManager();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration cfg = new CorsConfiguration();
        cfg.setAllowedOriginPatterns(List.of("*"));
        cfg.setAllowedMethods(List.of("GET","POST","PUT","DELETE","OPTIONS"));
        cfg.setAllowedHeaders(List.of("*"));
        cfg.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource src = new UrlBasedCorsConfigurationSource();
        src.registerCorsMapping("/**", cfg);
        return src;
    }
}
```

- [ ] **步骤 6：创建 RiskService（实现 scoreToLevel）**

```java
// backend/module-user/src/main/java/com/smartinvest/user/service/RiskService.java
package com.smartinvest.user.service;

import com.smartinvest.user.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.*;

@Service @RequiredArgsConstructor
public class RiskService {
    private final Object riskAssessmentRepository;  // 替换为 RiskAssessmentRepository
    private final Object userRepository;            // 替换为 UserRepository

    /** 将总分（0–30）转换为风险等级（1–5）。 */
    public int scoreToLevel(int totalScore) {
        if (totalScore <= 9)  return 1;   // 保守型
        if (totalScore <= 15) return 2;   // 稳健型
        if (totalScore <= 20) return 3;   // 平衡型
        if (totalScore <= 25) return 4;   // 进取型
        return 5;                          // 激进型
    }

    public Map<String, Object> getQuestionnaire() {
        return Map.of("questions", List.of(
            Map.of("id",1,"text","您的主要投资目标是什么？","options", List.of(
                Map.of("id","A","text","保全本金","score",1),
                Map.of("id","B","text","稳定收益","score",2),
                Map.of("id","C","text","收益与增长平衡","score",3),
                Map.of("id","D","text","长期增长","score",4),
                Map.of("id","E","text","最大化增长/投机","score",5))),
            Map.of("id",2,"text","您的投资期限是多久？","options", List.of(
                Map.of("id","A","text","不足1年","score",1),
                Map.of("id","B","text","1–3年","score",2),
                Map.of("id","C","text","3–5年","score",3),
                Map.of("id","D","text","5–10年","score",4),
                Map.of("id","E","text","超过10年","score",5)))
        ));
    }
}
```

- [ ] **步骤 7：运行测试 — 预期通过**

```bash
cd backend
mvn test -pl module-user -Dtest=RiskServiceTest
```

预期：`Tests run: 5, Failures: 0, Errors: 0`

- [ ] **步骤 8：接口冒烟测试**

```bash
# 注册
curl -s -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Password1!","fullName":"演示用户"}' | jq .
# 预期：{"accessToken":"eyJ...","tokenType":"Bearer"}

# 登录
curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Password1!"}' | jq .
# 预期：{"accessToken":"eyJ...","tokenType":"Bearer"}
```

- [ ] **步骤 9：提交**

```bash
git add backend/module-user/
git commit -m "feat(user): 添加 JWT 认证、注册登录、风险问卷"
```

---

## 任务 4：module-fund — 基金目录与 NAV 接口

**涉及文件：** `backend/module-fund/src/main/java/com/smartinvest/fund/`

- [ ] **步骤 1：创建 Fund 领域类和 Repository**

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
    String code; String isinClass; String name; String fundType;
    short riskLevel; String currency; BigDecimal currentNav; LocalDate navDate;
    BigDecimal annualMgmtFee; BigDecimal minInvestment;
    String benchmarkIndex; String marketFocus;
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
}
```

- [ ] **步骤 2：创建 FundService 和 FundController**

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/service/FundService.java
package com.smartinvest.fund.service;

import com.smartinvest.fund.domain.*;
import com.smartinvest.fund.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.*;

@Service @RequiredArgsConstructor
public class FundService {
    private final FundRepository fundRepository;
    private final FundNavHistoryRepository navHistoryRepository;

    public List<Fund> getAllFunds(String type, Short riskLevel) {
        List<Fund> funds = type != null
            ? fundRepository.findByFundTypeAndIsActiveTrue(type)
            : fundRepository.findByIsActiveTrue();
        if (riskLevel != null) funds = funds.stream().filter(f -> f.getRiskLevel() == riskLevel).toList();
        return funds;
    }

    public Fund getFundById(UUID id) {
        return fundRepository.findById(id).orElseThrow(() -> new NoSuchElementException("基金不存在: " + id));
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
            default   -> LocalDate.now().minusMonths(3);
        };
        return navHistoryRepository.findByFundIdAndNavDateAfterOrderByNavDateAsc(fundId, from);
    }
}
```

```java
// backend/module-fund/src/main/java/com/smartinvest/fund/controller/FundController.java
package com.smartinvest.fund.controller;

import com.smartinvest.fund.domain.*;
import com.smartinvest.fund.service.FundService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController @RequestMapping("/api/funds") @RequiredArgsConstructor
public class FundController {
    private final FundService fundService;

    @GetMapping
    public ResponseEntity<List<Fund>> list(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) Short riskLevel) {
        return ResponseEntity.ok(fundService.getAllFunds(type, riskLevel));
    }

    @GetMapping("/multi-asset")
    public ResponseEntity<List<Fund>> multiAsset() { return ResponseEntity.ok(fundService.getMultiAssetFunds()); }

    @GetMapping("/{id}")
    public ResponseEntity<Fund> get(@PathVariable UUID id) { return ResponseEntity.ok(fundService.getFundById(id)); }

    @GetMapping("/{id}/nav-history")
    public ResponseEntity<List<FundNavHistory>> navHistory(
            @PathVariable UUID id, @RequestParam(defaultValue = "3M") String period) {
        return ResponseEntity.ok(fundService.getNavHistory(id, period));
    }
}
```

- [ ] **步骤 3：冒烟测试**

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Password1!"}' | jq -r .accessToken)

curl -s http://localhost:8080/api/funds -H "Authorization: Bearer $TOKEN" | jq 'length'
# 预期：11
```

- [ ] **步骤 4：提交**

```bash
git add backend/module-fund/
git commit -m "feat(fund): 添加基金目录和 NAV 历史接口"
```

---

## 任务 5：module-order — 下单与取消

- [ ] **步骤 1：编写失败测试**

```java
// backend/module-order/src/test/java/com/smartinvest/order/service/OrderReferenceGeneratorTest.java
package com.smartinvest.order.service;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class OrderReferenceGeneratorTest {
    private final OrderReferenceGenerator gen = new OrderReferenceGenerator();

    @Test void oneTimeRef_matchesPattern()    { assertThat(gen.generate("ONE_TIME")).matches("P-\\d{6}"); }
    @Test void monthlyPlanRef_matchesPattern() { assertThat(gen.generate("MONTHLY_PLAN")).matches("\\d{17}"); }
}
```

- [ ] **步骤 2：创建 OrderReferenceGenerator**

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
            return "P-" + String.format("%06d", ThreadLocalRandom.current().nextInt(100_000, 999_999));
        }
        return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
            + String.format("%03d", ThreadLocalRandom.current().nextInt(0, 999));
    }
}
```

- [ ] **步骤 3：创建 SettlementDateCalculator 及其测试**

```java
// 测试：
// monday + 2 = wednesday
// friday + 2（跳过周末）= tuesday

// 实现：
@Component
public class SettlementDateCalculator {
    public LocalDate calculate(LocalDate from, int businessDays) {
        LocalDate date = from;
        int count = 0;
        while (count < businessDays) {
            date = date.plusDays(1);
            DayOfWeek dow = date.getDayOfWeek();
            if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) count++;
        }
        return date;
    }
}
```

- [ ] **步骤 4：运行所有测试**

```bash
mvn test -pl module-order
```

预期：全部通过

- [ ] **步骤 5：创建 OrderService 和 OrderController（参见英文版任务 5 步骤 8–9）**

- [ ] **步骤 6：提交**

```bash
git add backend/module-order/
git commit -m "feat(order): 添加下单和取消功能"
```

---

## 任务 6–7：module-portfolio、module-plan、调度器、通知

> 参见英文版任务 6 和 7 中的完整代码。以下为关键类清单：

- [ ] **Holding.java**、**HoldingRepository.java**、**PortfolioService.java**、**PortfolioController.java**

- [ ] **InvestmentPlan.java**、**InvestmentPlanRepository.java**、**InvestmentPlanService.java**、**InvestmentPlanController.java**

- [ ] **MonthlyInvestmentScheduler.java**（每日 01:00 HKT 执行月供计划）

- [ ] **EmailNotificationService.java**（通过 Amazon SES 发送邮件）

- [ ] **步骤：构建并测试**

```bash
cd backend
mvn clean verify
```

预期：`BUILD SUCCESS`

- [ ] **步骤：提交**

```bash
git add backend/module-portfolio/ backend/module-plan/ backend/module-scheduler/ backend/module-notification/
git commit -m "feat(portfolio,plan,scheduler,notification): 完整后端模块"
```

---

## 任务 8：前端 — 项目初始化

- [ ] **步骤 1：创建 Vite 项目**

```bash
npm create vite@latest frontend -- --template react-ts
cd frontend && npm install
```

- [ ] **步骤 2：安装依赖**

```bash
npm install react-router-dom@6 zustand@4 @tanstack/react-query@5 \
  axios recharts@2 lucide-react tailwindcss@3 postcss autoprefixer
npx tailwindcss init -p
```

- [ ] **步骤 3：配置 tailwind.config.js**

```js
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
    },
  },
};
```

- [ ] **步骤 4：src/index.css 中加入 Tailwind 指令**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

* { -webkit-tap-highlight-color: transparent; }
body { max-width: 430px; margin: 0 auto; background: #fff; }
```

- [ ] **步骤 5：index.html 中设置移动端 viewport**

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0,
      maximum-scale=1.0, user-scalable=no" />
```

- [ ] **步骤 6：创建 TypeScript 类型定义**

> 参见英文版任务 8 步骤 6 中的 `frontend/src/types/index.ts`，包含 `AuthResponse`、`User`、`Fund`、`NavDataPoint`、`Order`、`Holding`、`InvestmentPlan`。

- [ ] **步骤 7：创建 API 客户端和认证 Store**

> 参见英文版任务 8 步骤 7 中的 `frontend/src/api/client.ts`、`authApi.ts`、`store/authStore.ts`。

- [ ] **步骤 8：验证构建**

```bash
cd frontend && npm run build
```

预期：构建成功，无 TypeScript 错误

- [ ] **步骤 9：提交**

```bash
git add frontend/
git commit -m "feat(frontend): React + Tailwind + Zustand + React Query 基础框架"
```

---

## 任务 9–11：前端页面

> 完整代码参见英文版任务 9、10、11。以下为创建的页面清单：

**任务 9：认证页面和首页**

- [ ] `LoginPage.tsx` — 邮箱/密码登录，错误提示
- [ ] `RegisterPage.tsx` — 注册表单（姓名、邮箱、密码 ≥ 8 位）
- [ ] `SmartInvestHomePage.tsx` — 总市值、基金分类入口（货币市场/债券/股票/多资产/自建组合）
- [ ] `PageLayout.tsx` — 含顶部标题栏和返回按钮的通用布局

**任务 10：基金列表与详情**

- [ ] `RiskGauge.tsx` — 0–5 彩色风险条，双指示器（产品风险 ▼ / 用户风险 ▲）
- [ ] `NavChart.tsx` — 3M/6M/1Y/3Y/5Y 切换的累计收益折线图（Recharts）
- [ ] `FundListPage.tsx` — 支持按类型筛选，显示 NAV 和风险等级
- [ ] `FundDetailPage.tsx` — 含概览/持仓/风险三个 Tab，"立即投资"固定底部按钮

**任务 11：下单流程与持仓**

- [ ] `OrderSetupPage.tsx` — 一次性/月供切换，金额输入（最低 HKD 100）

- [ ] `OrderReviewPage.tsx` — 展示基金名称、金额、结算日（T+2）

- [ ] `OrderTermsPage.tsx` — 条款确认后调用后端下单

- [ ] `OrderSuccessPage.tsx` — 显示订单参考号和待处理状态

- [ ] `MyHoldingsPage.tsx` — 总市值、我的交易（带待处理数量徽章）、我的月供计划

- [ ] `MyTransactionsPage.tsx` — 按状态显示（待处理/已完成/已取消），颜色区分

- [ ] **步骤：各页面完成后构建验证**

```bash
cd frontend && npm run build
```

预期：无错误

- [ ] **步骤：Chrome 移动端视图验证**

```bash
cd frontend
VITE_API_BASE_URL=http://localhost:8080 npm run dev
```

打开 Chrome → F12 → 设备工具栏 → 选择 iPhone 14（390×844）  
预期：所有页面在移动端视口内正确渲染

- [ ] **步骤：提交**

```bash
git add frontend/src/
git commit -m "feat(frontend): 完整前端页面（认证/基金/下单/持仓）"
```

---

## 任务 12：Terraform 基础设施

> 完整 HCL 代码参见英文版任务 12。以下为模块结构：

```
infrastructure/
├── providers.tf    # AWS provider，region 变量
├── main.tf         # 调用 vpc、ec2、rds、s3-cloudfront、iam 模块
├── variables.tf    # aws_region, environment, admin_cidr, key_pair_name, account_id
├── outputs.tf      # ec2_public_ip, cloudfront_domain, frontend_bucket
└── modules/
    ├── vpc/        # VPC、公有/私有子网、安全组（EC2 + RDS）
    ├── ec2/        # t3.small 实例、弹性 IP、systemd 启动脚本
    ├── rds/        # PostgreSQL 16 db.t3.micro，凭证存 Secrets Manager
    ├── s3-cloudfront/  # 私有 S3 桶、CloudFront OAC 分发、SPA 404 回退
    └── iam/        # EC2 实例角色（secretsmanager, ses, cloudwatch, s3）
```

- [ ] **步骤：验证 Terraform**

```bash
cd infrastructure
terraform init
terraform validate
```

预期：`Success! The configuration is valid.`

- [ ] **步骤：提交**

```bash
git add infrastructure/
git commit -m "feat(infra): Terraform 模块（VPC/EC2/RDS/S3+CloudFront）"
```

---

## 任务 13：CI/CD（GitHub Actions）

> 完整 YAML 参见英文版任务 13。

- [ ] **步骤 1：创建 .github/workflows/ci.yml**

触发条件：对 main/develop 的 PR  
作业：

1. `backend` — `mvn clean verify`（Java 21）

2. `frontend` — `npm ci && npm run build`（Node 20）

3. `terraform-validate` — `terraform validate`
- [ ] **步骤 2：创建 .github/workflows/cd.yml**

触发条件：推送到 main  
作业：

1. `deploy-backend` — 构建 JAR → 上传 S3 → SSM 重启服务

2. `deploy-frontend` — `npm run build` → `aws s3 sync` → CloudFront 失效
- [ ] **步骤 3：配置 GitHub Secrets**

```
AWS_ACCESS_KEY_ID          IAM 部署用户 Access Key
AWS_SECRET_ACCESS_KEY      IAM 部署用户 Secret Key
EC2_INSTANCE_ID            terraform output ec2_instance_id
ARTIFACT_BUCKET            smart-invest-artifacts-<account_id>
FRONTEND_BUCKET            terraform output frontend_bucket
CF_DISTRIBUTION_ID         terraform output cloudfront_distribution_id
API_BASE_URL               https://api.yourdomain.com
```

- [ ] **步骤 4：推送并验证 CI 通过**

```bash
git add .github/
git commit -m "feat(cicd): GitHub Actions CI 和 CD 工作流"
git push origin main
```

预期：GitHub Actions CI 通过

---

## 任务 14：生产部署

- [ ] **步骤 1：执行 Terraform**

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

记录输出：`ec2_public_ip`、`cloudfront_domain`、`frontend_bucket`

- [ ] **步骤 2：创建制品 S3 存储桶**

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://smart-invest-artifacts-${ACCOUNT_ID} --region us-east-1
```

- [ ] **步骤 3：构建并上传 JAR**

```bash
cd backend
mvn clean package -DskipTests
aws s3 cp app/target/smart-invest-app.jar \
  s3://smart-invest-artifacts-${ACCOUNT_ID}/smart-invest-app.jar
```

- [ ] **步骤 4：SSH 登录 EC2 验证**

```bash
EC2_IP=$(cd infrastructure && terraform output -raw ec2_public_ip)
ssh -i smart-invest-key.pem ec2-user@${EC2_IP}
sudo systemctl status smart-invest
# 预期：active (running)
sudo journalctl -u smart-invest -f
# 预期日志：Started SmartInvestApplication，Flyway applied 13 migrations
```

- [ ] **步骤 5：部署前端**

```bash
cd frontend
VITE_API_BASE_URL=https://${EC2_IP} npm run build
aws s3 sync dist/ s3://$(cd ../infrastructure && terraform output -raw frontend_bucket)/ --delete
CF_ID=$(cd infrastructure && terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id ${CF_ID} --paths "/*"
```

- [ ] **步骤 6：生产环境冒烟测试**

```bash
CF_DOMAIN=$(cd infrastructure && terraform output -raw cloudfront_domain)

# 前端可访问
curl -I https://${CF_DOMAIN}
# 预期：HTTP/2 200

# 后端健康检查
curl https://${EC2_IP}/actuator/health
# 预期：{"status":"UP"}

# 注册
curl -X POST https://${EC2_IP}/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@demo.com","password":"Password1!","fullName":"测试用户"}'
# 预期：201 含 accessToken
```

- [ ] **步骤 7：更新 README 并最终提交**

```bash
# 更新 README.md：
# - 在线演示地址：https://<cloudfront_domain>
# - GitHub 地址：https://github.com/engineerping/smart-invest
# - 架构图、技术栈徽章

git add README.md
git commit -m "docs: 添加在线演示地址、架构图和技术栈说明"
git push origin main
```

---

## 任务 15：CloudWatch 监控

- [ ] **步骤：创建日志组和告警**

```bash
# 创建日志组
aws logs create-log-group --log-group-name /smart-invest/application --region us-east-1

# 创建 SNS 话题
SNS_ARN=$(aws sns create-topic --name smart-invest-alerts --query TopicArn --output text)
aws sns subscribe --topic-arn $SNS_ARN --protocol email --notification-endpoint your@email.com

# EC2 CPU 告警（>80%，5分钟均值，连续2次）
EC2_ID=$(cd infrastructure && terraform output -raw ec2_instance_id)
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-CPU-High" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --dimensions Name=InstanceId,Value=${EC2_ID} \
  --statistic Average --period 300 --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions ${SNS_ARN}

# RDS 存储空间告警（<5GB）
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-RDS-Storage-Low" \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --dimensions Name=DBInstanceIdentifier,Value=smart-invest-db \
  --statistic Average --period 300 --threshold 5368709120 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions ${SNS_ARN}
```

- [ ] **步骤：提交**

```bash
git commit -m "ops: 添加 EC2 CPU 和 RDS 存储 CloudWatch 告警"
```

---

## 项目周期规划（参考）

| 周次  | 交付物                                            | 里程碑         |
| --- | ---------------------------------------------- | ----------- |
| 0   | 工具安装、仓库初始化、Terraform 框架、docker-compose         | ✓ 开发环境就绪    |
| 1–2 | AWS 基础设施（VPC、EC2、RDS、S3、CloudFront）            | ✓ 云环境就绪     |
| 2–3 | module-user（注册、登录、JWT、风险问卷）                    | ✓ 认证完成      |
| 3–4 | module-fund（基金目录、NAV 历史、资产配置、种子数据）             | ✓ 基金数据就绪    |
| 4   | module-order（单只基金下单、组合批量下单、取消）                 | ✓ 核心交易流程    |
| 5   | module-plan（月供计划 CRUD、终止流程）                    | ✓ 投资计划完成    |
| 5   | module-portfolio（持仓计算、未实现盈亏、总市值）               | ✓ 持仓视图完成    |
| 5–6 | 前端 — 认证页面、Smart Invest 首页、基金列表（筛选）             | ✓ 前端基础完成    |
| 6–7 | 前端 — 基金详情（NAV 图、风险条）、完整下单流程                    | ✓ 完整投资流程    |
| 7   | 前端 — 我的持仓、我的交易、我的月供计划、取消功能                     | ✓ 功能全覆盖     |
| 8   | module-scheduler + module-notification（SES 邮件） | ✓ 自动化完成     |
| 9   | CI/CD 流水线、GitHub Actions、EC2 systemd 自动部署      | ✓ DevOps 就绪 |
| 10  | 端到端测试、CloudWatch 告警、结构化日志                      | ✓ 可观测性完成    |
| 11  | 生产部署、HTTPS 配置、域名绑定、演示数据填充                      | ✓ **上线**    |
| 12  | README、架构图、项目文档                                | ✓ 仓库完备      |

---

## 自检清单

**规格覆盖度：**

- [x] 投资路径 A（单只基金）— 任务 4、5、9、10、11
- [x] 投资路径 B（多资产组合 5-Tab）— FundController `/multi-asset`、MultiAssetPortfolioPage
- [x] 投资路径 C（自建组合，风险 4-5 专属）— AllocationForm、Step1–Step5 页面
- [x] 我的持仓页面 — 任务 11
- [x] 我的交易记录 — 任务 11
- [x] 取消订单 — OrderController DELETE、CancelOrderPage
- [x] 月供计划终止 — InvestmentPlanController DELETE
- [x] 风险问卷 — 任务 3、RiskQuestionnairePage
- [x] 业务规则（最低 HKD 100/500、配置合计 100%、T+2）— 任务 3、5
- [x] AWS Well-Architected（安全组、IAM、Secrets Manager、CloudWatch）— 任务 12、15
- [x] CI/CD — 任务 13
- [x] 仅移动端前端（max-width: 430px）— 任务 8
