CREATE TABLE fund_asset_allocations (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id     UUID         NOT NULL REFERENCES funds(id),
    asset_class VARCHAR(50)  NOT NULL,
    percentage  DECIMAL(6,2) NOT NULL,
    as_of_date  DATE         NOT NULL,
    UNIQUE (fund_id, asset_class, as_of_date)
);
