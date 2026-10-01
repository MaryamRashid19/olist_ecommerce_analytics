/* =====================================================================
   Olist Sales Analysis  |  PostgreSQL
   Data source: "Brazilian E-Commerce Public Dataset by Olist" (Kaggle)

   Run order
     1. Schema            - create the nine base tables
     2. Load data         - run the \copy commands from psql (see section 2)
     3. Foreign keys      - add referential integrity after loading
     4. Data validation   - row counts, null checks, duplicate checks
     5. Indexes           - B-Tree indexes for DirectQuery joins/filters
     6. BI views          - dimension and fact views consumed by Power BI
     7. View checks       - confirm the sales view does not duplicate rows
   ===================================================================== */


/* ---------------------------------------------------------------------
   1. SCHEMA
   --------------------------------------------------------------------- */

DROP TABLE IF EXISTS olist_customers_dataset CASCADE;
CREATE TABLE olist_customers_dataset (
    customer_id                 TEXT PRIMARY KEY,
    customer_unique_id          TEXT,
    customer_zip_code_prefix    INTEGER,
    customer_city               TEXT,
    customer_state              TEXT
);

DROP TABLE IF EXISTS olist_geolocation_dataset CASCADE;
CREATE TABLE olist_geolocation_dataset (
    geolocation_zip_code_prefix NUMERIC,
    geolocation_lat             NUMERIC,
    geolocation_lng             NUMERIC,
    geolocation_city            TEXT,
    geolocation_state           TEXT
);

DROP TABLE IF EXISTS olist_order_items_dataset CASCADE;
CREATE TABLE olist_order_items_dataset (
    order_id                    TEXT,
    order_item_id               INTEGER,
    product_id                  TEXT,
    seller_id                   TEXT,
    shipping_limit_date         TIMESTAMP,
    price                       NUMERIC,
    freight_value               NUMERIC
);

DROP TABLE IF EXISTS olist_order_payments_dataset CASCADE;
CREATE TABLE olist_order_payments_dataset (
    order_id                    TEXT,
    payment_sequential          INTEGER,
    payment_type                TEXT,
    payment_installments        INTEGER,
    payment_value               NUMERIC
);

DROP TABLE IF EXISTS olist_order_reviews_dataset CASCADE;
CREATE TABLE olist_order_reviews_dataset (
    review_id                   TEXT,
    order_id                    TEXT,
    review_score                INTEGER,
    review_comment_title        TEXT,
    review_comment_message      TEXT,
    review_creation_date        TIMESTAMP,
    review_answer_timestamp     TIMESTAMP
);

