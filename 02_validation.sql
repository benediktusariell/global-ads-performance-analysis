-- 02_validation.sql
-- Data quality checks run before any analysis. Confirms the dataset is clean
-- and that the source's pre-calculated metrics (CTR, CPC, CPA, ROAS) match
-- what you'd derive from the raw counts.

-- 1. Row count and date coverage sanity check
SELECT
  COUNT(*)          AS total_rows,
  MIN(date)         AS earliest_date,
  MAX(date)         AS latest_date,
  COUNT(DISTINCT platform)      AS n_platforms,
  COUNT(DISTINCT country)       AS n_countries,
  COUNT(DISTINCT industry)      AS n_industries,
  COUNT(DISTINCT campaign_type) AS n_campaign_types
FROM `ads_analytics.global_ads_performance`;

-- 2. Exact duplicate rows
SELECT date, platform, campaign_type, industry, country, COUNT(*) AS n
FROM `ads_analytics.global_ads_performance`
GROUP BY date, platform, campaign_type, industry, country
HAVING COUNT(*) > 1;

-- 3. Null check across every column
SELECT
  COUNTIF(date IS NULL)          AS null_date,
  COUNTIF(platform IS NULL)      AS null_platform,
  COUNTIF(campaign_type IS NULL) AS null_campaign_type,
  COUNTIF(industry IS NULL)      AS null_industry,
  COUNTIF(country IS NULL)       AS null_country,
  COUNTIF(impressions IS NULL)   AS null_impressions,
  COUNTIF(clicks IS NULL)        AS null_clicks,
  COUNTIF(ad_spend IS NULL)      AS null_ad_spend,
  COUNTIF(conversions IS NULL)   AS null_conversions,
  COUNTIF(revenue IS NULL)       AS null_revenue
FROM `ads_analytics.global_ads_performance`;

-- 4. Logical impossibilities: negative values, clicks > impressions,
--    conversions > clicks, spend with zero impressions, etc.
SELECT *
FROM `ads_analytics.global_ads_performance`
WHERE ad_spend < 0
   OR revenue < 0
   OR clicks > impressions
   OR conversions > clicks
   OR (ad_spend > 0 AND impressions = 0);

-- 5. Recompute CTR, CPC, CPA, ROAS from raw fields and flag any row where the
--    source's pre-calculated column disagrees beyond a small rounding tolerance.
--    This is the step that proves you understand the metrics, not just display them.
SELECT
  date, platform, campaign_type, industry, country,
  ctr  AS source_ctr,  ROUND(clicks / NULLIF(impressions, 0), 4)      AS calc_ctr,
  cpc  AS source_cpc,  ROUND(ad_spend / NULLIF(clicks, 0), 2)         AS calc_cpc,
  cpa  AS source_cpa,  ROUND(ad_spend / NULLIF(conversions, 0), 2)    AS calc_cpa,
  roas AS source_roas, ROUND(revenue / NULLIF(ad_spend, 0), 2)        AS calc_roas
FROM `ads_analytics.global_ads_performance`
WHERE ABS(ctr  - clicks / NULLIF(impressions, 0))   > 0.001
   OR ABS(cpc  - ad_spend / NULLIF(clicks, 0))       > 0.05
   OR ABS(cpa  - ad_spend / NULLIF(conversions, 0))  > 0.05
   OR ABS(roas - revenue / NULLIF(ad_spend, 0))      > 0.05;

-- 6. Statistical outliers on spend and ROAS (values > 3 standard deviations
--    from the mean), for manual review rather than automatic exclusion.
WITH stats AS (
  SELECT
    AVG(ad_spend) AS mean_spend, STDDEV(ad_spend) AS sd_spend,
    AVG(roas)     AS mean_roas,  STDDEV(roas)     AS sd_roas
  FROM `ads_analytics.global_ads_performance`
)
SELECT g.*
FROM `ads_analytics.global_ads_performance` g, stats
WHERE ABS(g.ad_spend - stats.mean_spend) > 3 * stats.sd_spend
   OR ABS(g.roas - stats.mean_roas)      > 3 * stats.sd_roas;
