-- =============================================================
-- Synthetic seed data, generated entirely in SQL.
-- setseed() makes every run produce identical data.
-- Period: 2024-07-01 to 2026-06-30 (two fiscal years)
-- =============================================================
SET search_path TO retail;
DO $$ BEGIN PERFORM setseed(0.42); END $$;

INSERT INTO regions VALUES
  (1, 'Northeast'), (2, 'Southeast'), (3, 'Midwest'), (4, 'Southwest'), (5, 'West');

INSERT INTO stores VALUES
  (1,  'Boston Downtown',   1, 'Store',  '2019-04-01'),
  (2,  'Newark Plaza',      1, 'Store',  '2020-09-15'),
  (3,  'Atlanta Midtown',   2, 'Store',  '2018-06-01'),
  (4,  'Orlando Park',      2, 'Store',  '2021-03-20'),
  (5,  'Chicago Loop',      3, 'Store',  '2017-11-11'),
  (6,  'Columbus East',     3, 'Store',  '2022-02-01'),
  (7,  'Dallas Uptown',     4, 'Store',  '2018-08-08'),
  (8,  'Houston Galleria',  4, 'Store',  '2019-10-10'),
  (9,  'Denton Square',     4, 'Store',  '2023-05-05'),
  (10, 'Seattle Center',    5, 'Store',  '2020-01-15'),
  (11, 'San Diego Bay',     5, 'Store',  '2021-07-07'),
  (12, 'Online Store',      5, 'Online', '2016-01-01');

INSERT INTO categories VALUES
  (1, 'Laptops'), (2, 'Monitors'), (3, 'Accessories'), (4, 'Audio'),
  (5, 'Networking'), (6, 'Storage'), (7, 'Office Furniture'), (8, 'Software');

-- 64 products: 8 per category, prices by category band
INSERT INTO products (product_id, product_name, category_id, unit_price, unit_cost)
SELECT
    (c.category_id - 1) * 8 + n                                  AS product_id,
    c.category_name || ' Model ' || chr(64 + n)                  AS product_name,
    c.category_id,
    ROUND((band.lo + (band.hi - band.lo) * (n - 1) / 7.0)::numeric, 2) AS unit_price,
    ROUND((band.lo + (band.hi - band.lo) * (n - 1) / 7.0)::numeric * band.cost_ratio, 2) AS unit_cost
FROM categories c
JOIN (VALUES (1, 650, 2200, 0.82), (2, 160, 900, 0.74), (3, 12, 90, 0.45), (4, 35, 380, 0.58),
             (5, 40, 420, 0.62), (6, 55, 450, 0.68), (7, 120, 950, 0.55), (8, 30, 400, 0.20))
     AS band(category_id, lo, hi, cost_ratio) USING (category_id)
CROSS JOIN generate_series(1, 8) AS n;

-- 4,000 customers with fictional names; ids assigned in signup order
WITH c AS (
    SELECT
        (ARRAY['Alex','Jordan','Taylor','Morgan','Casey','Riley','Avery','Quinn','Jamie','Drew',
               'Sam','Robin','Kai','Reese','Parker','Rowan','Emerson','Hayden','Logan','Skyler'])[1 + floor(random()*20)::int] AS first_name,
        (ARRAY['Rivera','Patel','Nguyen','Kim','Garcia','Smith','Okafor','Chen','Silva','Khan',
               'Lopez','Brown','Ali','Rossi','Murphy','Singh','Novak','Haddad','Tanaka','Clark'])[1 + floor(random()*20)::int] AS last_name,
        1 + floor(random() * 5)::int AS region_id,
        DATE '2023-01-01' + floor(random() ^ 0.9 * 1260)::int AS signup_date,
        random() AS r_seg, random() AS r_seg2, g
    FROM generate_series(1, 4000) g
)
INSERT INTO customers
SELECT
    row_number() OVER (ORDER BY signup_date, g),
    first_name, last_name,
    'customer' || row_number() OVER (ORDER BY signup_date, g) || '@example.com',
    region_id, signup_date,
    CASE WHEN r_seg < 0.70 THEN 'Consumer' WHEN r_seg2 < 0.65 THEN 'Small Business' ELSE 'Corporate' END
FROM c;

-- Orders: demand grows ~20% a year (linearly rising density), holiday uplift via extra Nov/Dec orders.
-- Each order goes to a customer who had already signed up; earlier customers buy more (random()^2 skew).
CREATE TEMP TABLE signup_curve AS
SELECT d::date AS day, (SELECT COUNT(*) FROM customers c WHERE c.signup_date <= d) AS eligible
FROM generate_series(DATE '2024-07-01', DATE '2026-06-30', INTERVAL '1 day') d;

