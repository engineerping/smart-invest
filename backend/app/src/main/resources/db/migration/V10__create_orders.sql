CREATE TABLE orders (
    id                 UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number   VARCHAR(30)   UNIQUE NOT NULL,
    user_id            UUID          NOT NULL REFERENCES users(id),
    fund_id            UUID          NOT NULL REFERENCES funds(id),
    order_type         VARCHAR(20)   NOT NULL,
    investment_type    VARCHAR(20)   NOT NULL,
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
