-- =============================================================
-- Reusable objects for recurring reporting
-- =============================================================
SET search_path TO retail;

-- 1. Parameterised sales summary: SELECT * FROM fn_sales_summary('2026-01-01', '2026-03-31', 'category');
CREATE OR REPLACE FUNCTION fn_sales_summary(p_start DATE, p_end DATE, p_group_by TEXT DEFAULT 'category')
RETURNS TABLE (dimension TEXT, revenue NUMERIC, gross_profit NUMERIC, margin_pct NUMERIC, orders BIGINT)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF p_group_by NOT IN ('category', 'region', 'channel', 'segment') THEN
        RAISE EXCEPTION 'p_group_by must be one of category, region, channel, segment (got %)', p_group_by;
    END IF;
    IF p_end < p_start THEN
        RAISE EXCEPTION 'p_end (%) is before p_start (%)', p_end, p_start;
    END IF;

    RETURN QUERY
    SELECT
        CASE p_group_by
            WHEN 'category' THEN v.category_name
            WHEN 'region'   THEN v.region_name
            WHEN 'channel'  THEN v.channel
            ELSE v.segment
        END                                                AS dimension,
        ROUND(SUM(v.net_revenue), 2),
        ROUND(SUM(v.gross_profit), 2),
        ROUND(100 * SUM(v.gross_profit) / NULLIF(SUM(v.net_revenue), 0), 1),
        COUNT(DISTINCT v.order_id)
    FROM v_sales v
    WHERE v.order_date BETWEEN p_start AND p_end
    GROUP BY 1
    ORDER BY 2 DESC;
END;
$$;

-- 2. Customer RFM scores, materialised for fast dashboard reads
DROP MATERIALIZED VIEW IF EXISTS mv_customer_rfm;
CREATE MATERIALIZED VIEW mv_customer_rfm AS
WITH base AS (
    SELECT customer_id,
           MAX(order_date)          AS last_order_date,
           COUNT(DISTINCT order_id) AS frequency,
           SUM(net_revenue)         AS monetary
    FROM v_sales GROUP BY customer_id
)
SELECT b.*,
       (SELECT MAX(order_date) FROM orders) - b.last_order_date AS recency_days,
       NTILE(5) OVER (ORDER BY b.last_order_date) AS r_score,
       NTILE(5) OVER (ORDER BY b.frequency)       AS f_score,
       NTILE(5) OVER (ORDER BY b.monetary)        AS m_score
FROM base b;
CREATE UNIQUE INDEX ON mv_customer_rfm (customer_id);

-- 3. Procedure the scheduler calls after each nightly load
CREATE OR REPLACE PROCEDURE sp_refresh_reporting()
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_rfm;
    RAISE NOTICE 'mv_customer_rfm refreshed at %', now();
END;
$$;

-- 4. Data-quality checks: every row returned is a problem (empty result = healthy)
CREATE OR REPLACE VIEW v_data_quality_issues AS
SELECT 'Order with no line items' AS issue, o.order_id::text AS record
FROM orders o LEFT JOIN order_items oi USING (order_id) WHERE oi.order_id IS NULL
UNION ALL
SELECT 'Order dated before customer signup', o.order_id::text
FROM orders o JOIN customers c USING (customer_id) WHERE o.order_date < c.signup_date
UNION ALL
SELECT 'Item sold below cost after discount', oi.order_id || '-' || oi.line_no
FROM order_items oi JOIN products p USING (product_id)
WHERE oi.unit_price * (1 - oi.discount_pct) < p.unit_cost
UNION ALL
SELECT 'Item price differs from list price', oi.order_id || '-' || oi.line_no
FROM order_items oi JOIN products p USING (product_id) WHERE oi.unit_price <> p.unit_price;
