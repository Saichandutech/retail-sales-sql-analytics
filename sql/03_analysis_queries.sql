-- =============================================================
-- Business questions answered in SQL (PostgreSQL)
-- Each query starts with "-- name: <id>" and "-- question: <text>"
-- so scripts/run_analysis.py can execute and document them.
-- =============================================================
SET search_path TO retail;

-- name: q01_monthly_revenue_growth
-- question: How is revenue trending month over month and year over year?
-- skills: CTE, date_trunc, LAG window function, NULLIF
WITH monthly AS (
    SELECT order_month,
           SUM(net_revenue)            AS revenue,
           SUM(gross_profit)           AS gross_profit,
           COUNT(DISTINCT order_id)    AS orders
    FROM v_sales
    GROUP BY order_month
)
SELECT
    to_char(order_month, 'YYYY-MM')                                         AS month,
    ROUND(revenue)                                                          AS revenue,
    orders,
    ROUND(100 * gross_profit / revenue, 1)                                  AS margin_pct,
    ROUND(100 * (revenue / NULLIF(LAG(revenue)     OVER w, 0) - 1), 1)      AS mom_growth_pct,
    ROUND(100 * (revenue / NULLIF(LAG(revenue, 12) OVER w, 0) - 1), 1)      AS yoy_growth_pct
FROM monthly
WINDOW w AS (ORDER BY order_month)
ORDER BY order_month;

-- name: q02_fiscal_year_summary
-- question: How did FY2026 compare with FY2025 (fiscal year starts July 1)?
-- skills: conditional aggregation, FILTER clause
SELECT
    'FY' || EXTRACT(year FROM order_date + INTERVAL '6 months')    AS fiscal_year,
    ROUND(SUM(net_revenue))                                        AS revenue,
    ROUND(SUM(gross_profit))                                       AS gross_profit,
    ROUND(100 * SUM(gross_profit) / SUM(net_revenue), 1)           AS margin_pct,
    COUNT(DISTINCT order_id)                                       AS orders,
    COUNT(DISTINCT customer_id)                                    AS active_customers,
    ROUND(SUM(net_revenue) / COUNT(DISTINCT order_id), 2)          AS avg_order_value,
    ROUND(100.0 * SUM(net_revenue) FILTER (WHERE channel = 'Online') / SUM(net_revenue), 1) AS online_share_pct
FROM v_sales
GROUP BY 1
ORDER BY 1;

-- name: q03_category_performance
-- question: Which categories drive revenue vs profit?
-- skills: aggregate + window share-of-total, RANK
SELECT
    category_name,
    ROUND(SUM(net_revenue))                                              AS revenue,
    ROUND(100 * SUM(net_revenue) / SUM(SUM(net_revenue)) OVER (), 1)     AS revenue_share_pct,
    ROUND(SUM(gross_profit))                                             AS gross_profit,
    ROUND(100 * SUM(gross_profit) / SUM(SUM(gross_profit)) OVER (), 1)   AS profit_share_pct,
    ROUND(100 * SUM(gross_profit) / SUM(net_revenue), 1)                 AS margin_pct,
    RANK() OVER (ORDER BY SUM(gross_profit) DESC)                        AS profit_rank
FROM v_sales
GROUP BY category_name
ORDER BY revenue DESC;

-- name: q04_top_products_by_region
-- question: What are the top 3 products by revenue in each region?
-- skills: ROW_NUMBER partitioned ranking (top-N per group)
WITH ranked AS (
    SELECT region_name, product_name,
           ROUND(SUM(net_revenue)) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY region_name ORDER BY SUM(net_revenue) DESC) AS rn
    FROM v_sales
    GROUP BY region_name, product_name
)
SELECT region_name, rn AS rank, product_name, revenue
FROM ranked
WHERE rn <= 3
ORDER BY region_name, rn;

