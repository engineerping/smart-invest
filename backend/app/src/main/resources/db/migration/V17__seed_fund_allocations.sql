-- V17: Seed fund asset/sector/geo allocations and top holdings
-- As-of date: 2026-03-31

-- ============================================================
-- 1. ASSET ALLOCATIONS
-- ============================================================
INSERT INTO fund_asset_allocations (fund_id, asset_class, percentage, as_of_date)
SELECT f.id, v.asset_class, v.percentage::decimal, v.as_of_date::date
FROM (VALUES
-- SI-MM-01 Money Market
('SI-MM-01', 'Bank Deposits',      85.00, '2026-03-31'),
('SI-MM-01', 'Short-term Bills',   15.00, '2026-03-31'),

-- SI-BI-01 Global Aggregate Bond Index
('SI-BI-01', 'Government Bonds',   48.00, '2026-03-31'),
('SI-BI-01', 'Corporate Bonds',    35.00, '2026-03-31'),
('SI-BI-01', 'Securitised Bonds',  10.00, '2026-03-31'),
('SI-BI-01', 'Cash & Equivalents',  7.00, '2026-03-31'),

-- SI-BI-02 Global Corporate Bond Index
('SI-BI-02', 'Corporate Bonds',    75.00, '2026-03-31'),
('SI-BI-02', 'Government Bonds',   10.00, '2026-03-31'),
('SI-BI-02', 'Securitised Bonds',   8.00, '2026-03-31'),
('SI-BI-02', 'Cash & Equivalents',  7.00, '2026-03-31'),

-- SI-EI-01 US Equity Index
('SI-EI-01', 'US Equities',        95.00, '2026-03-31'),
('SI-EI-01', 'Cash & Equivalents',  5.00, '2026-03-31'),

-- SI-EI-02 Global Equity Index
('SI-EI-02', 'US Equities',        60.00, '2026-03-31'),
('SI-EI-02', 'European Equities',  15.00, '2026-03-31'),
('SI-EI-02', 'Japanese Equities',   8.00, '2026-03-31'),
('SI-EI-02', 'HK & China Equities',10.00, '2026-03-31'),
('SI-EI-02', 'Other Equities',      4.50, '2026-03-31'),
('SI-EI-02', 'Cash & Equivalents',  2.50, '2026-03-31'),

-- SI-EI-03 Hang Seng Index
('SI-EI-03', 'HK & China Equities',88.00, '2026-03-31'),
('SI-EI-03', 'US Equities',         5.00, '2026-03-31'),
('SI-EI-03', 'Cash & Equivalents',  7.00, '2026-03-31'),

-- SI-MA-01 World Selection 1 (Conservative)
('SI-MA-01', 'Fixed Income',       65.00, '2026-03-31'),
('SI-MA-01', 'Global Equities',    22.00, '2026-03-31'),
('SI-MA-01', 'Money Market',        8.00, '2026-03-31'),
('SI-MA-01', 'Alternatives',        5.00, '2026-03-31'),

-- SI-MA-02 World Selection 2 (Moderately Conservative)
('SI-MA-02', 'Fixed Income',       50.00, '2026-03-31'),
('SI-MA-02', 'Global Equities',    38.00, '2026-03-31'),
('SI-MA-02', 'Money Market',        7.00, '2026-03-31'),
('SI-MA-02', 'Alternatives',        5.00, '2026-03-31'),

-- SI-MA-03 World Selection 3 (Balanced)
('SI-MA-03', 'Fixed Income',       38.00, '2026-03-31'),
('SI-MA-03', 'Global Equities',    50.00, '2026-03-31'),
('SI-MA-03', 'Money Market',        5.00, '2026-03-31'),
('SI-MA-03', 'Alternatives',        7.00, '2026-03-31'),

-- SI-MA-04 World Selection 4 (Adventurous)
('SI-MA-04', 'Fixed Income',       20.00, '2026-03-31'),
('SI-MA-04', 'Global Equities',    68.00, '2026-03-31'),
('SI-MA-04', 'Money Market',        4.00, '2026-03-31'),
('SI-MA-04', 'Alternatives',        8.00, '2026-03-31'),

-- SI-MA-05 World Selection 5 (Speculative)
('SI-MA-05', 'Fixed Income',       10.00, '2026-03-31'),
('SI-MA-05', 'Global Equities',    80.00, '2026-03-31'),
('SI-MA-05', 'Commodities',         7.00, '2026-03-31'),
('SI-MA-05', 'Money Market',        3.00, '2026-03-31')
) AS v(fund_code, asset_class, percentage, as_of_date)
JOIN funds f ON f.code = v.fund_code
ON CONFLICT (fund_id, asset_class, as_of_date) DO NOTHING;

