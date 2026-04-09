-- V18: Seed demo orders for demo user (demo@smartinvest.com)

INSERT INTO orders (id, reference_number, user_id, fund_id, order_type, investment_type,
                    amount, nav_at_order, executed_units, status, order_date, settlement_date,
                    created_at, completed_at)
SELECT
    '10000000-0000-0000-0000-000000000001',
    'SI-20260325-0001',
    '00000000-0000-0000-0000-000000000001',
    f.id,
    'ONE_TIME', 'BUY',
    49750.00, 9.9500, 5000.000000,
    'COMPLETED', '2026-03-25', '2026-03-27',
    '2026-03-25 09:00:00+08', '2026-03-27 17:00:00+08'
FROM funds f WHERE f.code = 'SI-MM-01'
ON CONFLICT (id) DO NOTHING;

INSERT INTO orders (id, reference_number, user_id, fund_id, order_type, investment_type,
                    amount, nav_at_order, executed_units, status, order_date, settlement_date,
                    created_at, completed_at)
SELECT
    '10000000-0000-0000-0000-000000000002',
    'SI-20260326-0001',
    '00000000-0000-0000-0000-000000000001',
    f.id,
    'ONE_TIME', 'BUY',
    24900.00, 8.3000, 3000.000000,
    'COMPLETED', '2026-03-26', '2026-03-28',
    '2026-03-26 10:00:00+08', '2026-03-28 17:00:00+08'
FROM funds f WHERE f.code = 'SI-BI-01'
ON CONFLICT (id) DO NOTHING;

INSERT INTO orders (id, reference_number, user_id, fund_id, order_type, investment_type,
                    amount, nav_at_order, executed_units, status, order_date, settlement_date,
                    created_at, completed_at)
SELECT
    '10000000-0000-0000-0000-000000000003',
    'SI-20260328-0001',
    '00000000-0000-0000-0000-000000000001',
    f.id,
    'ONE_TIME', 'BUY',
    14775.00, 98.5000, 150.000000,
    'COMPLETED', '2026-03-28', '2026-04-01',
    '2026-03-28 11:00:00+08', '2026-04-01 17:00:00+08'
FROM funds f WHERE f.code = 'SI-EI-01'
ON CONFLICT (id) DO NOTHING;

INSERT INTO orders (id, reference_number, user_id, fund_id, order_type, investment_type,
                    amount, nav_at_order, executed_units, status, order_date, settlement_date,
                    created_at)
SELECT
    '10000000-0000-0000-0000-000000000004',
    'SI-20260407-0001',
    '00000000-0000-0000-0000-000000000001',
    f.id,
    'MONTHLY_PLAN', 'BUY',
    5000.00, 9.9900, NULL,
    'PENDING', '2026-04-07', '2026-04-09',
    '2026-04-07 09:00:00+08'
FROM funds f WHERE f.code = 'SI-MM-01'
ON CONFLICT (id) DO NOTHING;
