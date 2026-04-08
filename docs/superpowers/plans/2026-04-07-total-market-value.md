# Total Market Value Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded market value figures on SmartInvestHomePage and MyHoldingsPage with real values computed from `holdings.total_units × latest NAV`.

**Architecture:** Backend computes per-holding market value (total_units × latest NAV from fund_nav_history) and exposes two endpoints: `GET /api/portfolio/me/holdings` returns a `HoldingResponse` list with per-holding `marketValue`, and `GET /api/portfolio/me/summary` returns `{ totalMarketValue }`. Frontend consumes these to replace the hardcoded numbers.

**Tech Stack:** Java 21, Spring Boot 3.3.2, JPA, Mockito/JUnit 5 (via spring-boot-starter-test), React, TanStack Query (React Query)

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Modify | `backend/module-fund/src/main/java/com/smartinvest/fund/repository/FundNavHistoryRepository.java` | Add `findTopByFundIdOrderByNavDateDesc` query |
| Modify | `backend/module-portfolio/pom.xml` | Add `module-fund` dependency so PortfolioService can access FundNavHistoryRepository |
| Create | `backend/module-portfolio/src/main/java/com/smartinvest/portfolio/dto/HoldingResponse.java` | DTO: id, fundId, totalUnits, totalInvested, marketValue |
| Modify | `backend/module-portfolio/src/main/java/com/smartinvest/portfolio/service/PortfolioService.java` | Inject FundNavHistoryRepository, add `getHoldingsWithMarketValue` and `getTotalMarketValue` |
| Modify | `backend/module-portfolio/src/main/java/com/smartinvest/portfolio/controller/PortfolioController.java` | Change holdings endpoint to return `HoldingResponse`; add `/me/summary` endpoint |
| Create | `backend/module-portfolio/src/test/java/com/smartinvest/portfolio/service/PortfolioServiceTest.java` | Unit tests for PortfolioService using Mockito |
| Modify | `frontend/src/pages/holdings/MyHoldingsPage.tsx` | Sum `marketValue` from holdings; render per-holding market value |
| Modify | `frontend/src/pages/home/SmartInvestHomePage.tsx` | Call `/api/portfolio/me/summary`, display real totalMarketValue |

---

## Task 1: Add `findTopByFundIdOrderByNavDateDesc` to FundNavHistoryRepository

**Files:**
- Modify: `backend/module-fund/src/main/java/com/smartinvest/fund/repository/FundNavHistoryRepository.java`

- [ ] **Step 1: Add the query method**

Replace the file content:

```java
package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.FundNavHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.*;

public interface FundNavHistoryRepository extends JpaRepository<FundNavHistory, Long> {
    List<FundNavHistory> findByFundIdAndNavDateAfterOrderByNavDateAsc(UUID fundId, LocalDate after);
    Optional<FundNavHistory> findTopByFundIdOrderByNavDateDesc(UUID fundId);
}
```

- [ ] **Step 2: Verify the build compiles**

```bash
cd backend && mvn compile -pl module-fund -q
```

Expected: BUILD SUCCESS (no output)

- [ ] **Step 3: Commit**

```bash
cd backend && git add module-fund/src/main/java/com/smartinvest/fund/repository/FundNavHistoryRepository.java
git commit -m "feat: add findTopByFundIdOrderByNavDateDesc to FundNavHistoryRepository"
```

---

## Task 2: Add module-fund dependency to module-portfolio

**Files:**
- Modify: `backend/module-portfolio/pom.xml`

- [ ] **Step 1: Add the dependency**

Replace the entire `pom.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.smartinvest</groupId>
        <artifactId>smart-invest-parent</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>module-portfolio</artifactId>
    <name>Module Portfolio</name>

    <dependencies>
        <dependency>
            <groupId>com.smartinvest</groupId>
            <artifactId>module-fund</artifactId>
            <version>${project.version}</version>
        </dependency>
    </dependencies>
</project>
```

- [ ] **Step 2: Verify compile**

```bash
cd backend && mvn compile -pl module-portfolio -am -q
```

Expected: BUILD SUCCESS

- [ ] **Step 3: Commit**

```bash
cd backend && git add module-portfolio/pom.xml
git commit -m "feat: add module-fund dependency to module-portfolio"
```

---

## Task 3: Create HoldingResponse DTO