-- name: q05_store_performance
-- question: How does each store compare with the average store in its region?
-- skills: window AVG partitioned by region, comparison to group mean
-- note: the Online store has no regional peer, so it compares only with itself
WITH store_rev AS (
    SELECT v.store_id, SUM(v.net_revenue) AS revenue, COUNT(DISTINCT v.order_id) AS orders
    FROM v_sales v
    WHERE v.order_date >= DATE '2025-07-01'
    GROUP BY v.store_id
)
SELECT
    s.store_name, r.region_name AS store_region, s.channel,
    ROUND(sr.revenue)                                                        AS fy26_revenue,
    sr.orders,
    ROUND(100 * (sr.revenue / AVG(sr.revenue) OVER (PARTITION BY r.region_name, s.channel) - 1), 1) AS vs_region_avg_pct
FROM store_rev sr
JOIN stores s  USING (store_id)
JOIN regions r ON r.region_id = s.region_id
ORDER BY sr.revenue DESC;

-- name: q06_pareto_customers
-- question: What share of revenue comes from the top 20% of customers?
-- skills: NTILE, cumulative SUM window
WITH cust AS (
    SELECT customer_id, SUM(net_revenue) AS revenue
    FROM v_sales GROUP BY customer_id
),
banded AS (
    SELECT revenue, NTILE(5) OVER (ORDER BY revenue DESC) AS quintile FROM cust
)
SELECT
    'Top ' || quintile * 20 || '%'                                              AS customer_group,
    COUNT(*)                                                                     AS customers,
    ROUND(SUM(revenue))                                                          AS revenue,
    ROUND(100 * SUM(SUM(revenue)) OVER (ORDER BY quintile) / SUM(SUM(revenue)) OVER (), 1) AS cumulative_revenue_pct
FROM banded
GROUP BY quintile
ORDER BY quintile;

