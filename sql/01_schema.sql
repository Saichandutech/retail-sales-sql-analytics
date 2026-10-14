-- =============================================================
-- Retail sales analytics – schema (PostgreSQL 13+)
-- =============================================================
DROP SCHEMA IF EXISTS retail CASCADE;
CREATE SCHEMA retail;
SET search_path TO retail;

CREATE TABLE regions (
    region_id    SMALLINT PRIMARY KEY,
    region_name  TEXT NOT NULL UNIQUE
);

CREATE TABLE stores (
    store_id    SMALLINT PRIMARY KEY,
    store_name  TEXT NOT NULL,
    region_id   SMALLINT NOT NULL REFERENCES regions,
    channel     TEXT NOT NULL CHECK (channel IN ('Store', 'Online')),
    opened_on   DATE NOT NULL
);

CREATE TABLE categories (
    category_id    SMALLINT PRIMARY KEY,
    category_name  TEXT NOT NULL UNIQUE
);

CREATE TABLE products (
    product_id    INTEGER PRIMARY KEY,
    product_name  TEXT NOT NULL,
    category_id   SMALLINT NOT NULL REFERENCES categories,
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    unit_cost     NUMERIC(10,2) NOT NULL CHECK (unit_cost > 0)
);

CREATE TABLE customers (
    customer_id  INTEGER PRIMARY KEY,
    first_name   TEXT NOT NULL,
    last_name    TEXT NOT NULL,
    email        TEXT UNIQUE,
    region_id    SMALLINT NOT NULL REFERENCES regions,
    signup_date  DATE NOT NULL,
    segment      TEXT NOT NULL CHECK (segment IN ('Consumer', 'Small Business', 'Corporate'))
);

CREATE TABLE orders (
    order_id     INTEGER PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES customers,
    store_id     SMALLINT NOT NULL REFERENCES stores,
    order_date   DATE NOT NULL,
    status       TEXT NOT NULL CHECK (status IN ('Completed', 'Cancelled', 'Returned'))
);

CREATE TABLE order_items (
    order_id     INTEGER NOT NULL REFERENCES orders ON DELETE CASCADE,
    line_no      SMALLINT NOT NULL,
    product_id   INTEGER NOT NULL REFERENCES products,
    quantity     SMALLINT NOT NULL CHECK (quantity > 0),
    unit_price   NUMERIC(10,2) NOT NULL,     -- price actually charged
    discount_pct NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 0.5),
    PRIMARY KEY (order_id, line_no)
);

CREATE INDEX ix_orders_date      ON orders (order_date);
CREATE INDEX ix_orders_customer  ON orders (customer_id);
CREATE INDEX ix_items_product    ON order_items (product_id);

-- Revenue logic defined ONCE so every query and BI tool uses the same definition
CREATE VIEW v_sales AS
SELECT
    o.order_id,
    o.order_date,
    date_trunc('month', o.order_date)::date                    AS order_month,
    o.customer_id,
    c.segment,
    o.store_id,
    s.channel,
    r.region_name,                                             -- customer's home region
    oi.line_no,
    oi.product_id,
    p.product_name,
    cat.category_name,
    oi.quantity,
    oi.discount_pct,
    ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct), 2) AS net_revenue,
    ROUND(oi.quantity * p.unit_cost, 2)                           AS cost,
    ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct) - oi.quantity * p.unit_cost, 2) AS gross_profit
FROM orders o
JOIN order_items oi USING (order_id)
JOIN products p     USING (product_id)
JOIN categories cat USING (category_id)
JOIN customers c    USING (customer_id)
JOIN stores s       USING (store_id)
JOIN regions r      ON r.region_id = c.region_id
WHERE o.status = 'Completed';