WITH base AS (
    SELECT g, random() AS u, random() AS r_cust, random() AS r_store, random() AS r_status
    FROM generate_series(1, 36000) g
),
dated AS (   -- inverse CDF of a density rising from 1 to 1.45 across the two years
    SELECT b.*, DATE '2024-07-01' + floor(730 * (sqrt(1 + 0.45 * b.u * 2.45) - 1) / 0.45)::int AS order_date
    FROM base b
),
holiday AS (
    SELECT g, u, random() AS r_cust, r_store, r_status,
           (CASE WHEN u < 0.45 THEN DATE '2024-11-01' ELSE DATE '2025-11-01' END) + floor(random() * 61)::int AS order_date
    FROM dated WHERE random() < 0.22
),
all_orders AS (
    SELECT x.order_date, x.r_store, x.r_status,
           1 + floor(x.r_cust ^ 1.8 * sc.eligible)::int AS customer_id
    FROM (SELECT order_date, r_cust, r_store, r_status FROM dated
          UNION ALL SELECT order_date, r_cust, r_store, r_status FROM holiday) x
    JOIN signup_curve sc ON sc.day = x.order_date
)
INSERT INTO orders (order_id, customer_id, store_id, order_date, status)
SELECT
    row_number() OVER (ORDER BY a.order_date, a.customer_id, a.r_store)::int,
    a.customer_id,
    CASE WHEN r_store < 0.35 THEN 12 ELSE rs.store_id END,   -- 35% online, rest a store in the customer's region
    order_date,
    CASE WHEN r_status < 0.03 THEN 'Cancelled' WHEN r_status < 0.08 THEN 'Returned' ELSE 'Completed' END
FROM all_orders a
JOIN customers cu ON cu.customer_id = a.customer_id
LEFT JOIN (
    SELECT store_id, region_id,
           row_number() OVER (PARTITION BY region_id ORDER BY store_id) AS rn,
           COUNT(*)     OVER (PARTITION BY region_id)                    AS cnt
    FROM stores WHERE channel = 'Store'
) rs ON rs.region_id = cu.region_id
    AND rs.rn = 1 + floor((a.r_store - 0.35) / 0.65 * rs.cnt)::int;

-- 1–4 lines per order; later lines often from the first line's category (drives basket analysis)
WITH sized AS (   -- line count drawn per order (in its own CTE so random() runs once per row)
    SELECT order_id, order_date, 1 + floor(random() ^ 1.6 * 4)::int AS n_lines FROM orders
),
lines AS (
    SELECT o.order_id, o.order_date, l AS line_no, random() AS r1, random() AS r2, random() AS r3
    FROM sized o
    CROSS JOIN LATERAL generate_series(1, o.n_lines) AS l
),
first_cat AS (
    SELECT order_id, 1 + floor(random() ^ 1.2 * 8)::int AS cat FROM orders
),
picked AS (
    SELECT l.*,
           CASE
             WHEN l.line_no = 1 THEN f.cat
             WHEN f.cat = 1 AND l.r1 < 0.55 THEN (ARRAY[2,3,8])[1 + floor(l.r3 * 3)::int]   -- laptop buyers add monitors/accessories/software
             WHEN l.r1 < 0.45 THEN f.cat
             ELSE 1 + floor(l.r3 * 8)::int
           END AS cat
    FROM lines l JOIN first_cat f USING (order_id)
)
INSERT INTO order_items (order_id, line_no, product_id, quantity, unit_price, discount_pct)
SELECT
    p.order_id,
    p.line_no,
    pr.product_id,
    CASE WHEN p.cat IN (3, 8) THEN 1 + floor(p.r2 * 3)::int ELSE 1 END,
    pr.unit_price,
    CASE WHEN EXTRACT(month FROM p.order_date) IN (11, 12) AND p.r2 < 0.6 THEN 0.15
         WHEN p.r2 < 0.12 THEN 0.10
         ELSE 0 END
FROM picked p
JOIN products pr ON pr.product_id = (p.cat - 1) * 8 + 1 + floor(p.r2 ^ 1.5 * 8)::int;

-- Monitors have a known quality issue: extra returns on orders containing a monitor
UPDATE orders o SET status = 'Returned'
WHERE o.status = 'Completed'
  AND o.order_date >= DATE '2025-09-01'
  AND EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id AND oi.product_id BETWEEN 9 AND 16)
  AND random() < 0.07;

ANALYZE;
