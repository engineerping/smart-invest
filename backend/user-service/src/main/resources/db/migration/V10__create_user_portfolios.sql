-- 用户自建投资组合模板：复刻 HSBC FlexInvest "Build your own portfolio" 功能
CREATE TABLE user_portfolios (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users(id),
    name       VARCHAR(200) NOT NULL,
    status     VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE | DELETED
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_portfolios_user_id ON user_portfolios(user_id);

-- 组合内各基金的配置比例（所有 allocation_pct 之和 = 100）
CREATE TABLE user_portfolio_allocations (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    portfolio_id   UUID          NOT NULL REFERENCES user_portfolios(id) ON DELETE CASCADE,
    fund_id        UUID          NOT NULL REFERENCES funds(id),
    allocation_pct DECIMAL(5,2)  NOT NULL,
    UNIQUE (portfolio_id, fund_id)
);
