ALTER TABLE m5.raw_calendar RENAME COLUMN "snap_CA" TO snap_ca;
ALTER TABLE m5.raw_calendar RENAME COLUMN "snap_TX" TO snap_tx;
ALTER TABLE m5.raw_calendar RENAME COLUMN "snap_WI" TO snap_wi;

-- Drop existing for idempotent re-runs
DROP TABLE IF EXISTS m5.dim_item  CASCADE;
DROP TABLE IF EXISTS m5.dim_store CASCADE;
DROP TABLE IF EXISTS m5.dim_date  CASCADE;

-- Item dimension: 3,049 distinct items
CREATE TABLE m5.dim_item AS
SELECT DISTINCT item_id, dept_id, cat_id
FROM   m5.raw_sales_long;
ALTER TABLE m5.dim_item ADD PRIMARY KEY (item_id);

-- Store dimension: 10 stores across 3 states
CREATE TABLE m5.dim_store AS
SELECT DISTINCT store_id, state_id
FROM   m5.raw_sales_long;
ALTER TABLE m5.dim_store ADD PRIMARY KEY (store_id);

-- Date dimension: 1,969 days
CREATE TABLE m5.dim_date AS
SELECT date, d, wm_yr_wk, weekday, wday, month, year,
       event_name_1, event_type_1, snap_ca, snap_tx, snap_wi
FROM   m5.raw_calendar;
ALTER TABLE m5.dim_date ADD PRIMARY KEY (date);
CREATE INDEX ON m5.dim_date (d);