-- ============================================================
-- 2. SECTOR ALLOCATIONS (for equity and multi-asset funds)
-- ============================================================
INSERT INTO fund_sector_allocations (fund_id, sector, percentage, as_of_date)
SELECT f.id, v.sector, v.percentage::decimal, v.as_of_date::date
FROM (VALUES
-- SI-EI-01 US Equity Index
('SI-EI-01', 'Information Technology', 30.00, '2026-03-31'),
('SI-EI-01', 'Financials',             14.00, '2026-03-31'),
('SI-EI-01', 'Healthcare',             12.00, '2026-03-31'),
('SI-EI-01', 'Consumer Discretionary', 10.00, '2026-03-31'),
('SI-EI-01', 'Communication Services',  9.00, '2026-03-31'),
('SI-EI-01', 'Industrials',             8.00, '2026-03-31'),
('SI-EI-01', 'Consumer Staples',        6.00, '2026-03-31'),
('SI-EI-01', 'Energy',                  4.00, '2026-03-31'),
('SI-EI-01', 'Utilities',               2.00, '2026-03-31'),
('SI-EI-01', 'Real Estate',             2.50, '2026-03-31'),
('SI-EI-01', 'Materials',               2.50, '2026-03-31'),

-- SI-EI-02 Global Equity Index
('SI-EI-02', 'Information Technology', 25.00, '2026-03-31'),
('SI-EI-02', 'Financials',             17.00, '2026-03-31'),
('SI-EI-02', 'Healthcare',             12.00, '2026-03-31'),
('SI-EI-02', 'Consumer Discretionary', 11.00, '2026-03-31'),
('SI-EI-02', 'Industrials',             9.00, '2026-03-31'),
('SI-EI-02', 'Communication Services',  8.00, '2026-03-31'),
('SI-EI-02', 'Consumer Staples',        6.00, '2026-03-31'),
('SI-EI-02', 'Energy',                  4.00, '2026-03-31'),
('SI-EI-02', 'Real Estate',             4.00, '2026-03-31'),
('SI-EI-02', 'Utilities',               2.00, '2026-03-31'),
('SI-EI-02', 'Materials',               2.00, '2026-03-31'),

-- SI-EI-03 Hang Seng Index
('SI-EI-03', 'Financials',             28.00, '2026-03-31'),
('SI-EI-03', 'Information Technology', 25.00, '2026-03-31'),
('SI-EI-03', 'Consumer Discretionary', 15.00, '2026-03-31'),
('SI-EI-03', 'Real Estate',            10.00, '2026-03-31'),
('SI-EI-03', 'Communication Services',  8.00, '2026-03-31'),
('SI-EI-03', 'Industrials',             6.00, '2026-03-31'),
('SI-EI-03', 'Healthcare',              4.00, '2026-03-31'),
('SI-EI-03', 'Utilities',               2.00, '2026-03-31'),
('SI-EI-03', 'Energy',                  1.00, '2026-03-31'),
('SI-EI-03', 'Consumer Staples',        1.00, '2026-03-31'),

-- SI-MA-01 World Selection 1
('SI-MA-01', 'Fixed Income',           35.00, '2026-03-31'),
('SI-MA-01', 'Financials',             15.00, '2026-03-31'),
('SI-MA-01', 'Information Technology', 10.00, '2026-03-31'),
('SI-MA-01', 'Healthcare',              8.00, '2026-03-31'),
('SI-MA-01', 'Consumer Staples',        7.00, '2026-03-31'),
('SI-MA-01', 'Energy',                  5.00, '2026-03-31'),
('SI-MA-01', 'Industrials',             5.00, '2026-03-31'),
('SI-MA-01', 'Consumer Discretionary',  5.00, '2026-03-31'),
('SI-MA-01', 'Real Estate',             4.00, '2026-03-31'),
('SI-MA-01', 'Utilities',               3.00, '2026-03-31'),
('SI-MA-01', 'Communication Services',  3.00, '2026-03-31'),

-- SI-MA-02 World Selection 2
('SI-MA-02', 'Fixed Income',           28.00, '2026-03-31'),
('SI-MA-02', 'Information Technology', 15.00, '2026-03-31'),
('SI-MA-02', 'Financials',             14.00, '2026-03-31'),
('SI-MA-02', 'Healthcare',             10.00, '2026-03-31'),
('SI-MA-02', 'Consumer Discretionary',  8.00, '2026-03-31'),
('SI-MA-02', 'Industrials',             6.00, '2026-03-31'),
('SI-MA-02', 'Consumer Staples',        5.00, '2026-03-31'),
('SI-MA-02', 'Energy',                  4.00, '2026-03-31'),
('SI-MA-02', 'Real Estate',             4.00, '2026-03-31'),
('SI-MA-02', 'Utilities',               3.00, '2026-03-31'),
('SI-MA-02', 'Communication Services',  3.00, '2026-03-31'),

-- SI-MA-03 World Selection 3
('SI-MA-03', 'Information Technology', 20.00, '2026-03-31'),
('SI-MA-03', 'Fixed Income',           20.00, '2026-03-31'),
('SI-MA-03', 'Financials',             14.00, '2026-03-31'),
('SI-MA-03', 'Healthcare',             10.00, '2026-03-31'),
('SI-MA-03', 'Consumer Discretionary',  9.00, '2026-03-31'),
('SI-MA-03', 'Industrials',             7.00, '2026-03-31'),
('SI-MA-03', 'Consumer Staples',        5.00, '2026-03-31'),
('SI-MA-03', 'Energy',                  4.00, '2026-03-31'),
('SI-MA-03', 'Real Estate',             4.00, '2026-03-31'),
('SI-MA-03', 'Utilities',               3.00, '2026-03-31'),
('SI-MA-03', 'Communication Services',  4.00, '2026-03-31'),

-- SI-MA-04 World Selection 4
('SI-MA-04', 'Information Technology', 24.00, '2026-03-31'),
('SI-MA-04', 'Financials',             15.00, '2026-03-31'),
('SI-MA-04', 'Fixed Income',           10.00, '2026-03-31'),
('SI-MA-04', 'Healthcare',              9.00, '2026-03-31'),
('SI-MA-04', 'Consumer Discretionary',  9.00, '2026-03-31'),
('SI-MA-04', 'Industrials',             8.00, '2026-03-31'),
('SI-MA-04', 'Consumer Staples',        6.00, '2026-03-31'),
('SI-MA-04', 'Energy',                  5.00, '2026-03-31'),
('SI-MA-04', 'Real Estate',             4.00, '2026-03-31'),
('SI-MA-04', 'Utilities',               3.00, '2026-03-31'),
('SI-MA-04', 'Communication Services',  7.00, '2026-03-31'),

-- SI-MA-05 World Selection 5
('SI-MA-05', 'Information Technology', 28.00, '2026-03-31'),
('SI-MA-05', 'Financials',             15.00, '2026-03-31'),
('SI-MA-05', 'Healthcare',             10.00, '2026-03-31'),
('SI-MA-05', 'Consumer Discretionary', 10.00, '2026-03-31'),
('SI-MA-05', 'Industrials',             8.00, '2026-03-31'),
('SI-MA-05', 'Communication Services',  9.00, '2026-03-31'),
('SI-MA-05', 'Consumer Staples',        5.00, '2026-03-31'),
('SI-MA-05', 'Energy',                  5.00, '2026-03-31'),
('SI-MA-05', 'Real Estate',             3.00, '2026-03-31'),
('SI-MA-05', 'Utilities',               2.00, '2026-03-31'),
('SI-MA-05', 'Materials',               3.00, '2026-03-31'),
('SI-MA-05', 'Commodities',             2.00, '2026-03-31')
) AS v(fund_code, sector, percentage, as_of_date)
JOIN funds f ON f.code = v.fund_code
ON CONFLICT (fund_id, sector, as_of_date) DO NOTHING;

