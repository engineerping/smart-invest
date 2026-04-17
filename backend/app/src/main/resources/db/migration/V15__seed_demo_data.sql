-- Demo user (email: demo@smartinvest.com, password: Demo1234!)
INSERT INTO users (id, email, password, full_name, risk_level, status)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'demo@smartinvest.com',
    '$2y$10$z46I149lLF1jlsIGwlpRX.zML0aCkzwOFNzex.8G9Eh1IsVeushwa',
    'Demo User',
    4,
    'ACTIVE'
) ON CONFLICT (email) DO NOTHING;

-- NAV history: Smart Invest Global Money Funds - HKD (SI-MM-01)
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 9.9700, '2026-03-31' FROM funds WHERE code = 'SI-MM-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 9.9750, '2026-04-01' FROM funds WHERE code = 'SI-MM-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 9.9800, '2026-04-02' FROM funds WHERE code = 'SI-MM-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 9.9850, '2026-04-03' FROM funds WHERE code = 'SI-MM-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 9.9900, '2026-04-07' FROM funds WHERE code = 'SI-MM-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;

-- NAV history: Smart Invest Global Aggregate Bond Index Fund (SI-BI-01)
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 8.4200, '2026-03-31' FROM funds WHERE code = 'SI-BI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 8.4600, '2026-04-01' FROM funds WHERE code = 'SI-BI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 8.4900, '2026-04-02' FROM funds WHERE code = 'SI-BI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 8.5100, '2026-04-03' FROM funds WHERE code = 'SI-BI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 8.5200, '2026-04-07' FROM funds WHERE code = 'SI-BI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;

-- NAV history: Smart Invest US Equity Index Fund (SI-EI-01)
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 101.3000, '2026-03-31' FROM funds WHERE code = 'SI-EI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 102.5500, '2026-04-01' FROM funds WHERE code = 'SI-EI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 103.2000, '2026-04-02' FROM funds WHERE code = 'SI-EI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 103.9000, '2026-04-03' FROM funds WHERE code = 'SI-EI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;
INSERT INTO fund_nav_history (fund_id, nav, nav_date)
SELECT id, 104.5000, '2026-04-07' FROM funds WHERE code = 'SI-EI-01'
ON CONFLICT (fund_id, nav_date) DO NOTHING;

-- Holdings for demo user
-- Money Market: 5,000 units @ avg cost 9.9500, invested 49,750.00
INSERT INTO holdings (user_id, fund_id, total_units, avg_cost_nav, total_invested)
SELECT
    '00000000-0000-0000-0000-000000000001',
    id,
    5000.000000,
    9.9500,
    49750.00
FROM funds WHERE code = 'SI-MM-01'
ON CONFLICT (user_id, fund_id) DO NOTHING;

-- Bond Index: 3,000 units @ avg cost 8.3000, invested 24,900.00
INSERT INTO holdings (user_id, fund_id, total_units, avg_cost_nav, total_invested)
SELECT
    '00000000-0000-0000-0000-000000000001',
    id,
    3000.000000,
    8.3000,
    24900.00
FROM funds WHERE code = 'SI-BI-01'
ON CONFLICT (user_id, fund_id) DO NOTHING;

-- US Equity: 150 units @ avg cost 98.5000, invested 14,775.00
INSERT INTO holdings (user_id, fund_id, total_units, avg_cost_nav, total_invested)
SELECT
    '00000000-0000-0000-0000-000000000001',
    id,
    150.000000,
    98.5000,
    14775.00
FROM funds WHERE code = 'SI-EI-01'
ON CONFLICT (user_id, fund_id) DO NOTHING;

-- Expected total market value for demo user:
--   Money Market:  5,000 × 9.9900  = 49,950.00
--   Bond Index:    3,000 × 8.5200  = 25,560.00
--   US Equity:       150 × 104.5000 = 15,675.00
--   Total: 91,185.00 HKD
