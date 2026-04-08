-- V17: Seed fund asset/sector/geo allocations and top holdings
-- As-of date: 2026-03-31

-- ============================================================
-- 1. ASSET ALLOCATIONS
-- ============================================================
INSERT INTO fund_asset_allocations (fund_id, asset_class, percentage, as_of_date) VALUES
-- SI-MM-01 Money Market
('af0a6529-e715-40ec-89e7-acbd1ac70a9f', 'Bank Deposits',      85.00, '2026-03-31'),
('af0a6529-e715-40ec-89e7-acbd1ac70a9f', 'Short-term Bills',   15.00, '2026-03-31'),

-- SI-BI-01 Global Aggregate Bond Index
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Government Bonds',   48.00, '2026-03-31'),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Corporate Bonds',   35.00, '2026-03-31'),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Securitised Bonds',  10.00, '2026-03-31'),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Cash & Equivalents',  7.00, '2026-03-31'),

-- SI-BI-02 Global Corporate Bond Index
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Corporate Bonds',    75.00, '2026-03-31'),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Government Bonds',   10.00, '2026-03-31'),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Securitised Bonds',   8.00, '2026-03-31'),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Cash & Equivalents',  7.00, '2026-03-31'),

-- SI-EI-01 US Equity Index
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'US Equities',        95.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Cash & Equivalents',  5.00, '2026-03-31'),

-- SI-EI-02 Global Equity Index
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'US Equities',        60.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'European Equities',  15.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Japanese Equities',   8.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'HK & China Equities',10.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Other Equities',      4.50, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Cash & Equivalents',  2.50, '2026-03-31'),

-- SI-EI-03 Hang Seng Index
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'HK & China Equities',88.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'US Equities',        5.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Cash & Equivalents',  7.00, '2026-03-31'),

-- SI-MA-01 World Selection 1 (Conservative)
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Fixed Income',       65.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Global Equities',     22.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Money Market',        8.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Alternatives',       5.00, '2026-03-31'),

-- SI-MA-02 World Selection 2 (Moderately Conservative)
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Fixed Income',       50.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Global Equities',     38.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Money Market',        7.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Alternatives',        5.00, '2026-03-31'),

-- SI-MA-03 World Selection 3 (Balanced)
('8b612612-7802-416e-94d0-74bd7814805e', 'Fixed Income',       38.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Global Equities',    50.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Money Market',        5.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Alternatives',        7.00, '2026-03-31'),

-- SI-MA-04 World Selection 4 (Adventurous)
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Fixed Income',       20.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Global Equities',    68.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Money Market',        4.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Alternatives',        8.00, '2026-03-31'),

-- SI-MA-05 World Selection 5 (Speculative)
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Fixed Income',       10.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Global Equities',    80.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Commodities',         7.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Money Market',        3.00, '2026-03-31')
ON CONFLICT (fund_id, asset_class, as_of_date) DO NOTHING;

-- ============================================================
-- 2. SECTOR ALLOCATIONS (for equity and multi-asset funds)
-- ============================================================
INSERT INTO fund_sector_allocations (fund_id, sector, percentage, as_of_date) VALUES
-- SI-EI-01 US Equity Index
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Information Technology', 30.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Financials',              14.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Healthcare',              12.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Consumer Discretionary',  10.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Communication Services',  9.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Industrials',             8.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Consumer Staples',        6.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Energy',                  4.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Utilities',               2.00, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Real Estate',            2.50, '2026-03-31'),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Materials',               2.50, '2026-03-31'),

-- SI-EI-02 Global Equity Index
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Information Technology', 25.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Financials',              17.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Healthcare',              12.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Consumer Discretionary',  11.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Industrials',               9.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Communication Services',  8.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Consumer Staples',        6.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Energy',                  4.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Real Estate',             4.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Utilities',               2.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Materials',               2.00, '2026-03-31'),

