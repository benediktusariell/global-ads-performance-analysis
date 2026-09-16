# Global ads performance — SQL analysis

SQL layer for a media buyer portfolio project analyzing 1,800 rows of global ad
performance data (Jan–Dec 2024, 3 platforms, 7 countries, 5 industries, 4
campaign types). Two focus areas: **funnel efficiency** (where each segment
leaks between impressions and revenue) and a **budget reallocation
simulation** (what a spend shift from the weakest to strongest ROAS platform
would project).

Written for BigQuery standard SQL; a Postgres-compatible table definition is
included as a comment in `01_schema.sql`.

## Pipeline

Raw CSV → loaded into `ads_analytics.global_ads_performance` → validated and
cross-checked against source metrics → aggregated for funnel diagnostics and
a reallocation simulation → results feed the Power BI dashboard and the
written case study.

## Files

| File | Purpose |
|---|---|
| `01_schema.sql` | Table definition for the raw dataset. |
| `02_validation.sql` | Row counts, duplicate check, null check, logical-impossibility check (clicks > impressions, etc.), recomputes CTR/CPC/CPA/ROAS from raw fields and flags any mismatch against the source columns, and a 3-standard-deviation outlier scan on spend and ROAS. |
| `03_funnel_efficiency.sql` | Impressions → clicks → conversions → revenue by platform, country, and campaign type, plus a rule-based diagnosis (top-of-funnel vs. bottom-of-funnel leak) per platform and a monthly CTR/CVR trend for the weakest segment. |
| `04_budget_reallocation.sql` | Baseline spend/revenue/ROAS ranking by platform, a from/to reallocation simulation under three explicit marginal-return scenarios (conservative/base/aggressive), and a portfolio-wide "shift 10% of every below-average platform's spend to the top platform" variant. |

## Loading the data

```bash
bq load --source_format=CSV --skip_leading_rows=1 \
  ads_analytics.global_ads_performance \
  global_ads_performance_dataset.csv \
  date:DATE,platform:STRING,campaign_type:STRING,industry:STRING,country:STRING,impressions:INT64,clicks:INT64,ctr:NUMERIC,cpc:NUMERIC,ad_spend:NUMERIC,conversions:INT64,cpa:NUMERIC,revenue:NUMERIC,roas:NUMERIC
```

Or, in the BigQuery console: create the table from `01_schema.sql`, then use
"Create table from upload" and point it at the CSV, skipping the header row.

## Notes

- `02_validation.sql` should be run and reviewed before trusting any
  downstream numbers — this project's dataset passed all checks cleanly (no
  duplicates, no nulls, no logical impossibilities), which is itself worth
  stating in the write-up rather than skipping past.
- Placeholders like `REPLACE_WITH_WEAKEST_PLATFORM` in `03_funnel_efficiency.sql`
  and `04_budget_reallocation.sql` are meant to be filled in after running the
  earlier ranking queries in each file — this keeps the queries data-driven
  rather than hardcoding an assumed answer.
- Aggregated outputs from these queries are what feed the Power BI dashboard
  and the case study narrative — Power BI should connect to these views/query
  results rather than redoing the aggregation logic in DAX.