**Files:**
- Create: `backend/module-portfolio/src/main/java/com/smartinvest/portfolio/dto/HoldingResponse.java`

- [ ] **Step 1: Create the DTO**

```java
package com.smartinvest.portfolio.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record HoldingResponse(
    UUID id,
    UUID fundId,
    BigDecimal totalUnits,
    BigDecimal totalInvested,
    BigDecimal marketValue
) {}
```

- [ ] **Step 2: Verify compile**

```bash
cd backend && mvn compile -pl module-portfolio -am -q
```

Expected: BUILD SUCCESS

- [ ] **Step 3: Commit**

```bash
cd backend && git add module-portfolio/src/main/java/com/smartinvest/portfolio/dto/HoldingResponse.java
git commit -m "feat: add HoldingResponse DTO"
```

---

## Task 4: Write failing tests for PortfolioService

**Files:**
- Create: `backend/module-portfolio/src/test/java/com/smartinvest/portfolio/service/PortfolioServiceTest.java`

- [ ] **Step 1: Create the test directory**

```bash
mkdir -p backend/module-portfolio/src/test/java/com/smartinvest/portfolio/service
```

- [ ] **Step 2: Write the tests**

```java
package com.smartinvest.portfolio.service;

import com.smartinvest.fund.domain.FundNavHistory;
import com.smartinvest.fund.repository.FundNavHistoryRepository;
import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.dto.HoldingResponse;
import com.smartinvest.portfolio.repository.HoldingRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PortfolioServiceTest {

    @Mock HoldingRepository holdingRepository;
    @Mock FundNavHistoryRepository fundNavHistoryRepository;
    @InjectMocks PortfolioService portfolioService;

    @Test
    void getHoldingsWithMarketValue_computesMarketValueFromNav() {
        UUID userId = UUID.randomUUID();
        UUID fundId = UUID.randomUUID();

        Holding holding = new Holding();
        holding.setId(UUID.randomUUID());
        holding.setUserId(userId);
        holding.setFundId(fundId);
        holding.setTotalUnits(new BigDecimal("100.000000"));
        holding.setTotalInvested(new BigDecimal("950.00"));

        FundNavHistory nav = new FundNavHistory();
        nav.setFundId(fundId);
        nav.setNav(new BigDecimal("10.5000"));
        nav.setNavDate(LocalDate.now());

        when(holdingRepository.findByUserId(userId)).thenReturn(List.of(holding));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId))
            .thenReturn(Optional.of(nav));

        List<HoldingResponse> result = portfolioService.getHoldingsWithMarketValue(userId);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).marketValue()).isEqualByComparingTo("1050.00");
    }

    @Test
    void getHoldingsWithMarketValue_fallsBackToTotalInvestedWhenNoNav() {
        UUID userId = UUID.randomUUID();
        UUID fundId = UUID.randomUUID();

        Holding holding = new Holding();
        holding.setId(UUID.randomUUID());
        holding.setUserId(userId);
        holding.setFundId(fundId);
        holding.setTotalUnits(new BigDecimal("100.000000"));
        holding.setTotalInvested(new BigDecimal("950.00"));

        when(holdingRepository.findByUserId(userId)).thenReturn(List.of(holding));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId))
            .thenReturn(Optional.empty());

        List<HoldingResponse> result = portfolioService.getHoldingsWithMarketValue(userId);

        assertThat(result.get(0).marketValue()).isEqualByComparingTo("950.00");
    }

    @Test
    void getTotalMarketValue_sumsAllHoldingMarketValues() {
        UUID userId = UUID.randomUUID();
        UUID fundId1 = UUID.randomUUID();
        UUID fundId2 = UUID.randomUUID();

        Holding h1 = new Holding();
        h1.setId(UUID.randomUUID());
        h1.setUserId(userId);
        h1.setFundId(fundId1);
        h1.setTotalUnits(new BigDecimal("100.000000"));
        h1.setTotalInvested(new BigDecimal("1000.00"));

        Holding h2 = new Holding();
        h2.setId(UUID.randomUUID());
        h2.setUserId(userId);
        h2.setFundId(fundId2);
        h2.setTotalUnits(new BigDecimal("50.000000"));
        h2.setTotalInvested(new BigDecimal("500.00"));

        FundNavHistory nav1 = new FundNavHistory();
        nav1.setNav(new BigDecimal("10.0000"));

        FundNavHistory nav2 = new FundNavHistory();
        nav2.setNav(new BigDecimal("20.0000"));

        when(holdingRepository.findByUserId(userId)).thenReturn(List.of(h1, h2));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId1))
            .thenReturn(Optional.of(nav1));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId2))
            .thenReturn(Optional.of(nav2));

        BigDecimal total = portfolioService.getTotalMarketValue(userId);

        // h1: 100 × 10 = 1000, h2: 50 × 20 = 1000, total = 2000
        assertThat(total).isEqualByComparingTo("2000.00");
    }

    @Test
    void getTotalMarketValue_returnsZeroWhenNoHoldings() {
        UUID userId = UUID.randomUUID();
        when(holdingRepository.findByUserId(userId)).thenReturn(List.of());

        BigDecimal total = portfolioService.getTotalMarketValue(userId);

        assertThat(total).isEqualByComparingTo(BigDecimal.ZERO);
    }
}
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
cd backend && mvn test -pl module-portfolio -am -Dtest=PortfolioServiceTest 2>&1 | tail -20
```

