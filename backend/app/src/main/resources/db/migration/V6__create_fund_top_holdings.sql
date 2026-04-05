CREATE TABLE fund_top_holdings (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id      UUID         NOT NULL REFERENCES funds(id),
    holding_name VARCHAR(200) NOT NULL,
    weight       DECIMAL(6,2) NOT NULL,
    as_of_date   DATE         NOT NULL,
    sequence     SMALLINT     NOT NULL
);
