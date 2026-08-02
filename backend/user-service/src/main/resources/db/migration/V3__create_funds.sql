CREATE TABLE funds (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(30)  UNIQUE NOT NULL,
    isin_class      VARCHAR(50),
    name            VARCHAR(300) NOT NULL,
    fund_type       VARCHAR(30)  NOT NULL,
    risk_level      SMALLINT     NOT NULL,
    currency        VARCHAR(5)   DEFAULT 'HKD',
    current_nav     DECIMAL(15,4),
    nav_date        DATE,
    annual_mgmt_fee DECIMAL(6,4),
    min_investment  DECIMAL(12,2) DEFAULT 100.00,
    benchmark_index VARCHAR(300),
    market_focus    VARCHAR(200),
    description     TEXT,
    is_active       BOOLEAN      DEFAULT TRUE,
    created_at      TIMESTAMPTZ  DEFAULT NOW()
);
