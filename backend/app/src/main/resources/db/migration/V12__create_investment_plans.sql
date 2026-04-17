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
    terminated_at          TIMESTAMPTZ,
    portfolio_id           UUID          REFERENCES user_portfolios(id)
);
