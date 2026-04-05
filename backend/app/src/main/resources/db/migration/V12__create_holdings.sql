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