-- SI-EI-03 Hang Seng Index
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Financials',             28.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Information Technology',  25.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Consumer Discretionary',  15.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Real Estate',             10.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Communication Services',  8.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Industrials',              6.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Healthcare',               4.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Utilities',                2.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Energy',                  1.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Consumer Staples',        1.00, '2026-03-31'),

-- SI-MA-01 World Selection 1
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Fixed Income',            35.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Financials',              15.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Information Technology', 10.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Healthcare',              8.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Consumer Staples',         7.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Energy',                   5.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Industrials',              5.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Consumer Discretionary',  5.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Real Estate',              4.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Utilities',                3.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Communication Services',  3.00, '2026-03-31'),

-- SI-MA-02 World Selection 2
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Fixed Income',            28.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Information Technology', 15.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Financials',              14.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Healthcare',              10.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Consumer Discretionary',  8.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Industrials',              6.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Consumer Staples',         5.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Energy',                   4.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Real Estate',              4.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Utilities',                3.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Communication Services',   3.00, '2026-03-31'),

-- SI-MA-03 World Selection 3
('8b612612-7802-416e-94d0-74bd7814805e', 'Information Technology', 20.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Fixed Income',           20.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Financials',              14.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Healthcare',             10.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Consumer Discretionary',  9.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Industrials',             7.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Consumer Staples',        5.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Energy',                  4.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Real Estate',             4.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Utilities',               3.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Communication Services',  4.00, '2026-03-31'),

-- SI-MA-04 World Selection 4
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Information Technology', 24.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Financials',              15.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Fixed Income',            10.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Healthcare',              9.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Consumer Discretionary',  9.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Industrials',             8.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Consumer Staples',        6.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Energy',                  5.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Real Estate',             4.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Utilities',               3.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Communication Services', 7.00, '2026-03-31'),

-- SI-MA-05 World Selection 5
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Information Technology', 28.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Financials',              15.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Healthcare',              10.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Consumer Discretionary', 10.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Industrials',              8.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Communication Services',  9.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Consumer Staples',        5.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Energy',                  5.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Real Estate',             3.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Utilities',               2.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Materials',               3.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Commodities',             2.00, '2026-03-31')
ON CONFLICT (fund_id, sector, as_of_date) DO NOTHING;

-- ============================================================
-- 3. GEOGRAPHIC ALLOCATIONS
-- ============================================================
INSERT INTO fund_geo_allocations (fund_id, region, percentage, as_of_date) VALUES
-- SI-MM-01 Money Market
('af0a6529-e715-40ec-89e7-acbd1ac70a9f', 'Hong Kong',            100.00, '2026-03-31'),

-- SI-BI-01 Global Aggregate Bond Index
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'North America',         40.00, '2026-03-31'),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Europe',                30.00, '2026-03-31'),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Asia Pacific',         15.00, '2026-03-31'),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Emerging Markets',      10.00, '2026-03-31'),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Cash & Others',          5.00, '2026-03-31'),

-- SI-BI-02 Global Corporate Bond Index
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'North America',         55.00, '2026-03-31'),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Europe',                25.00, '2026-03-31'),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Asia Pacific',          10.00, '2026-03-31'),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Emerging Markets',       5.00, '2026-03-31'),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Cash & Others',         5.00, '2026-03-31'),

-- SI-EI-01 US Equity Index
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'North America',         100.00, '2026-03-31'),

-- SI-EI-02 Global Equity Index
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'North America',         60.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Europe',                15.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Japan',                  8.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Asia Pacific ex Japan', 9.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Emerging Markets',       5.00, '2026-03-31'),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Cash & Others',          3.00, '2026-03-31'),

-- SI-EI-03 Hang Seng Index
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Hong Kong',            55.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'China',                 35.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'North America',         5.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Europe',                 2.00, '2026-03-31'),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Cash & Others',          3.00, '2026-03-31'),

-- SI-MA-01 World Selection 1 (Conservative)
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'North America',         35.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Europe',                20.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Asia Pacific',          18.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Hong Kong',             10.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Emerging Markets',       10.00, '2026-03-31'),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Cash & Others',          7.00, '2026-03-31'),