-- ============================================================
-- 3. GEOGRAPHIC ALLOCATIONS
-- ============================================================
INSERT INTO fund_geo_allocations (fund_id, region, percentage, as_of_date)
SELECT f.id, v.region, v.percentage::decimal, v.as_of_date::date
FROM (VALUES
-- SI-MM-01 Money Market
('SI-MM-01', 'Hong Kong',            100.00, '2026-03-31'),

-- SI-BI-01 Global Aggregate Bond Index
('SI-BI-01', 'North America',         40.00, '2026-03-31'),
('SI-BI-01', 'Europe',                30.00, '2026-03-31'),
('SI-BI-01', 'Asia Pacific',          15.00, '2026-03-31'),
('SI-BI-01', 'Emerging Markets',      10.00, '2026-03-31'),
('SI-BI-01', 'Cash & Others',          5.00, '2026-03-31'),

-- SI-BI-02 Global Corporate Bond Index
('SI-BI-02', 'North America',         55.00, '2026-03-31'),
('SI-BI-02', 'Europe',                25.00, '2026-03-31'),
('SI-BI-02', 'Asia Pacific',          10.00, '2026-03-31'),
('SI-BI-02', 'Emerging Markets',       5.00, '2026-03-31'),
('SI-BI-02', 'Cash & Others',          5.00, '2026-03-31'),

-- SI-EI-01 US Equity Index
('SI-EI-01', 'North America',        100.00, '2026-03-31'),

-- SI-EI-02 Global Equity Index
('SI-EI-02', 'North America',         60.00, '2026-03-31'),
('SI-EI-02', 'Europe',                15.00, '2026-03-31'),
('SI-EI-02', 'Japan',                  8.00, '2026-03-31'),
('SI-EI-02', 'Asia Pacific ex Japan',  9.00, '2026-03-31'),
('SI-EI-02', 'Emerging Markets',       5.00, '2026-03-31'),
('SI-EI-02', 'Cash & Others',          3.00, '2026-03-31'),

-- SI-EI-03 Hang Seng Index
('SI-EI-03', 'Hong Kong',             55.00, '2026-03-31'),
('SI-EI-03', 'China',                 35.00, '2026-03-31'),
('SI-EI-03', 'North America',          5.00, '2026-03-31'),
('SI-EI-03', 'Europe',                 2.00, '2026-03-31'),
('SI-EI-03', 'Cash & Others',          3.00, '2026-03-31'),

-- SI-MA-01 World Selection 1 (Conservative)
('SI-MA-01', 'North America',         35.00, '2026-03-31'),
('SI-MA-01', 'Europe',                20.00, '2026-03-31'),
('SI-MA-01', 'Asia Pacific',          18.00, '2026-03-31'),
('SI-MA-01', 'Hong Kong',             10.00, '2026-03-31'),
('SI-MA-01', 'Emerging Markets',      10.00, '2026-03-31'),
('SI-MA-01', 'Cash & Others',          7.00, '2026-03-31'),

-- SI-MA-02 World Selection 2
('SI-MA-02', 'North America',         40.00, '2026-03-31'),
('SI-MA-02', 'Europe',                18.00, '2026-03-31'),
('SI-MA-02', 'Asia Pacific',          20.00, '2026-03-31'),
('SI-MA-02', 'Hong Kong',              8.00, '2026-03-31'),
('SI-MA-02', 'Emerging Markets',       7.00, '2026-03-31'),
('SI-MA-02', 'Cash & Others',          7.00, '2026-03-31'),

-- SI-MA-03 World Selection 3 (Balanced)
('SI-MA-03', 'North America',         45.00, '2026-03-31'),
('SI-MA-03', 'Europe',                15.00, '2026-03-31'),
('SI-MA-03', 'Asia Pacific',          20.00, '2026-03-31'),
('SI-MA-03', 'Hong Kong',              7.00, '2026-03-31'),
('SI-MA-03', 'Emerging Markets',       8.00, '2026-03-31'),
('SI-MA-03', 'Cash & Others',          5.00, '2026-03-31'),

-- SI-MA-04 World Selection 4 (Adventurous)
('SI-MA-04', 'North America',         50.00, '2026-03-31'),
('SI-MA-04', 'Europe',                12.00, '2026-03-31'),
('SI-MA-04', 'Asia Pacific',          20.00, '2026-03-31'),
('SI-MA-04', 'Hong Kong',              6.00, '2026-03-31'),
('SI-MA-04', 'Emerging Markets',      10.00, '2026-03-31'),
('SI-MA-04', 'Cash & Others',          2.00, '2026-03-31'),

-- SI-MA-05 World Selection 5 (Speculative)
('SI-MA-05', 'North America',         55.00, '2026-03-31'),
('SI-MA-05', 'Europe',                10.00, '2026-03-31'),
('SI-MA-05', 'Asia Pacific',          18.00, '2026-03-31'),
('SI-MA-05', 'Hong Kong',              5.00, '2026-03-31'),
('SI-MA-05', 'Emerging Markets',      10.00, '2026-03-31'),
('SI-MA-05', 'Cash & Others',          2.00, '2026-03-31')
) AS v(fund_code, region, percentage, as_of_date)
JOIN funds f ON f.code = v.fund_code
ON CONFLICT (fund_id, region, as_of_date) DO NOTHING;

