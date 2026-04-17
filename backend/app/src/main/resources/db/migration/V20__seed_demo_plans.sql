-- V19: Seed demo investment plans for demo user (demo@smartinvest.com)

INSERT INTO investment_plans (id, reference_number, user_id, fund_id, monthly_amount,
                              next_contribution_date, status, completed_orders, total_invested,
                              plan_creation_date)
SELECT '20000000-0000-0000-0000-000000000001', 'PLAN-SI-MM-01-001',
       '00000000-0000-0000-0000-000000000001',
       f.id, 5000.00, '2026-05-07', 'ACTIVE', 3, 15000.00, '2026-02-07'
FROM funds f WHERE f.code = 'SI-MM-01'
ON CONFLICT (id) DO NOTHING;

INSERT INTO investment_plans (id, reference_number, user_id, fund_id, monthly_amount,
                              next_contribution_date, status, completed_orders, total_invested,
                              plan_creation_date)
SELECT '20000000-0000-0000-0000-000000000002', 'PLAN-SI-BI-01-001',
       '00000000-0000-0000-0000-000000000001',
       f.id, 3000.00, '2026-05-10', 'ACTIVE', 2, 6000.00, '2026-03-10'
FROM funds f WHERE f.code = 'SI-BI-01'
ON CONFLICT (id) DO NOTHING;
