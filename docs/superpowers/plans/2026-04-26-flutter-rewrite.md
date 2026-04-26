# Flutter Rewrite - Match React Implementation

> **For agentic workers:** Use superpowers:subagent-driven-development to implement this plan.

**Goal:** Rewrite Flutter frontend to exactly match React UI/functionality

**Architecture:** Keep existing Flutter project structure, replace UI screens to match React

**Tech Stack:** Flutter 3.41, Material Design 3, go_router, Riverpod

---

## Task 1: Login Screen

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`

React LoginPage has:
- Top bar: SVG logo (48x48 gradient red with chart icon) left, language toggle button right
- Center: "Smart Invest" gradient badge (red→orange), 3D red text "智能投资平台", tagline in gradient box
- Form: email input with placeholder "demo@smartinvest.com", password input with placeholder "Demo1234!"
- onFocus: auto-fill demo credentials
- Password visibility toggle (Eye/EyeOff icons from lucide-react equivalent in Flutter)
- Error display
- Link to register
- GitHub link at bottom
- Language toggle (EN↔中文) stored in localStorage

Flutter equivalent widgets needed:
- Custom SVG/logo via CustomPaint or Icon
- Gradient text effects
- Language toggle using i18n (flutter_riverpod or similar)
- Password visibility toggle

---

## Task 2: Register Screen

**Files:**
- Modify: `lib/features/auth/presentation/register_screen.dart`

React RegisterPage has:
- Logo/brand header (same style as login)
- Full name input
- Email input
- Password input (min 8 chars)
- Error messages
- Link to login
- GitHub link
- Language toggle
- NO confirm password field (React doesn't have it)

**CRITICAL:** Remove confirm password field - React only has name, email, password

---

## Task 3: Home Screen (SmartInvestHomePage)

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart` (create if not exists)

React SmartInvestHomePage has:
- Header: SVG logo + "Smart Invest" text left, language toggle + logout button right
- Total market value card (from API /api/holdings/me/summary)
- "My Holdings" link button
- Fund categories section: Money Market, Bond Index, Equity Index (buttons linking to /funds?type=xxx)
- Portfolios section: Multi-Asset Fund, Build Portfolio buttons

---

## Task 4: Fund List Screen

**Files:**
- Check: `lib/features/funds/presentation/fund_list_screen.dart`

React FundListPage has:
- PageLayout with title and back button
- Fund list from /api/funds?type=xxx
- Each row: fund name, market focus, NAV (4 decimals), risk level colored dot
- Navigate to /funds/:id on tap

---

## Task 5: Fund Detail Screen

**Files:**
- Modify: `lib/features/funds/presentation/fund_detail_screen.dart`

React FundDetailPage has:
- PageLayout with fund name and back
- Current NAV section (4 decimals, nav date)
- 3 Tabs: Overview, Holdings, Risk
- Overview tab: NavChart with period selector (3M/6M/1Y/3Y/5Y), fund info (mgmt fee, min investment, benchmark)
- Holdings tab: top holdings list
- Risk tab: RiskGauge component
- Fixed bottom "Invest Now" button navigating to /order?fundId=xxx

NavChart React shows % return from base, Flutter currently shows absolute NAV values - needs update

---

## Task 6: Nav Chart Widget

**Files:**
- Modify: `lib/shared/widgets/nav_chart.dart`