-- SI-MA-02 World Selection 2
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'North America',         40.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Europe',                18.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Asia Pacific',          20.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Hong Kong',              8.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Emerging Markets',        7.00, '2026-03-31'),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Cash & Others',          7.00, '2026-03-31'),

-- SI-MA-03 World Selection 3 (Balanced)
('8b612612-7802-416e-94d0-74bd7814805e', 'North America',         45.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Europe',                15.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Asia Pacific',          20.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Hong Kong',              7.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Emerging Markets',        8.00, '2026-03-31'),
('8b612612-7802-416e-94d0-74bd7814805e', 'Cash & Others',          5.00, '2026-03-31'),

-- SI-MA-04 World Selection 4 (Adventurous)
('757c6844-3847-4ed9-a580-04e65075c2c8', 'North America',         50.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Europe',                12.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Asia Pacific',          20.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Hong Kong',              6.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Emerging Markets',      10.00, '2026-03-31'),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Cash & Others',          2.00, '2026-03-31'),

-- SI-MA-05 World Selection 5 (Speculative)
('0155713b-2b01-4fae-9f67-604b120d36ad', 'North America',         55.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Europe',                10.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Asia Pacific',          18.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Hong Kong',              5.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Emerging Markets',      10.00, '2026-03-31'),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Cash & Others',          2.00, '2026-03-31')
ON CONFLICT (fund_id, region, as_of_date) DO NOTHING;

-- ============================================================
-- 4. TOP HOLDINGS
-- ============================================================
INSERT INTO fund_top_holdings (fund_id, holding_name, weight, as_of_date, sequence) VALUES
-- SI-MM-01 Money Market
('af0a6529-e715-40ec-89e7-acbd1ac70a9f', 'Hong Kong Dollar Deposits',  45.00, '2026-03-31', 1),
('af0a6529-e715-40ec-89e7-acbd1ac70a9f', 'US Dollar Deposits',         30.00, '2026-03-31', 2),
('af0a6529-e715-40ec-89e7-acbd1ac70a9f', 'HK Treasury Bills (3M)',      15.00, '2026-03-31', 3),
('af0a6529-e715-40ec-89e7-acbd1ac70a9f', 'Short-term Commercial Paper', 10.00, '2026-03-31', 4),

-- SI-BI-01 Global Aggregate Bond Index
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'US Treasury Notes 2.75% 2027',    5.50, '2026-03-31', 1),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Japan Government Bonds 0.1% 2029', 4.00, '2026-03-31', 2),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'UK Gilts 4.25% 2027',             3.50, '2026-03-31', 3),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'German Bunds 2.5% 2034',          3.00, '2026-03-31', 4),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'France OAT 3.0% 2033',           2.80, '2026-03-31', 5),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Italy BTP 4.0% 2030',              2.50, '2026-03-31', 6),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Spain Bonos 3.5% 2032',           2.30, '2026-03-31', 7),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Japan Government Bonds 0.5% 2033',2.00, '2026-03-31', 8),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Canadian Government Bonds',       1.80, '2026-03-31', 9),
('897408e7-ea8a-4f4c-bbe0-ef34b705f5de', 'Australia Government Bonds',      1.50, '2026-03-31', 10),

-- SI-BI-02 Global Corporate Bond Index
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Apple Inc. 3.25% 2029',            3.20, '2026-03-31', 1),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Microsoft Corp. 2.675% 2030',     2.80, '2026-03-31', 2),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Samsung Electronics 3.875% 2033', 2.50, '2026-03-31', 3),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'JPMorgan Chase 4.25% 2027',        2.20, '2026-03-31', 4),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'HSBC Holdings 4.0% 2030',         2.00, '2026-03-31', 5),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Nestle SA 3.375% 2031',           1.80, '2026-03-31', 6),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Toyota Motor Corp 2.76% 2032',   1.60, '2026-03-31', 7),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'AT&T Inc. 3.5% 2031',             1.50, '2026-03-31', 8),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Verizon Communications 3.0% 2030',1.40, '2026-03-31', 9),
('8de30a3e-1f2a-4970-8173-677cb2b8d483', 'Pfizer Inc. 2.55% 2032',           1.20, '2026-03-31', 10),

