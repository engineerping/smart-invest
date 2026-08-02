CREATE TABLE fund_nav_history (
    id       BIGSERIAL     PRIMARY KEY,
    fund_id  UUID          NOT NULL REFERENCES funds(id),
    nav      DECIMAL(15,4) NOT NULL,
    nav_date DATE          NOT NULL,
    UNIQUE (fund_id, nav_date)
);
CREATE INDEX idx_nav_history_fund_date ON fund_nav_history (fund_id, nav_date DESC);
