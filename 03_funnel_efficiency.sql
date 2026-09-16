-- 03_funnel_efficiency.sql
-- Impressions -> Clicks -> Conversions -> Revenue, broken down by segment,
-- to find WHERE in the funnel each platform/country/industry leaks.

-- 1. Full funnel by platform: CTR (impressions->clicks) and CVR (clicks->conversions)
--    side by side, so you can tell a "not enough clicks" problem from a
--    "clicks don't convert" problem.
SELECT
  platform,
  SUM(impressions)  AS total_impressions,
  SUM(clicks)        AS total_clicks,
  SUM(conversions)   AS total_conversions,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(SUM(clicks) / NULLIF(SUM(impressions), 0), 4)   AS ctr,
  ROUND(SUM(conversions) / NULLIF(SUM(clicks), 0), 4)   AS cvr,
  ROUND(SUM(ad_spend) / NULLIF(SUM(conversions), 0), 2) AS cpa,
  ROUND(SUM(revenue) / NULLIF(SUM(ad_spend), 0), 2)     AS roas
FROM `ads_analytics.global_ads_performance`
GROUP BY platform
ORDER BY roas DESC;

-- 2. Same funnel view, cut by country -- surfaces geographic leaks that
--    platform-level aggregation hides.
SELECT
  country,
  ROUND(SUM(clicks) / NULLIF(SUM(impressions), 0), 4)   AS ctr,
  ROUND(SUM(conversions) / NULLIF(SUM(clicks), 0), 4)   AS cvr,
  ROUND(SUM(ad_spend) / NULLIF(SUM(conversions), 0), 2) AS cpa,
  ROUND(SUM(revenue) / NULLIF(SUM(ad_spend), 0), 2)     AS roas,
  SUM(ad_spend) AS total_spend
FROM `ads_analytics.global_ads_performance`
GROUP BY country
ORDER BY roas DESC;

-- 3. Same funnel view, cut by campaign_type -- Search/Shopping/Video/Display
--    typically leak at different funnel stages by nature of the format.
SELECT
  campaign_type,
  ROUND(SUM(clicks) / NULLIF(SUM(impressions), 0), 4)   AS ctr,
  ROUND(SUM(conversions) / NULLIF(SUM(clicks), 0), 4)   AS cvr,
  ROUND(SUM(ad_spend) / NULLIF(SUM(conversions), 0), 2) AS cpa,
  ROUND(SUM(revenue) / NULLIF(SUM(ad_spend), 0), 2)     AS roas
FROM `ads_analytics.global_ads_performance`
GROUP BY campaign_type
ORDER BY roas DESC;

-- 4. Diagnostic classification: flags each platform as a "top of funnel"
--    problem (low CTR, decent CVR), a "bottom of funnel" problem (good CTR,
--    low CVR), both, or neither, relative to the overall dataset average.
--    This is the table that turns funnel numbers into a plain-English diagnosis.
WITH overall AS (
  SELECT
    SUM(clicks) / NULLIF(SUM(impressions), 0) AS avg_ctr,
    SUM(conversions) / NULLIF(SUM(clicks), 0) AS avg_cvr
  FROM `ads_analytics.global_ads_performance`
),
by_platform AS (
  SELECT
    platform,
    SUM(clicks) / NULLIF(SUM(impressions), 0) AS ctr,
    SUM(conversions) / NULLIF(SUM(clicks), 0) AS cvr
  FROM `ads_analytics.global_ads_performance`
  GROUP BY platform
)
SELECT
  p.platform,
  ROUND(p.ctr, 4) AS ctr,
  ROUND(p.cvr, 4) AS cvr,
  CASE
    WHEN p.ctr < o.avg_ctr AND p.cvr >= o.avg_cvr THEN 'Top-of-funnel leak: weak CTR, healthy CVR -- creative/targeting issue'
    WHEN p.ctr >= o.avg_ctr AND p.cvr < o.avg_cvr THEN 'Bottom-of-funnel leak: healthy CTR, weak CVR -- landing page/offer issue'
    WHEN p.ctr < o.avg_ctr AND p.cvr < o.avg_cvr  THEN 'Leaking at both stages -- broad review needed'
    ELSE 'Above average at both stages'
  END AS diagnosis
FROM by_platform p, overall o
ORDER BY p.ctr DESC;

-- 5. Monthly trend of CTR and CVR for the weakest platform (edit the platform
--    name after running query 1), to check whether the leak is worsening
--    (ad fatigue / rising competition) or stable (structural).
SELECT
  DATE_TRUNC(date, MONTH) AS month,
  ROUND(SUM(clicks) / NULLIF(SUM(impressions), 0), 4) AS ctr,
  ROUND(SUM(conversions) / NULLIF(SUM(clicks), 0), 4) AS cvr
FROM `ads_analytics.global_ads_performance`
WHERE platform = 'REPLACE_WITH_WEAKEST_PLATFORM'
GROUP BY month
ORDER BY month;
