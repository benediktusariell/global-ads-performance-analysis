-- 04_budget_reallocation.sql
-- Simulates shifting ad spend from the weakest ROAS platform to the strongest,
-- and projects the resulting revenue/ROAS change under an explicit,
-- stated marginal-return assumption.

-- 1. Baseline: current spend, revenue, and ROAS by platform, ranked.
--    This is what you're reallocating away from / into.
WITH platform_perf AS (
  SELECT
    platform,
    SUM(ad_spend) AS spend,
    SUM(revenue)  AS revenue,
    ROUND(SUM(revenue) / NULLIF(SUM(ad_spend), 0), 2) AS roas
  FROM `ads_analytics.global_ads_performance`
  GROUP BY platform
)
SELECT
  platform, spend, revenue, roas,
  RANK() OVER (ORDER BY roas DESC) AS roas_rank
FROM platform_perf
ORDER BY roas DESC;

-- 2. Reallocation simulation: move a fixed dollar amount from the lowest-ROAS
--    platform to the highest-ROAS platform. Three scenarios (conservative /
--    base / aggressive) apply different discounts to the receiving platform's
--    current ROAS, since returns typically diminish as spend scales up --
--    stating this assumption explicitly is what makes the simulation credible.
--
-- Edit these three parameters after running query 1:
--   @shift_amount   -- dollars to move, e.g. 50000
--   @from_platform  -- lowest ROAS platform from query 1
--   @to_platform    -- highest ROAS platform from query 1

DECLARE shift_amount FLOAT64 DEFAULT 50000;
DECLARE from_platform STRING DEFAULT 'REPLACE_WITH_LOWEST_ROAS_PLATFORM';
DECLARE to_platform   STRING DEFAULT 'REPLACE_WITH_HIGHEST_ROAS_PLATFORM';

WITH platform_perf AS (
  SELECT
    platform,
    SUM(ad_spend) AS spend,
    SUM(revenue)  AS revenue,
    SUM(revenue) / NULLIF(SUM(ad_spend), 0) AS roas
  FROM `ads_analytics.global_ads_performance`
  GROUP BY platform
),
baseline AS (
  SELECT SUM(revenue) AS total_revenue_before FROM platform_perf
),
scenarios AS (
  SELECT 'conservative' AS scenario, 0.6 AS marginal_factor UNION ALL
  SELECT 'base',         0.8 UNION ALL
  SELECT 'aggressive',   1.0
)
SELECT
  s.scenario,
  b.total_revenue_before,
  ROUND(
    b.total_revenue_before
    - shift_amount * (SELECT roas FROM platform_perf WHERE platform = from_platform)
    + shift_amount * (SELECT roas FROM platform_perf WHERE platform = to_platform) * s.marginal_factor
  , 2) AS projected_total_revenue,
  ROUND(
    (
      shift_amount * (SELECT roas FROM platform_perf WHERE platform = to_platform) * s.marginal_factor
      - shift_amount * (SELECT roas FROM platform_perf WHERE platform = from_platform)
    ) / NULLIF(b.total_revenue_before, 0) * 100
  , 2) AS revenue_change_pct
FROM scenarios s, baseline b
ORDER BY
  CASE s.scenario WHEN 'conservative' THEN 1 WHEN 'base' THEN 2 ELSE 3 END;

-- 3. Same reallocation logic, generalized as a per-platform "what if we moved
--    10% of every below-average-ROAS platform's spend into the top platform"
--    view -- useful if you want a portfolio-wide rebalancing story instead of
--    a single from/to pair.
WITH platform_perf AS (
  SELECT
    platform,
    SUM(ad_spend) AS spend,
    SUM(revenue) / NULLIF(SUM(ad_spend), 0) AS roas
  FROM `ads_analytics.global_ads_performance`
  GROUP BY platform
),
overall_roas AS (
  SELECT SUM(revenue) / NULLIF(SUM(ad_spend), 0) AS avg_roas
  FROM `ads_analytics.global_ads_performance`
),
top_platform AS (
  SELECT platform, roas FROM platform_perf ORDER BY roas DESC LIMIT 1
)
SELECT
  p.platform,
  ROUND(p.roas, 2) AS current_roas,
  ROUND(p.spend * 0.10, 2) AS spend_moved_out,
  ROUND(p.spend * 0.10 * (t.roas * 0.8 - p.roas), 2) AS projected_revenue_delta -- base-case (0.8) marginal factor
FROM platform_perf p, top_platform t, overall_roas o
WHERE p.roas < o.avg_roas
ORDER BY projected_revenue_delta DESC;