Expected: COMPILATION ERROR or test failure — `getHoldingsWithMarketValue` and `getTotalMarketValue` don't exist yet.

---

## Task 5: Implement PortfolioService

**Files:**
- Modify: `backend/module-portfolio/src/main/java/com/smartinvest/portfolio/service/PortfolioService.java`

- [ ] **Step 1: Replace PortfolioService with full implementation**

```java
package com.smartinvest.portfolio.service;

import com.smartinvest.fund.repository.FundNavHistoryRepository;
import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.dto.HoldingResponse;
import com.smartinvest.portfolio.repository.HoldingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;

@Service @RequiredArgsConstructor
public class PortfolioService {
    private final HoldingRepository holdingRepository;
    private final FundNavHistoryRepository fundNavHistoryRepository;

    public List<HoldingResponse> getHoldingsWithMarketValue(UUID userId) {
        return holdingRepository.findByUserId(userId).stream()
            .map(h -> toResponse(h))
            .toList();
    }

    public BigDecimal getTotalMarketValue(UUID userId) {
        return getHoldingsWithMarketValue(userId).stream()
            .map(HoldingResponse::marketValue)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private HoldingResponse toResponse(Holding h) {
        BigDecimal marketValue = fundNavHistoryRepository
            .findTopByFundIdOrderByNavDateDesc(h.getFundId())
            .map(nav -> h.getTotalUnits().multiply(nav.getNav()).setScale(2, RoundingMode.HALF_UP))
            .orElse(h.getTotalInvested());
        return new HoldingResponse(h.getId(), h.getFundId(), h.getTotalUnits(), h.getTotalInvested(), marketValue);
    }
}
```

- [ ] **Step 2: Run the tests**

```bash
cd backend && mvn test -pl module-portfolio -am -Dtest=PortfolioServiceTest 2>&1 | tail -20
```

Expected: `Tests run: 4, Failures: 0, Errors: 0`

- [ ] **Step 3: Commit**

```bash
cd backend && git add \
  module-portfolio/src/main/java/com/smartinvest/portfolio/service/PortfolioService.java \
  module-portfolio/src/test/java/com/smartinvest/portfolio/service/PortfolioServiceTest.java
git commit -m "feat: implement PortfolioService market value calculation with tests"
```

---

## Task 6: Update PortfolioController

**Files:**
- Modify: `backend/module-portfolio/src/main/java/com/smartinvest/portfolio/controller/PortfolioController.java`

- [ ] **Step 1: Replace controller**

```java
package com.smartinvest.portfolio.controller;

import com.smartinvest.portfolio.dto.HoldingResponse;
import com.smartinvest.portfolio.service.PortfolioService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.*;

@RestController
@RequestMapping("/api/portfolio")
@RequiredArgsConstructor
public class PortfolioController {
    private final PortfolioService portfolioService;

    @GetMapping("/me/holdings")
    public ResponseEntity<List<HoldingResponse>> holdings(@AuthenticationPrincipal UserDetails principal) {
        return ResponseEntity.ok(portfolioService.getHoldingsWithMarketValue(UUID.fromString(principal.getUsername())));
    }

    @GetMapping("/me/summary")
    public ResponseEntity<Map<String, BigDecimal>> summary(@AuthenticationPrincipal UserDetails principal) {
        BigDecimal total = portfolioService.getTotalMarketValue(UUID.fromString(principal.getUsername()));
        return ResponseEntity.ok(Map.of("totalMarketValue", total));
    }
}
```

