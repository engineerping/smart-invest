# Total Market Value Feature Design

**Date:** 2026-04-07  
**Status:** Approved

## Overview

Both `SmartInvestHomePage` and `MyHoldingsPage` display a "Total market value (HKD)" figure that is currently hardcoded. This feature replaces those hardcoded values with real data computed from `holdings.total_units × latest NAV` from `fund_nav_history`.

## Architecture

### Calculation Formula

```
marketValue (per holding) = total_units × latest NAV for that fund
totalMarketValue = sum of all holdings' marketValue
```

If no NAV record exists for a fund, `total_invested` is used as a fallback for that holding's market value.

---

## Backend Changes

### 1. `FundNavHistoryRepository`

Add a derived query method:
```java
Optional<FundNavHistory> findTopByFundIdOrderByNavDateDesc(UUID fundId);
```

### 2. New DTO: `HoldingResponse`

Located in `module-portfolio`. Replaces direct exposure of the `Holding` entity in API responses.

```java
record HoldingResponse(
    UUID id,
    UUID fundId,
    BigDecimal totalUnits,
    BigDecimal totalInvested,
    BigDecimal marketValue
)
```

### 3. `PortfolioService`

- Inject `FundNavHistoryRepository` (cross-module dependency via Spring bean).
- Add `getHoldingsWithMarketValue(UUID userId) → List<HoldingResponse>`: fetches holdings, looks up latest NAV per fund, computes `marketValue` per holding.
- Add `getTotalMarketValue(UUID userId) → BigDecimal`: sums `marketValue` across all holdings for the user.

### 4. `PortfolioController`

| Method | Path | Change |
|--------|------|--------|
| GET | `/api/portfolio/me/holdings` | Return `List<HoldingResponse>` instead of `List<Holding>` |
| GET | `/api/portfolio/me/summary` | New endpoint, returns `{ "totalMarketValue": 12345.67 }` |

---

## Frontend Changes

### `MyHoldingsPage`

- The existing `useQuery` for `/api/portfolio/me/holdings` now receives `HoldingResponse` objects with a `marketValue` field.
- Compute total: `holdings.reduce((sum, h) => sum + h.marketValue, 0)`.
- Replace hardcoded `1000` with the computed total.
- Render `marketValue` per holding in the list card.

### `SmartInvestHomePage`

- Add a `useQuery` for `GET /api/portfolio/me/summary`.
- Replace hardcoded `100` with `data?.totalMarketValue ?? 0`.

---

## Data Flow

```
fund_nav_history (latest NAV per fund)
        +
holdings (total_units per user per fund)
        ↓
PortfolioService.getHoldingsWithMarketValue()
        ↓
HoldingResponse[] ──────────────────────────→ MyHoldingsPage (per-holding + sum)
        ↓
PortfolioService.getTotalMarketValue()
        ↓
GET /api/portfolio/me/summary ──────────────→ SmartInvestHomePage (total only)
```

---

## Error Handling

- Missing NAV: fallback to `totalInvested` for that holding. No error thrown.
- No holdings: total market value returns `0`.

---

## Out of Scope

- Real-time NAV updates (uses latest persisted NAV in DB).
- Currency conversion (all values assumed HKD).
- Gain/loss calculation.