-- ============================================================
-- 4. TOP HOLDINGS
-- ============================================================
INSERT INTO fund_top_holdings (fund_id, holding_name, weight, as_of_date, sequence)
SELECT f.id, v.holding_name, v.weight::decimal, v.as_of_date::date, v.sequence::smallint
FROM (VALUES
-- SI-MM-01 Money Market
('SI-MM-01', 'Hong Kong Dollar Deposits',   45.00, '2026-03-31', 1),
('SI-MM-01', 'US Dollar Deposits',          30.00, '2026-03-31', 2),
('SI-MM-01', 'HK Treasury Bills (3M)',       15.00, '2026-03-31', 3),
('SI-MM-01', 'Short-term Commercial Paper', 10.00, '2026-03-31', 4),

-- SI-BI-01 Global Aggregate Bond Index
('SI-BI-01', 'US Treasury Notes 2.75% 2027',     5.50, '2026-03-31', 1),
('SI-BI-01', 'Japan Government Bonds 0.1% 2029',  4.00, '2026-03-31', 2),
('SI-BI-01', 'UK Gilts 4.25% 2027',               3.50, '2026-03-31', 3),
('SI-BI-01', 'German Bunds 2.5% 2034',            3.00, '2026-03-31', 4),
('SI-BI-01', 'France OAT 3.0% 2033',              2.80, '2026-03-31', 5),
('SI-BI-01', 'Italy BTP 4.0% 2030',               2.50, '2026-03-31', 6),
('SI-BI-01', 'Spain Bonos 3.5% 2032',             2.30, '2026-03-31', 7),
('SI-BI-01', 'Japan Government Bonds 0.5% 2033',  2.00, '2026-03-31', 8),
('SI-BI-01', 'Canadian Government Bonds',         1.80, '2026-03-31', 9),
('SI-BI-01', 'Australia Government Bonds',        1.50, '2026-03-31', 10),

-- SI-BI-02 Global Corporate Bond Index
('SI-BI-02', 'Apple Inc. 3.25% 2029',             3.20, '2026-03-31', 1),
('SI-BI-02', 'Microsoft Corp. 2.675% 2030',       2.80, '2026-03-31', 2),
('SI-BI-02', 'Samsung Electronics 3.875% 2033',   2.50, '2026-03-31', 3),
('SI-BI-02', 'JPMorgan Chase 4.25% 2027',         2.20, '2026-03-31', 4),
('SI-BI-02', 'HSBC Holdings 4.0% 2030',           2.00, '2026-03-31', 5),
('SI-BI-02', 'Nestle SA 3.375% 2031',             1.80, '2026-03-31', 6),
('SI-BI-02', 'Toyota Motor Corp 2.76% 2032',      1.60, '2026-03-31', 7),
('SI-BI-02', 'AT&T Inc. 3.5% 2031',               1.50, '2026-03-31', 8),
('SI-BI-02', 'Verizon Communications 3.0% 2030',  1.40, '2026-03-31', 9),
('SI-BI-02', 'Pfizer Inc. 2.55% 2032',            1.20, '2026-03-31', 10),

-- SI-EI-01 US Equity Index
('SI-EI-01', 'Apple Inc.',               7.20, '2026-03-31', 1),
('SI-EI-01', 'Microsoft Corporation',    6.50, '2026-03-31', 2),
('SI-EI-01', 'NVIDIA Corporation',       5.80, '2026-03-31', 3),
('SI-EI-01', 'Amazon.com Inc.',          3.60, '2026-03-31', 4),
('SI-EI-01', 'Meta Platforms Inc.',      2.80, '2026-03-31', 5),
('SI-EI-01', 'Tesla Inc.',               2.40, '2026-03-31', 6),
('SI-EI-01', 'Berkshire Hathaway Inc.',  1.90, '2026-03-31', 7),
('SI-EI-01', 'Alphabet Inc. Class A',    1.80, '2026-03-31', 8),
('SI-EI-01', 'Alphabet Inc. Class C',    1.70, '2026-03-31', 9),
('SI-EI-01', 'SPDR S&P 500 ETF Trust',   1.50, '2026-03-31', 10),

-- SI-EI-02 Global Equity Index
('SI-EI-02', 'Apple Inc.',               5.50, '2026-03-31', 1),
('SI-EI-02', 'Microsoft Corporation',    4.80, '2026-03-31', 2),
('SI-EI-02', 'NVIDIA Corporation',       4.20, '2026-03-31', 3),
('SI-EI-02', 'Tencent Holdings Ltd.',    2.80, '2026-03-31', 4),
('SI-EI-02', 'Alphabet Inc.',            2.50, '2026-03-31', 5),
('SI-EI-02', 'Amazon.com Inc.',          2.30, '2026-03-31', 6),
('SI-EI-02', 'Samsung Electronics Co.', 1.90, '2026-03-31', 7),
('SI-EI-02', 'HSBC Holdings plc',        1.60, '2026-03-31', 8),
('SI-EI-02', 'Taiwan Semiconductor',     1.50, '2026-03-31', 9),
('SI-EI-02', 'Nestle S.A.',              1.40, '2026-03-31', 10),

-- SI-EI-03 Hang Seng Index
('SI-EI-03', 'Tencent Holdings Ltd.',             10.50, '2026-03-31', 1),
('SI-EI-03', 'Alibaba Group Holdings Ltd.',        9.80, '2026-03-31', 2),
('SI-EI-03', 'HSBC Holdings plc',                  8.20, '2026-03-31', 3),
('SI-EI-03', 'China Construction Bank',            5.50, '2026-03-31', 4),
('SI-EI-03', 'Ping An Insurance Group',            4.80, '2026-03-31', 5),
('SI-EI-03', 'Meituan',                            4.20, '2026-03-31', 6),
('SI-EI-03', 'Xiaomi Corporation',                 3.50, '2026-03-31', 7),
('SI-EI-03', 'China Mobile Ltd.',                  3.00, '2026-03-31', 8),
('SI-EI-03', 'CK Hutchison Holdings',              2.80, '2026-03-31', 9),
('SI-EI-03', 'Link Asset Management (Link REIT)',  2.50, '2026-03-31', 10),

-- SI-MA-01 World Selection 1 (Conservative)
('SI-MA-01', 'US Treasury Notes 2.75% 2027',       8.00, '2026-03-31', 1),
('SI-MA-01', 'Smart Invest Global Aggregate Bond', 7.50, '2026-03-31', 2),
('SI-MA-01', 'Hong Kong Dollar Deposits',          7.00, '2026-03-31', 3),
('SI-MA-01', 'Smart Invest US Equity Index',       6.00, '2026-03-31', 4),
('SI-MA-01', 'Smart Invest Global Equity Index',   5.50, '2026-03-31', 5),
('SI-MA-01', 'iShares Core Global Aggregate',      5.00, '2026-03-31', 6),
('SI-MA-01', 'Smart Invest Global Corporate Bond', 4.00, '2026-03-31', 7),
('SI-MA-01', 'JPMorgan Chase 4.25% 2027',          3.50, '2026-03-31', 8),
('SI-MA-01', 'Apple Inc.',                         3.00, '2026-03-31', 9),
('SI-MA-01', 'Microsoft Corporation',              2.50, '2026-03-31', 10),

-- SI-MA-02 World Selection 2
('SI-MA-02', 'Smart Invest Global Equity Index',   10.00, '2026-03-31', 1),
('SI-MA-02', 'Smart Invest Global Aggregate Bond',  9.00, '2026-03-31', 2),
('SI-MA-02', 'Smart Invest US Equity Index',        8.00, '2026-03-31', 3),
('SI-MA-02', 'Apple Inc.',                          4.50, '2026-03-31', 4),
('SI-MA-02', 'Microsoft Corporation',               4.00, '2026-03-31', 5),
('SI-MA-02', 'Smart Invest Global Corporate Bond',  3.50, '2026-03-31', 6),
('SI-MA-02', 'NVIDIA Corporation',                  3.00, '2026-03-31', 7),
('SI-MA-02', 'US Treasury Notes 2.75% 2027',        3.00, '2026-03-31', 8),
('SI-MA-02', 'Tencent Holdings Ltd.',               2.50, '2026-03-31', 9),
('SI-MA-02', 'Alphabet Inc.',                       2.00, '2026-03-31', 10),

-- SI-MA-03 World Selection 3 (Balanced)
('SI-MA-03', 'Smart Invest US Equity Index',        14.00, '2026-03-31', 1),
('SI-MA-03', 'Smart Invest Global Equity Index',    13.00, '2026-03-31', 2),
('SI-MA-03', 'Smart Invest Global Aggregate Bond',   8.00, '2026-03-31', 3),
('SI-MA-03', 'Apple Inc.',                           5.00, '2026-03-31', 4),
('SI-MA-03', 'Microsoft Corporation',                4.50, '2026-03-31', 5),
('SI-MA-03', 'NVIDIA Corporation',                   4.00, '2026-03-31', 6),
('SI-MA-03', 'Smart Invest Hang Seng Index Fund',    3.50, '2026-03-31', 7),
('SI-MA-03', 'Alphabet Inc.',                        3.00, '2026-03-31', 8),
('SI-MA-03', 'Tencent Holdings Ltd.',                2.50, '2026-03-31', 9),
('SI-MA-03', 'Amazon.com Inc.',                      2.00, '2026-03-31', 10),

-- SI-MA-04 World Selection 4 (Adventurous)
('SI-MA-04', 'Smart Invest US Equity Index',        20.00, '2026-03-31', 1),
('SI-MA-04', 'Smart Invest Global Equity Index',    18.00, '2026-03-31', 2),
('SI-MA-04', 'Smart Invest Hang Seng Index Fund',    8.00, '2026-03-31', 3),
('SI-MA-04', 'Apple Inc.',                           6.00, '2026-03-31', 4),
('SI-MA-04', 'NVIDIA Corporation',                   5.50, '2026-03-31', 5),
('SI-MA-04', 'Microsoft Corporation',                5.00, '2026-03-31', 6),
('SI-MA-04', 'Alphabet Inc.',                        3.50, '2026-03-31', 7),
('SI-MA-04', 'Tencent Holdings Ltd.',                3.00, '2026-03-31', 8),
('SI-MA-04', 'Smart Invest Global Corporate Bond',   3.00, '2026-03-31', 9),
('SI-MA-04', 'Amazon.com Inc.',                      2.50, '2026-03-31', 10),

-- SI-MA-05 World Selection 5 (Speculative)
('SI-MA-05', 'Smart Invest US Equity Index',        25.00, '2026-03-31', 1),
('SI-MA-05', 'Smart Invest Global Equity Index',    22.00, '2026-03-31', 2),
('SI-MA-05', 'Smart Invest Hang Seng Index Fund',   10.00, '2026-03-31', 3),
('SI-MA-05', 'Apple Inc.',                           6.00, '2026-03-31', 4),
('SI-MA-05', 'NVIDIA Corporation',                   5.50, '2026-03-31', 5),
('SI-MA-05', 'Microsoft Corporation',                5.00, '2026-03-31', 6),
('SI-MA-05', 'Alphabet Inc.',                        4.00, '2026-03-31', 7),
('SI-MA-05', 'Tencent Holdings Ltd.',                3.50, '2026-03-31', 8),
('SI-MA-05', 'Tesla Inc.',                           3.00, '2026-03-31', 9),
('SI-MA-05', 'Amazon.com Inc.',                      2.50, '2026-03-31', 10)
) AS v(fund_code, holding_name, weight, as_of_date, sequence)
JOIN funds f ON f.code = v.fund_code
ON CONFLICT (fund_id, holding_name, as_of_date) DO NOTHING;
