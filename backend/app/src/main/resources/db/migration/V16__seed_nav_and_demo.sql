-- V15: Backfill funds.current_nav and seed demo orders + investment plan

-- ============================================================
-- 1. BACKFILL funds.current_nav FROM LATEST NAV
-- ============================================================
UPDATE funds f SET
    current_nav = sub.nav,
    nav_date    = sub.nav_date
FROM (
    SELECT fund_id, nav, fund_nav_history.nav_date,
           ROW_NUMBER() OVER (PARTITION BY fund_id ORDER BY fund_nav_history.nav_date DESC) AS rn
    FROM fund_nav_history
) sub
WHERE f.id = sub.fund_id AND sub.rn = 1;