-- SI-EI-01 US Equity Index
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Apple Inc.',                         7.20, '2026-03-31', 1),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Microsoft Corporation',             6.50, '2026-03-31', 2),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'NVIDIA Corporation',                5.80, '2026-03-31', 3),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Amazon.com Inc.',                   3.60, '2026-03-31', 4),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Meta Platforms Inc.',               2.80, '2026-03-31', 5),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Tesla Inc.',                        2.40, '2026-03-31', 6),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Berkshire Hathaway Inc.',           1.90, '2026-03-31', 7),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Alphabet Inc. Class A',            1.80, '2026-03-31', 8),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'Alphabet Inc. Class C',              1.70, '2026-03-31', 9),
('40f83e88-2a40-449c-b011-a84be2f0f6a1', 'SPDR S&P 500 ETF Trust',            1.50, '2026-03-31', 10),

-- SI-EI-02 Global Equity Index
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Apple Inc.',                         5.50, '2026-03-31', 1),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Microsoft Corporation',             4.80, '2026-03-31', 2),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'NVIDIA Corporation',                4.20, '2026-03-31', 3),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Tencent Holdings Ltd.',             2.80, '2026-03-31', 4),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Alphabet Inc.',                     2.50, '2026-03-31', 5),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Amazon.com Inc.',                   2.30, '2026-03-31', 6),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Samsung Electronics Co.',          1.90, '2026-03-31', 7),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'HSBC Holdings plc',                 1.60, '2026-03-31', 8),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Taiwan Semiconductor',             1.50, '2026-03-31', 9),
('cc6c23d3-a28d-499d-91b1-771709815b8d', 'Nestle S.A.',                      1.40, '2026-03-31', 10),

-- SI-EI-03 Hang Seng Index
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Tencent Holdings Ltd.',            10.50, '2026-03-31', 1),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Alibaba Group Holdings Ltd.',       9.80, '2026-03-31', 2),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'HSBC Holdings plc',                 8.20, '2026-03-31', 3),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'China Construction Bank',           5.50, '2026-03-31', 4),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Ping An Insurance Group',           4.80, '2026-03-31', 5),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Meituan',                           4.20, '2026-03-31', 6),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Xiaomi Corporation',                3.50, '2026-03-31', 7),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'China Mobile Ltd.',                 3.00, '2026-03-31', 8),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'CK Hutchison Holdings',             2.80, '2026-03-31', 9),
('aa041bff-9c81-455d-858d-c3d2207c5cf6', 'Link Asset Management (Link REIT)', 2.50, '2026-03-31', 10),

-- SI-MA-01 World Selection 1 (Conservative)
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'US Treasury Notes 2.75% 2027',    8.00, '2026-03-31', 1),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Smart Invest Global Aggregate Bond', 7.50, '2026-03-31', 2),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Hong Kong Dollar Deposits',        7.00, '2026-03-31', 3),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Smart Invest US Equity Index',     6.00, '2026-03-31', 4),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Smart Invest Global Equity Index',  5.50, '2026-03-31', 5),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'iShares Core Global Aggregate',     5.00, '2026-03-31', 6),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Smart Invest Global Corporate Bond',4.00, '2026-03-31', 7),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'JPMorgan Chase 4.25% 2027',        3.50, '2026-03-31', 8),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Apple Inc.',                        3.00, '2026-03-31', 9),
('4f97531c-992f-43dd-84ff-591d64bde4e5', 'Microsoft Corporation',             2.50, '2026-03-31', 10),