DROP TABLE IF EXISTS olist_orders_dataset CASCADE;
CREATE TABLE olist_orders_dataset (
    order_id                        TEXT PRIMARY KEY,
    customer_id                     TEXT,
    order_status                    TEXT,
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

DROP TABLE IF EXISTS olist_products_dataset CASCADE;
CREATE TABLE olist_products_dataset (
    product_id                  TEXT PRIMARY KEY,
    product_category_name       TEXT,
    product_name_length         INTEGER,
    product_description_length  INTEGER,
    product_photos_qty          INTEGER,
    product_weight_g            NUMERIC,
    product_length_cm           NUMERIC,
    product_height_cm           NUMERIC,
    product_width_cm            NUMERIC
);

DROP TABLE IF EXISTS olist_sellers_dataset CASCADE;
CREATE TABLE olist_sellers_dataset (
    seller_id                   TEXT PRIMARY KEY,
    seller_zip_code_prefix      INTEGER,
    seller_city                 TEXT,
    seller_state                TEXT
);

DROP TABLE IF EXISTS product_category_name_translation CASCADE;
CREATE TABLE product_category_name_translation (
    product_category_name           TEXT PRIMARY KEY,
    product_category_name_english   TEXT
);


/* ---------------------------------------------------------------------
   2. LOAD DATA (run in psql, not in a GUI query window)
   Download the CSVs from Kaggle and adjust the folder path.
   Columns are loaded by position, so the misspelled headers in the
   products CSV (product_name_lenght, product_description_lenght)
   do not need to match the column names above.

   \copy olist_customers_dataset            FROM 'data/olist_customers_dataset.csv'            WITH (FORMAT csv, HEADER true)
   \copy olist_geolocation_dataset          FROM 'data/olist_geolocation_dataset.csv'          WITH (FORMAT csv, HEADER true)
   \copy olist_order_items_dataset          FROM 'data/olist_order_items_dataset.csv'          WITH (FORMAT csv, HEADER true)
   \copy olist_order_payments_dataset       FROM 'data/olist_order_payments_dataset.csv'       WITH (FORMAT csv, HEADER true)
   \copy olist_order_reviews_dataset        FROM 'data/olist_order_reviews_dataset.csv'        WITH (FORMAT csv, HEADER true)
   \copy olist_orders_dataset               FROM 'data/olist_orders_dataset.csv'               WITH (FORMAT csv, HEADER true)
   \copy olist_products_dataset             FROM 'data/olist_products_dataset.csv'             WITH (FORMAT csv, HEADER true)
   \copy olist_sellers_dataset              FROM 'data/olist_sellers_dataset.csv'              WITH (FORMAT csv, HEADER true)
   \copy product_category_name_translation  FROM 'data/product_category_name_translation.csv'  WITH (FORMAT csv, HEADER true)
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   3. FOREIGN KEYS
   --------------------------------------------------------------------- */

ALTER TABLE olist_orders_dataset
    ADD CONSTRAINT fk_orders_customers
    FOREIGN KEY (customer_id) REFERENCES olist_customers_dataset (customer_id);

ALTER TABLE olist_order_items_dataset
    ADD CONSTRAINT fk_items_orders   FOREIGN KEY (order_id)   REFERENCES olist_orders_dataset (order_id),
    ADD CONSTRAINT fk_items_products FOREIGN KEY (product_id) REFERENCES olist_products_dataset (product_id),
    ADD CONSTRAINT fk_items_sellers  FOREIGN KEY (seller_id)  REFERENCES olist_sellers_dataset (seller_id);

ALTER TABLE olist_order_payments_dataset
    ADD CONSTRAINT fk_payments_orders
    FOREIGN KEY (order_id) REFERENCES olist_orders_dataset (order_id);

ALTER TABLE olist_order_reviews_dataset
    ADD CONSTRAINT fk_reviews_orders
    FOREIGN KEY (order_id) REFERENCES olist_orders_dataset (order_id);


/* ---------------------------------------------------------------------
   4. DATA VALIDATION
   --------------------------------------------------------------------- */

-- 4.1 Row counts per table
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM olist_customers_dataset
UNION ALL SELECT 'geolocation',          COUNT(*) FROM olist_geolocation_dataset
UNION ALL SELECT 'order_items',          COUNT(*) FROM olist_order_items_dataset
UNION ALL SELECT 'order_payments',       COUNT(*) FROM olist_order_payments_dataset
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM olist_order_reviews_dataset
UNION ALL SELECT 'orders',               COUNT(*) FROM olist_orders_dataset
UNION ALL SELECT 'products',             COUNT(*) FROM olist_products_dataset
UNION ALL SELECT 'sellers',              COUNT(*) FROM olist_sellers_dataset
UNION ALL SELECT 'category_translation', COUNT(*) FROM product_category_name_translation;

-- 4.2 Nulls in REQUIRED columns (all counts are expected to be 0)
SELECT 'customers' AS table_name, COUNT(*) AS null_count
FROM olist_customers_dataset
WHERE customer_id IS NULL OR customer_unique_id IS NULL OR customer_zip_code_prefix IS NULL
   OR customer_city IS NULL OR customer_state IS NULL
UNION ALL
SELECT 'geolocation', COUNT(*)
FROM olist_geolocation_dataset
WHERE geolocation_zip_code_prefix IS NULL OR geolocation_lat IS NULL OR geolocation_lng IS NULL
   OR geolocation_city IS NULL OR geolocation_state IS NULL
UNION ALL
SELECT 'order_items', COUNT(*)
FROM olist_order_items_dataset
WHERE order_id IS NULL OR order_item_id IS NULL OR product_id IS NULL OR seller_id IS NULL
   OR shipping_limit_date IS NULL OR price IS NULL OR freight_value IS NULL
UNION ALL
SELECT 'order_payments', COUNT(*)
FROM olist_order_payments_dataset
WHERE order_id IS NULL OR payment_sequential IS NULL OR payment_type IS NULL
   OR payment_installments IS NULL OR payment_value IS NULL
UNION ALL
SELECT 'order_reviews', COUNT(*)
FROM olist_order_reviews_dataset
WHERE review_id IS NULL OR order_id IS NULL OR review_score IS NULL
   OR review_creation_date IS NULL OR review_answer_timestamp IS NULL
UNION ALL
SELECT 'orders', COUNT(*)
FROM olist_orders_dataset
WHERE order_id IS NULL OR customer_id IS NULL OR order_status IS NULL
   OR order_purchase_timestamp IS NULL OR order_estimated_delivery_date IS NULL
UNION ALL
SELECT 'products', COUNT(*)
FROM olist_products_dataset
WHERE product_id IS NULL
UNION ALL
SELECT 'sellers', COUNT(*)
FROM olist_sellers_dataset
WHERE seller_id IS NULL OR seller_zip_code_prefix IS NULL OR seller_city IS NULL OR seller_state IS NULL
UNION ALL
SELECT 'category_translation', COUNT(*)
FROM product_category_name_translation
WHERE product_category_name IS NULL OR product_category_name_english IS NULL;

-- 4.3 Nulls in OPTIONAL columns (informational: these are legitimately empty for many rows)
SELECT 'reviews: comment title'          AS field, COUNT(*) AS null_count FROM olist_order_reviews_dataset WHERE review_comment_title IS NULL
UNION ALL SELECT 'reviews: comment message',       COUNT(*) FROM olist_order_reviews_dataset WHERE review_comment_message IS NULL
UNION ALL SELECT 'orders: approved_at',            COUNT(*) FROM olist_orders_dataset WHERE order_approved_at IS NULL
UNION ALL SELECT 'orders: delivered_carrier_date', COUNT(*) FROM olist_orders_dataset WHERE order_delivered_carrier_date IS NULL
UNION ALL SELECT 'orders: delivered_customer_date',COUNT(*) FROM olist_orders_dataset WHERE order_delivered_customer_date IS NULL
UNION ALL SELECT 'products: category_name',        COUNT(*) FROM olist_products_dataset WHERE product_category_name IS NULL
UNION ALL SELECT 'products: weight/dimensions',    COUNT(*) FROM olist_products_dataset
    WHERE product_weight_g IS NULL OR product_length_cm IS NULL OR product_height_cm IS NULL OR product_width_cm IS NULL;

-- 4.4 Key uniqueness (each query should return no rows)
SELECT customer_id, COUNT(*) FROM olist_customers_dataset GROUP BY customer_id HAVING COUNT(*) > 1;
SELECT order_id, COUNT(*) FROM olist_orders_dataset GROUP BY order_id HAVING COUNT(*) > 1;
SELECT product_id, COUNT(*) FROM olist_products_dataset GROUP BY product_id HAVING COUNT(*) > 1;
SELECT seller_id, COUNT(*) FROM olist_sellers_dataset GROUP BY seller_id HAVING COUNT(*) > 1;
SELECT product_category_name, COUNT(*) FROM product_category_name_translation GROUP BY product_category_name HAVING COUNT(*) > 1;

-- 4.5 Composite keys of the line-level tables (each query should return no rows)
SELECT order_id, order_item_id, COUNT(*)
FROM olist_order_items_dataset GROUP BY order_id, order_item_id HAVING COUNT(*) > 1;
SELECT order_id, payment_sequential, COUNT(*)
FROM olist_order_payments_dataset GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1;


/* ---------------------------------------------------------------------
   5. INDEXES
   Primary-key columns (orders.order_id, customers.customer_id, ...) are
   already indexed by their PRIMARY KEY constraints, so they are not
   indexed again here.
   --------------------------------------------------------------------- */

-- Orders
CREATE INDEX IF NOT EXISTS ix_orders_customer_id    ON olist_orders_dataset (customer_id);
CREATE INDEX IF NOT EXISTS ix_orders_purchase_date  ON olist_orders_dataset (order_purchase_timestamp);

-- Order items
CREATE INDEX IF NOT EXISTS ix_items_order_id        ON olist_order_items_dataset (order_id);
CREATE INDEX IF NOT EXISTS ix_items_product_id      ON olist_order_items_dataset (product_id);
CREATE INDEX IF NOT EXISTS ix_items_seller_id       ON olist_order_items_dataset (seller_id);

-- Customers
CREATE INDEX IF NOT EXISTS ix_customers_state       ON olist_customers_dataset (customer_state);

-- Payments and reviews
CREATE INDEX IF NOT EXISTS ix_payments_order_id     ON olist_order_payments_dataset (order_id);
CREATE INDEX IF NOT EXISTS ix_reviews_order_id      ON olist_order_reviews_dataset (order_id);


/* ---------------------------------------------------------------------
   6. BI VIEWS
   Creation order matters: bi_fact_sales depends on all four views above it.
   --------------------------------------------------------------------- */

-- 6.1 Product dimension: English category names and package volume
CREATE OR REPLACE VIEW bi_dim_product AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    (p.product_length_cm * p.product_height_cm * p.product_width_cm)   AS volume_cm3
FROM olist_products_dataset p
LEFT JOIN product_category_name_translation t
    ON t.product_category_name = p.product_category_name;

-- 6.2 Latest review per order
CREATE OR REPLACE VIEW bi_fact_review_latest AS
SELECT DISTINCT ON (r.order_id)
    r.order_id,
    r.review_score,
    r.review_creation_date,
    r.review_answer_timestamp
FROM olist_order_reviews_dataset r
ORDER BY r.order_id, r.review_creation_date DESC NULLS LAST;

-- 6.3 Order fulfilment: delivery duration and SLA flag
CREATE OR REPLACE VIEW bi_fact_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp::date                       AS purchase_date,
    date_trunc('month', o.order_purchase_timestamp)::date  AS purchase_month,
    o.order_delivered_customer_date::date                  AS delivered_date,
    o.order_estimated_delivery_date::date                  AS estimated_date,
    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
        THEN (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)
        ELSE NULL
    END AS delivery_days,
    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
         AND o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
        THEN 1
        ELSE 0
    END AS is_late,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state
FROM olist_orders_dataset o
JOIN olist_customers_dataset c
    ON c.customer_id = o.customer_id;

-- 6.4 Order-level payments: total value, max installments, dominant payment type
CREATE OR REPLACE VIEW bi_payments_order AS
SELECT
    op.order_id,
    SUM(op.payment_value)        AS order_payment_value,
    MAX(op.payment_installments) AS order_payment_installments,
    (ARRAY_AGG(op.payment_type ORDER BY op.payment_value DESC NULLS LAST))[1] AS order_payment_type
FROM olist_order_payments_dataset op
GROUP BY op.order_id;

-- 6.5 Sales fact (item grain), the view imported into Power BI via DirectQuery.
-- Payments come from bi_payments_order (one row per order), so orders with
-- several payment rows do not duplicate their item rows.
CREATE OR REPLACE VIEW bi_fact_sales AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date::date AS shipping_limit_date,
    oi.price,
    oi.freight_value,
    fo.customer_id,
    fo.customer_unique_id,
    fo.order_status,
    fo.purchase_date,
    fo.purchase_month,
    fo.delivered_date,
    fo.estimated_date,
    fo.delivery_days,
    fo.is_late,
    fo.customer_city,
    fo.customer_state,
    r.review_score,
    dp.category,
    p.order_payment_type         AS payment_type,
    p.order_payment_installments AS payment_installments,
    p.order_payment_value        AS payment_value,
    s.seller_city,
    s.seller_state
FROM olist_order_items_dataset oi
JOIN bi_fact_orders fo             ON fo.order_id = oi.order_id
LEFT JOIN bi_dim_product dp        ON dp.product_id = oi.product_id
LEFT JOIN bi_fact_review_latest r  ON r.order_id = oi.order_id
LEFT JOIN bi_payments_order p      ON p.order_id = oi.order_id
LEFT JOIN olist_sellers_dataset s  ON s.seller_id = oi.seller_id;


/* ---------------------------------------------------------------------
   7. VIEW CHECKS
   --------------------------------------------------------------------- */

-- 7.1 Row counts must be equal: the sales view should have exactly one row per order item
SELECT
    (SELECT COUNT(*) FROM olist_order_items_dataset) AS order_item_rows,
    (SELECT COUNT(*) FROM bi_fact_sales)             AS sales_view_rows;

-- 7.2 Revenue must be equal: item revenue in the view versus the base table
SELECT
    (SELECT SUM(price) FROM olist_order_items_dataset) AS base_revenue,
    (SELECT SUM(price) FROM bi_fact_sales)             AS view_revenue;

-- 7.3 Quick look at the order-level payment view
SELECT * FROM bi_payments_order LIMIT 10;