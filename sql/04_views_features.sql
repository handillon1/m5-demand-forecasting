CREATE MATERIALIZED VIEW m5.v_features AS
SELECT  f.item_id,
        f.store_id,
        f.date,
        f.units_sold,
        p.sell_price,
        d.wday,
        d.month,
        d.event_name_1,
        CASE f.store_id
          WHEN 'CA_1' THEN d.snap_ca WHEN 'CA_2' THEN d.snap_ca
          WHEN 'CA_3' THEN d.snap_ca WHEN 'CA_4' THEN d.snap_ca
          WHEN 'TX_1' THEN d.snap_tx WHEN 'TX_2' THEN d.snap_tx
          WHEN 'TX_3' THEN d.snap_tx
          WHEN 'WI_1' THEN d.snap_wi WHEN 'WI_2' THEN d.snap_wi
          WHEN 'WI_3' THEN d.snap_wi END  AS snap_active,
        AVG(f.units_sold) OVER (PARTITION BY f.item_id, f.store_id
                                ORDER BY f.date
                                ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS roll7_mean,
        AVG(f.units_sold) OVER (PARTITION BY f.item_id, f.store_id
                                ORDER BY f.date
                                ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING) AS roll28_mean,
        LAG(f.units_sold, 7)  OVER (PARTITION BY f.item_id, f.store_id ORDER BY f.date) AS lag_7,
        LAG(f.units_sold, 28) OVER (PARTITION BY f.item_id, f.store_id ORDER BY f.date) AS lag_28
FROM    m5.fact_sales_daily f
JOIN    m5.dim_date d ON d.date = f.date
LEFT    JOIN m5.raw_prices p ON p.store_id = f.store_id
                            AND p.item_id  = f.item_id
                            AND p.wm_yr_wk = d.wm_yr_wk;
 
CREATE INDEX ON m5.v_features (item_id, store_id, date);


