-- 01_schema.sql
-- Defines the table schema for the raw global ads performance dataset.
-- Run this first, then load global_ads_performance_dataset.csv into the table
-- (BigQuery: bq load / console "Create table from upload", skip header row).

CREATE TABLE IF NOT EXISTS `ads_analytics.global_ads_performance` (
  date          DATE,
  platform      STRING,
  campaign_type STRING,
  industry      STRING,
  country       STRING,
  impressions   INT64,
  clicks        INT64,
  ctr           NUMERIC,   -- source column, recomputed and checked in 02_validation.sql
  cpc           NUMERIC,   -- source column, recomputed and checked in 02_validation.sql
  ad_spend      NUMERIC,
  conversions   INT64,
  cpa           NUMERIC,   -- source column, recomputed and checked in 02_validation.sql
  revenue       NUMERIC,
  roas          NUMERIC    -- source column, recomputed and checked in 02_validation.sql
);

-- Postgres equivalent, if you'd rather run this locally:
-- CREATE TABLE global_ads_performance (
--   date          DATE,
--   platform      TEXT,
--   campaign_type TEXT,
--   industry      TEXT,
--   country       TEXT,
--   impressions   INTEGER,
--   clicks        INTEGER,
--   ctr           NUMERIC,
--   cpc           NUMERIC,
--   ad_spend      NUMERIC,
--   conversions   INTEGER,
--   cpa           NUMERIC,
--   revenue       NUMERIC,
--   roas          NUMERIC
-- );