-- name: q07_rfm_segments
-- question: How can customers be segmented by Recency, Frequency and Monetary value?
-- skills: NTILE scoring, CASE segmentation, multi-step CTEs
WITH base AS (
    SELECT customer_id,
           DATE '2026-06-30' - MAX(order_date) AS recency_days,
           COUNT(DISTINCT order_id)            AS frequency,
           SUM(net_revenue)                    AS monetary
    FROM v_sales GROUP BY customer_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r,
           NTILE(5) OVER (ORDER BY frequency)         AS f,
           NTILE(5) OVER (ORDER BY monetary)          AS m
    FROM base
),
segmented AS (
    SELECT *,
           CASE
             WHEN r >= 4 AND f >= 4 AND m >= 4 THEN '1. Champions'
             WHEN r >= 3 AND f >= 3              THEN '2. Loyal'
             WHEN r >= 4 AND f <= 2              THEN '3. New / Promising'
             WHEN r <= 2 AND f >= 3              THEN '4. At Risk'
             WHEN r <= 2 AND f <= 2              THEN '5. Lost / Dormant'
             ELSE                                     '6. Needs Attention'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                                   AS customers,
       ROUND(AVG(recency_days))                                   AS avg_recency_days,
       ROUND(AVG(frequency), 1)                                   AS avg_orders,
       ROUND(AVG(monetary))                                       AS avg_lifetime_revenue,
       ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_share_pct
FROM segmented
GROUP BY segment
ORDER BY segment;

-- name: q08_cohort_retention
-- question: What share of each first-purchase-quarter cohort buys again in later quarters?
-- (blank = quarter not yet complete; the 2024-Q3 cohort includes all pre-existing customers)
-- skills: cohort analysis, date arithmetic, conditional aggregation pivot
WITH first_purchase AS (
    SELECT customer_id, date_trunc('quarter', MIN(order_date))::date AS cohort
    FROM v_sales GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT v.customer_id, f.cohort,
           ((EXTRACT(year FROM v.order_date) - EXTRACT(year FROM f.cohort)) * 4
            + EXTRACT(quarter FROM v.order_date) - EXTRACT(quarter FROM f.cohort))::int AS q_offset
    FROM v_sales v JOIN first_purchase f USING (customer_id)
)
SELECT
    to_char(cohort, 'YYYY') || '-Q' || EXTRACT(quarter FROM cohort)            AS cohort,
    COUNT(*) FILTER (WHERE q_offset = 0)                                       AS customers,
    CASE WHEN cohort + INTERVAL '3 months' <= DATE '2026-04-01' THEN
         ROUND(100.0 * COUNT(*) FILTER (WHERE q_offset = 1) / COUNT(*) FILTER (WHERE q_offset = 0), 1) END AS q1_pct,
    CASE WHEN cohort + INTERVAL '6 months' <= DATE '2026-04-01' THEN
         ROUND(100.0 * COUNT(*) FILTER (WHERE q_offset = 2) / COUNT(*) FILTER (WHERE q_offset = 0), 1) END AS q2_pct,
    CASE WHEN cohort + INTERVAL '9 months' <= DATE '2026-04-01' THEN
         ROUND(100.0 * COUNT(*) FILTER (WHERE q_offset = 3) / COUNT(*) FILTER (WHERE q_offset = 0), 1) END AS q3_pct,
    CASE WHEN cohort + INTERVAL '12 months' <= DATE '2026-04-01' THEN
         ROUND(100.0 * COUNT(*) FILTER (WHERE q_offset = 4) / COUNT(*) FILTER (WHERE q_offset = 0), 1) END AS q4_pct
FROM activity
GROUP BY cohort
ORDER BY cohort;

-- name: q09_basket_pairs
-- question: Which category pairs are most often bought together?
-- skills: self-join, support / confidence / lift (market basket analysis)
WITH order_cats AS (
    SELECT DISTINCT order_id, category_name FROM v_sales
),
pairs AS (
    SELECT a.category_name AS cat_a, b.category_name AS cat_b, COUNT(*) AS together
    FROM order_cats a
    JOIN order_cats b ON a.order_id = b.order_id AND a.category_name < b.category_name
    GROUP BY 1, 2
),
singles AS (
    SELECT category_name, COUNT(*) AS n FROM order_cats GROUP BY 1
),
total AS (SELECT COUNT(DISTINCT order_id) AS n FROM order_cats)
SELECT
    p.cat_a || ' + ' || p.cat_b                                     AS category_pair,
    p.together                                                      AS orders_together,
    ROUND(100.0 * p.together / sa.n, 1)                             AS pct_of_a_orders_with_b,
    ROUND((p.together::numeric * t.n) / (sa.n * sb.n), 2)           AS lift
FROM pairs p
JOIN singles sa ON sa.category_name = p.cat_a
JOIN singles sb ON sb.category_name = p.cat_b
CROSS JOIN total t
ORDER BY lift DESC
LIMIT 8;

-- name: q10_returns_and_cancellations
-- question: Where are returns and cancellations concentrated?
-- skills: LEFT JOIN on all statuses, conditional aggregation, HAVING
SELECT
    cat.category_name,
    COUNT(DISTINCT o.order_id)                                                          AS orders,
    ROUND(100.0 * COUNT(DISTINCT o.order_id) FILTER (WHERE o.status = 'Returned')  / COUNT(DISTINCT o.order_id), 2) AS return_rate_pct,
    ROUND(100.0 * COUNT(DISTINCT o.order_id) FILTER (WHERE o.status = 'Cancelled') / COUNT(DISTINCT o.order_id), 2) AS cancel_rate_pct,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) FILTER (WHERE o.status = 'Returned')) AS returned_value
FROM orders o
JOIN order_items oi USING (order_id)
JOIN products p     USING (product_id)
JOIN categories cat USING (category_id)
GROUP BY cat.category_name
HAVING COUNT(DISTINCT o.order_id) > 100
ORDER BY returned_value DESC;

-- name: q11_discount_impact
-- question: Do holiday discounts grow volume enough to offset lower margin?
-- skills: CASE bucketing, comparing periods
SELECT
    CASE WHEN EXTRACT(month FROM v.order_date) IN (11, 12) THEN 'Nov–Dec (holiday)' ELSE 'Jan–Oct' END AS period,
    ROUND(AVG(v.discount_pct) * 100, 1)                                       AS avg_discount_pct,
    ROUND(SUM(v.net_revenue) / COUNT(DISTINCT v.order_month))                  AS avg_monthly_revenue,
    ROUND(SUM(v.gross_profit) / COUNT(DISTINCT v.order_month))                 AS avg_monthly_profit,
    ROUND(100 * SUM(v.gross_profit) / SUM(v.net_revenue), 1)                   AS margin_pct
