CREATE SCHEMA IF NOT EXISTS m5;
 
-- Raw landing tables (wide format, mirrors CSV)
CREATE TABLE m5.raw_sales (
    id            TEXT PRIMARY KEY,
    item_id       TEXT NOT NULL,
    dept_id       TEXT NOT NULL,
    cat_id        TEXT NOT NULL,
    store_id      TEXT NOT NULL,
    state_id      TEXT NOT NULL
    -- d_1 ... d_1941 will be added programmatically
);
 
CREATE TABLE m5.raw_calendar (
    date          DATE PRIMARY KEY,
    wm_yr_wk      INT,
    weekday       TEXT,
    wday          INT,
    month         INT,
    year          INT,
    d             TEXT UNIQUE,
    event_name_1  TEXT,
    event_type_1  TEXT,
    event_name_2  TEXT,
    event_type_2  TEXT,
    snap_ca       INT,
    snap_tx       INT,
    snap_wi       INT
);
 
CREATE TABLE m5.raw_prices (
    store_id  TEXT,
    item_id   TEXT,
    wm_yr_wk  INT,
    sell_price NUMERIC(10,4),
    PRIMARY KEY (store_id, item_id, wm_yr_wk)
);