React NavChart has:
- Period selector: 3M, 6M, 1Y, 3Y, 5Y
- Shows % return from first data point, not absolute NAV
- XAxis: date (MM-DD format), YAxis: percentage with % suffix
- Blue line (#3B82F6), no dots
- Tooltip shows percentage

---

## Task 7: My Holdings Screen

**Files:**
- Modify: `lib/features/holdings/presentation/my_holdings_screen.dart`

React MyHoldingsPage has:
- Total market value header card
- "My Transactions" row with pending count badge, chevron
- "My Plans" row with chevron
- Holdings list: fund name, code, units, market value

API: GET /api/holdings/me, GET /api/orders

---

## Task 8: My Transactions Screen

**Files:**
- Modify: `lib/features/holdings/presentation/my_transactions_screen.dart`

React MyTransactionsPage has:
- Orders list from /api/orders
- Each row: reference number, status (colored text), date, amount

Status styles: PENDING=amber, COMPLETED=green, CANCELLED=gray

---

## Task 9: Order Flow - All Screens

**Files:**
- Create/Modify:
  - `lib/features/order/presentation/order_setup_screen.dart`
  - `lib/features/order/presentation/order_review_screen.dart`
  - `lib/features/order/presentation/order_terms_screen.dart`
  - `lib/features/order/presentation/order_success_screen.dart`

React Order flow:
1. Setup: fund name, ONE_TIME/MONTHLY_PLAN toggle, amount input (min 100), continue button
2. Review: fund, order type, amount, settlement info, read terms button
3. Terms: scrollable terms text, confirm button (POST /api/orders)
4. Success: checkmark, reference number, amount, status, back home button

---

## Task 10: Investment Plans Screen

**Files:**
- Modify: `lib/features/plans/presentation/investment_plans_screen.dart`

React InvestmentPlansPage has:
- Plans list or empty state with "explore funds" link
- Each plan: reference number, fund name, monthly amount, next contribution date, status badge, total invested, completed orders

---

## Task 11: Build Portfolio Screen

**Files:**
- Modify: `lib/features/portfolio/presentation/build_portfolio_screen.dart`

React BuildPortfolioPage has:
- User risk level from auth store
- Restricted warning if risk level not 4 or 5
- Equity index funds list from /api/funds?type=EQUITY_INDEX

---

## Task 12: Multi-Asset Fund List

**Files:**
- Modify: `lib/features/funds/presentation/multi_asset_fund_list_screen.dart`

React MultiAssetFundListPage has:
- Title "Multi-Asset Funds", subtitle
- Funds from /api/funds/multi-asset
- Risk level label and colored dot

---

## Task 13: Risk Gauge Widget

**Files:**
- Check: `lib/shared/widgets/risk_gauge.dart`

React RiskGauge has:
- 6 colored segments (gray, dark blue, blue, yellow, orange, red)
- Product risk level indicator (▼)
- User risk level indicator (▲)
- "This fund is within your risk tolerance" or "exceeds" message

---

## Task 14: Page Layout Widget

**Files:**
- Check: `lib/shared/widgets/page_layout.dart`

React PageLayout has:
- Optional title header with optional back button
- Main content area with pb-20 (bottom padding for fixed elements)
- Simple structure, white background

---

## Task 15: API Response Types Fix

**Files:**
- Modify: `lib/features/funds/domain/fund_model.dart`
- Modify: `lib/features/holdings/domain/holding_model.dart`
- Modify: `lib/features/order/domain/order_model.dart`
- Modify: `lib/features/plans/domain/plan_model.dart`

Ensure all model field names match React TypeScript interfaces exactly.

Fund model needs: id, code, name, fundType, riskLevel, currentNav, navDate, annualMgmtFee, minInvestment, benchmarkIndex?, marketFocus?, description?

Holding model needs: id, fundId, fundName, fundCode, totalUnits, totalInvested, marketValue

Order model needs: id, referenceNumber, fundId, orderType, amount, status, orderDate, settlementDate?

Plan model needs: id, referenceNumber, fundId, fundName, monthlyAmount, nextContributionDate, status, completedOrders, totalInvested

---

## Task 16: Theme/Colors

**Files:**
- Check: `lib/core/theme/app_theme.dart`

Ensure colors match React CSS variables:
- si-red: #E8341A
- si-orange: #FF7043
- si-dark: dark text
- si-gray: gray text
- si-border: border color
- si-light: light background

---

## Task 17: Auth State & Token Storage

**Files:**
- Check: `lib/features/auth/domain/auth_state.dart`
- Check: `lib/features/auth/domain/auth_notifier.dart`
- Check: `lib/core/auth/token_manager.dart`

React auth store only stores token (accessToken) in localStorage.

Flutter should store token simply, match React behavior exactly.

---

## Task 18: Routing

**Files:**
- Check: `lib/core/router/app_router.dart`

Routes must match React:
- /login - LoginScreen
- /register - RegisterScreen
- / - SmartInvestHomePage (private)
- /funds - FundListPage (private)
- /funds/:id - FundDetailPage (private)
- /order - OrderSetupPage (private)
- /order/review - OrderReviewPage (private)
- /order/terms - OrderTermsPage (private)
- /order/success - OrderSuccessPage (private)
- /holdings - MyHoldingsPage (private)
- /transactions - MyTransactionsPage (private)
- /multi-asset - MultiAssetFundListPage (private)
- /plans - InvestmentPlansPage (private)
- /build-portfolio - BuildPortfolioPage (private)