FROM v_sales v
GROUP BY 1
ORDER BY 1 DESC;

-- name: q12_running_total_and_moving_avg
-- question: What is the cumulative FY2026 revenue and its 7-day moving average (last 14 days shown)?
-- skills: running SUM, ROWS BETWEEN frame, generate_series to fill missing days
WITH days AS (
    SELECT d::date AS day FROM generate_series(DATE '2025-07-01', DATE '2026-06-30', INTERVAL '1 day') d
),
daily AS (
    SELECT days.day, COALESCE(SUM(v.net_revenue), 0) AS revenue
    FROM days LEFT JOIN v_sales v ON v.order_date = days.day
    GROUP BY days.day
),
calc AS (
    SELECT day, revenue,
           SUM(revenue) OVER (ORDER BY day)                                        AS fy_cumulative,
           AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7d
    FROM daily
)
SELECT day, ROUND(revenue) AS revenue, ROUND(ma_7d) AS moving_avg_7d, ROUND(fy_cumulative) AS fy_cumulative
FROM calc
WHERE day > DATE '2026-06-16'
ORDER BY day;

-- name: q13_purchase_frequency_by_segment
-- question: How often do customers come back, and how does it differ by customer segment?
-- skills: LAG over each customer's order history, date differences, PERCENTILE_CONT median
WITH orders_by_customer AS (
    SELECT DISTINCT customer_id, segment, order_id, order_date
    FROM v_sales
),
gaps AS (
    SELECT customer_id, segment,
           order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS days_since_prev
    FROM orders_by_customer
),
per_customer AS (
    SELECT customer_id, segment, COUNT(*) AS orders
    FROM orders_by_customer
    GROUP BY customer_id, segment
)
SELECT
    p.segment,
    COUNT(*)                                                                    AS customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE p.orders >= 2) / COUNT(*), 1)          AS repeat_customer_pct,
    ROUND(AVG(p.orders), 1)                                                     AS avg_orders_per_customer,
    (SELECT ROUND(AVG(g.days_since_prev)) FROM gaps g
      WHERE g.segment = p.segment AND g.days_since_prev IS NOT NULL)            AS avg_days_between_orders,
    (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY g.days_since_prev) FROM gaps g
      WHERE g.segment = p.segment AND g.days_since_prev IS NOT NULL)            AS median_days_between_orders
FROM per_customer p
GROUP BY p.segment
ORDER BY avg_orders_per_customer DESC;

-- name: q14_new_vs_returning_revenue
-- question: How much revenue comes from new versus returning customers each quarter?
-- skills: first-purchase CTE, CASE classification, conditional SUM, share of total
WITH first_order AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM v_sales
    GROUP BY customer_id
),
classified AS (
    SELECT
        date_trunc('quarter', v.order_date)::date AS quarter,
        v.customer_id,
        v.net_revenue,
        CASE WHEN date_trunc('quarter', f.first_order_date) = date_trunc('quarter', v.order_date)
             THEN 'New' ELSE 'Returning' END AS customer_type
    FROM v_sales v
    JOIN first_order f USING (customer_id)
)
SELECT
    to_char(quarter, 'YYYY') || '-Q' || EXTRACT(quarter FROM quarter)                       AS quarter,
    COUNT(DISTINCT customer_id) FILTER (WHERE customer_type = 'New')                          AS new_customers,
    COUNT(DISTINCT customer_id) FILTER (WHERE customer_type = 'Returning')                    AS returning_customers,
    ROUND(SUM(net_revenue) FILTER (WHERE customer_type = 'New'))                              AS new_revenue,
    ROUND(SUM(net_revenue) FILTER (WHERE customer_type = 'Returning'))                        AS returning_revenue,
    ROUND(100 * SUM(net_revenue) FILTER (WHERE customer_type = 'Returning') / SUM(net_revenue), 1) AS returning_share_pct
FROM classified
WHERE quarter >= DATE '2024-10-01'   -- 2024-Q3 is excluded: every pre-existing customer looks "new" in the first quarter
GROUP BY quarter
ORDER BY quarter;
