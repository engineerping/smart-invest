# Product Analysis & Scope

## 1.1 Core Business Entities

Extracted from the Smart Invest User Guide (all 26 pages):

| Entity              | Key Attributes                                                  | Source    |
| ------------------- | --------------------------------------------------------------- | --------- |
| User                | email, password, full_name, risk_level (1–5), status            | p.3, p.15 |
| Fund                | code, name, type, NAV, risk_level, annual_fee, asset_allocation | p.7, p.12 |
| Fund Type           | MONEY_MARKET / BOND_INDEX / EQUITY_INDEX / MULTI_ASSET          | p.4, p.10 |
| Holding             | user_id, fund_id, total_units, avg_cost_nav, total_invested     | p.22      |
| Order               | type, amount, reference_number, status, settlement_date         | p.9, p.14 |
| Investment Plan     | monthly_amount, next_contribution_date, completed_orders        | p.23      |
| Portfolio Build     | selected_funds + allocation_percentages (must sum to 100%)      | p.18      |
| Reference Asset Mix | recommended asset class ratios per risk level                   | p.16      |

## 1.2 Three Investment Pathways

**Pathway A — Individual Fund Investment** (Money Market / Bond Index / Equity Index)

```
Browse fund list (sort + filter)
  → View fund detail (NAV chart / holdings / risk gauge / fees)
  → Tap "Invest now"
  → Select investment type: Monthly Plan or One-Time
  → Enter amount (min. 100 HKD) + start date
  → Select investment account + settlement account
  → Review page
  → Read Terms & Conditions → Confirm
  → Buy confirmation page with order reference number
```

**Pathway B — Multi-Asset Portfolio Investment**

```
Navigate to "Multi-asset portfolios"
  → View 5-tab ribbon (one tab per risk level 1–5)
  → Each tab: fund name, 6-month return, asset allocation pie chart
  → Tap "View fund details" for full details
  → Tap "Invest now" → same order flow as Pathway A (min. 100 HKD)
```

**Pathway C — Build Your Own Portfolio** *(Risk level 4 or 5 only)*

```
Navigate to "Build your own portfolio"
  → Step 1/5: View reference asset mix → Select funds (multi-select, filter/sort)
  → Step 2/5: Allocate percentages (must total exactly 100%)
  → Step 3/5: Investment details (Monthly/One-Time, min. 500 HKD total, start date, accounts)
  → Step 4/5: Review each fund one-by-one (notification appears per fund)
  → Step 5/5: Buy confirmation with individual order reference numbers per fund
```

## 1.3 Holdings & Transaction Management

**My Holdings Page**

- Total market value
- My transactions (with pending count badge)
- My investment plans (with active count badge)
- Individual fund holdings list with unrealised gain/loss

**My Transactions Page**

- Two tabs: Orders | Platform fees
- Orders grouped by month
- Status indicators: Pending (orange) / Cancelled (grey) / Completed (green)
- In-app history: 90 days; eStatement: 24 months

**Cancelling an Investment Plan** (4-step flow from User Guide p.23)

1. My Holdings → My investment plans
2. Select active plan
3. Tap "Terminate plan"
4. Review termination details → Confirm

**Cancelling a Pending Order** (4-step flow from User Guide p.24)

1. My Holdings → My transactions
2. Select pending order
3. Tap "Cancel order"
4. Review details → Confirm

## 1.4 Business Rules

| Rule                                  | Specification                                                        |
| ------------------------------------- | -------------------------------------------------------------------- |
| Minimum investment — individual fund  | 100 HKD                                                              |
| Minimum investment — custom portfolio | 500 HKD (total across all selected funds)                            |
| Build Portfolio access                | Risk level 4 (Adventurous) or 5 (Speculative) only                   |
| Portfolio allocation                  | Sum of all fund percentages must equal exactly 100%                  |
| Last fund amount calculation          | Total amount − sum of amounts allocated to all other funds           |
| Weekend / holiday orders              | Processed on the next business day                                   |
| Monthly plan debit day                | If falls on weekend/holiday, deferred to next business day           |
| Transaction history (in-app)          | 90 days                                                              |
| Transaction history (eStatement)      | 24 months                                                            |
| Risk level labels                     | 1=Conservative, 2=Moderate, 3=Balanced, 4=Adventurous, 5=Speculative |
| Order reference format — one-time     | `P-XXXXXX` (P + 6 digits)                                            |
| Order reference format — monthly plan | `YYYYMMDDHHmmssXXX` (timestamp + 3-digit suffix)                     |