- [ ] **Step 2: Verify full backend build**

```bash
cd backend && mvn compile -q
```

Expected: BUILD SUCCESS

- [ ] **Step 3: Commit**

```bash
cd backend && git add module-portfolio/src/main/java/com/smartinvest/portfolio/controller/PortfolioController.java
git commit -m "feat: update PortfolioController to return HoldingResponse and add summary endpoint"
```

---

## Task 7: Update MyHoldingsPage

**Files:**
- Modify: `frontend/src/pages/holdings/MyHoldingsPage.tsx`

- [ ] **Step 1: Replace file content**

```tsx
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

interface HoldingResponse {
  id: string;
  fundId: string;
  totalUnits: number;
  totalInvested: number;
  marketValue: number;
}

export default function MyHoldingsPage() {
  const navigate = useNavigate();
  const { data: holdings = [] } = useQuery<HoldingResponse[]>({
    queryKey: ['holdings'],
    queryFn: () => apiClient.get('/api/portfolio/me/holdings').then(r => r.data),
  });
  const { data: ordersPage } = useQuery({
    queryKey: ['orders'],
    queryFn: () => apiClient.get('/api/orders').then(r => r.data),
  });
  const pendingCount = ordersPage?.content?.filter((o: any) => o.status === 'PENDING').length ?? 0;
  const totalMarketValue = holdings.reduce((sum, h) => sum + h.marketValue, 0);

  return (
    <PageLayout title="My Holdings">
      <div className="px-4 py-4 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">Total market value (HKD)</p>
        <p className="text-2xl font-bold text-si-dark mt-1">{totalMarketValue.toFixed(2)}</p>
      </div>

      <div className="divide-y divide-si-border">
        <button onClick={() => navigate('/transactions')}
          className="w-full flex items-center justify-between px-4 py-4">
          <span className="text-sm text-si-dark">My transactions</span>
          <div className="flex items-center gap-2">
            {pendingCount > 0 && <span className="bg-amber-500 text-white text-xs px-2 py-0.5 rounded-full">{pendingCount}</span>}
            <span className="text-si-gray">›</span>
          </div>
        </button>
        <button onClick={() => navigate('/plans')}
          className="w-full flex items-center justify-between px-4 py-4">
          <span className="text-sm text-si-dark">My investment plans</span>
          <span className="text-si-gray">›</span>
        </button>
      </div>

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
                  <span>Market Value: HKD {h.marketValue.toFixed(2)}</span>
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

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit 2>&1 | head -20
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
cd frontend && git add src/pages/holdings/MyHoldingsPage.tsx
git commit -m "feat: display real market value in MyHoldingsPage"
```

---

## Task 8: Update SmartInvestHomePage

**Files:**
- Modify: `frontend/src/pages/home/SmartInvestHomePage.tsx`

- [ ] **Step 1: Replace file content**

```tsx
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useAuthStore } from '../../store/authStore';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function SmartInvestHomePage() {
  const logout = useAuthStore(s => s.logout);
  const navigate = useNavigate();
  const { data: summary } = useQuery<{ totalMarketValue: number }>({
    queryKey: ['portfolio-summary'],
    queryFn: () => apiClient.get('/api/portfolio/me/summary').then(r => r.data),
  });

  return (
    <PageLayout>
      <div className="flex items-center justify-between px-4 py-3 border-b border-si-border">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-si-red rounded" />
          <span className="font-bold text-si-dark text-sm">Smart Invest</span>
        </div>
        <button onClick={logout} className="text-xs text-si-gray">Sign out</button>
      </div>

      <div className="px-4 py-5 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">Total market value (HKD)</p>
        <p className="text-2xl font-bold text-si-dark mt-1">
          {summary?.totalMarketValue?.toFixed(2) ?? '—'}
        </p>
        <button onClick={() => navigate('/holdings')}
          className="mt-2 text-xs text-si-red font-medium">My Holdings ›</button>
      </div>

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
          className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
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

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit 2>&1 | head -20
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
cd frontend && git add src/pages/home/SmartInvestHomePage.tsx
git commit -m "feat: display real total market value in SmartInvestHomePage"
```
