DROP TABLE IF EXISTS m5.fact_sales_daily CASCADE;

CREATE TABLE m5.fact_sales_daily AS
SELECT  s.item_id,
        s.store_id,
        d.date,
        s.units_sold
FROM    m5.raw_sales_long s
JOIN    m5.dim_date       d  ON d.d = s.d;

CREATE INDEX ON m5.fact_sales_daily (item_id, store_id, date);
CREATE INDEX ON m5.fact_sales_daily (date);