-- SI-MA-02 World Selection 2
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Smart Invest Global Equity Index',  10.00, '2026-03-31', 1),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Smart Invest Global Aggregate Bond', 9.00, '2026-03-31', 2),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Smart Invest US Equity Index',      8.00, '2026-03-31', 3),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Apple Inc.',                         4.50, '2026-03-31', 4),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Microsoft Corporation',              4.00, '2026-03-31', 5),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Smart Invest Global Corporate Bond', 3.50, '2026-03-31', 6),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'NVIDIA Corporation',                 3.00, '2026-03-31', 7),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'US Treasury Notes 2.75% 2027',       3.00, '2026-03-31', 8),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Tencent Holdings Ltd.',              2.50, '2026-03-31', 9),
('08aa3e34-0643-48a5-90c1-9045f0bd4e5d', 'Alphabet Inc.',                     2.00, '2026-03-31', 10),

-- SI-MA-03 World Selection 3 (Balanced)
('8b612612-7802-416e-94d0-74bd7814805e', 'Smart Invest US Equity Index',      14.00, '2026-03-31', 1),
('8b612612-7802-416e-94d0-74bd7814805e', 'Smart Invest Global Equity Index',  13.00, '2026-03-31', 2),
('8b612612-7802-416e-94d0-74bd7814805e', 'Smart Invest Global Aggregate Bond', 8.00, '2026-03-31', 3),
('8b612612-7802-416e-94d0-74bd7814805e', 'Apple Inc.',                         5.00, '2026-03-31', 4),
('8b612612-7802-416e-94d0-74bd7814805e', 'Microsoft Corporation',              4.50, '2026-03-31', 5),
('8b612612-7802-416e-94d0-74bd7814805e', 'NVIDIA Corporation',                 4.00, '2026-03-31', 6),
('8b612612-7802-416e-94d0-74bd7814805e', 'Smart Invest Hang Seng Index Fund',  3.50, '2026-03-31', 7),
('8b612612-7802-416e-94d0-74bd7814805e', 'Alphabet Inc.',                      3.00, '2026-03-31', 8),
('8b612612-7802-416e-94d0-74bd7814805e', 'Tencent Holdings Ltd.',              2.50, '2026-03-31', 9),
('8b612612-7802-416e-94d0-74bd7814805e', 'Amazon.com Inc.',                    2.00, '2026-03-31', 10),

-- SI-MA-04 World Selection 4 (Adventurous)
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Smart Invest US Equity Index',      20.00, '2026-03-31', 1),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Smart Invest Global Equity Index',  18.00, '2026-03-31', 2),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Smart Invest Hang Seng Index Fund',  8.00, '2026-03-31', 3),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Apple Inc.',                         6.00, '2026-03-31', 4),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'NVIDIA Corporation',                 5.50, '2026-03-31', 5),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Microsoft Corporation',              5.00, '2026-03-31', 6),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Alphabet Inc.',                      3.50, '2026-03-31', 7),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Tencent Holdings Ltd.',              3.00, '2026-03-31', 8),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Smart Invest Global Corporate Bond', 3.00, '2026-03-31', 9),
('757c6844-3847-4ed9-a580-04e65075c2c8', 'Amazon.com Inc.',                    2.50, '2026-03-31', 10),

-- SI-MA-05 World Selection 5 (Speculative)
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Smart Invest US Equity Index',      25.00, '2026-03-31', 1),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Smart Invest Global Equity Index',  22.00, '2026-03-31', 2),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Smart Invest Hang Seng Index Fund', 10.00, '2026-03-31', 3),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Apple Inc.',                         6.00, '2026-03-31', 4),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'NVIDIA Corporation',                 5.50, '2026-03-31', 5),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Microsoft Corporation',              5.00, '2026-03-31', 6),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Alphabet Inc.',                      4.00, '2026-03-31', 7),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Tencent Holdings Ltd.',              3.50, '2026-03-31', 8),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Tesla Inc.',                         3.00, '2026-03-31', 9),
('0155713b-2b01-4fae-9f67-604b120d36ad', 'Amazon.com Inc.',                    2.50, '2026-03-31', 10)
ON CONFLICT (fund_id, holding_name, as_of_date) DO NOTHING;
