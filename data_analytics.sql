/* ============================================================
   SCHEMA SETUP: Core tables for trends & patterns analysis
   ============================================================ */

/* Customers table */
CREATE TABLE customers (
    customer_id     SERIAL PRIMARY KEY,          -- unique identifier
    customer_name   VARCHAR(100) NOT NULL,
    segment         VARCHAR(50),                 -- e.g., 'Retail', 'Corporate'
    signup_date     DATE NOT NULL
);

/* Products table */
CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    product_name    VARCHAR(100) NOT NULL,
    category        VARCHAR(50)                   -- e.g., 'Electronics', 'Furniture'
);

/* Sales table */
CREATE TABLE sales (
    sale_id         SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL,
    product_id      INT NOT NULL,
    order_date      DATE NOT NULL,
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    region          VARCHAR(50),
    -- Foreign keys
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_product  FOREIGN KEY (product_id)  REFERENCES products(product_id)
);

/* Calendar table */
CREATE TABLE calendar (
    date            DATE PRIMARY KEY,
    year            INT NOT NULL,
    month           INT NOT NULL,
    week            INT,
    day_of_week     VARCHAR(10)
);
/* ============================================================
   REPORT: Trends & Patterns via Window Functions, Subqueries, CTEs
   Author: Vidhi
   Purpose: Reproducible analytics for monthly trends, rankings,
            cohorts, price/mix decomposition, and growth streaks.
   ============================================================ */

/* ---------------------------
   0) Setup: derived helpers
   --------------------------- */

/* View: monthly revenue by order month */
CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT
  DATE_TRUNC('month', order_date) AS order_month,
  SUM(quantity * unit_price) AS revenue
FROM sales
GROUP BY DATE_TRUNC('month', order_date);

/* View: product revenue by region */
CREATE OR REPLACE VIEW v_product_revenue_region AS
SELECT
  s.region,
  p.product_name,
  SUM(s.quantity * s.unit_price) AS revenue
FROM sales s
JOIN products p ON p.product_id = s.product_id
GROUP BY s.region, p.product_name;

/* View: customer revenue with segment */
CREATE OR REPLACE VIEW v_customer_revenue AS
SELECT
  c.customer_id,
  c.customer_name,
  c.segment,
  SUM(s.quantity * s.unit_price) AS revenue
FROM customers c
JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.segment;

/* ---------------------------------------------------------
   1) Trend: monthly revenue + 3-month moving average (Window)
   --------------------------------------------------------- */
WITH trend AS (
  SELECT
    order_month,
    revenue,
    AVG(revenue) OVER (
      ORDER BY order_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS ma_3m
  FROM v_monthly_revenue
)
SELECT
  order_month,
  revenue,
  ma_3m,
  CASE
    WHEN ma_3m IS NULL THEN NULL
    ELSE ROUND(100.0 * (revenue - ma_3m) / NULLIF(ma_3m, 0), 2)
  END AS pct_vs_ma_3m
FROM trend
ORDER BY order_month;

/* ---------------------------------------------------------
   2) Ranking: top 5 products by revenue within each region (Window)
   --------------------------------------------------------- */
WITH ranked AS (
  SELECT
    region,
    product_name,
    revenue,
    RANK() OVER (PARTITION BY region ORDER BY revenue DESC) AS rnk
  FROM v_product_revenue_region
)
SELECT region, product_name, revenue, rnk
FROM ranked
WHERE rnk <= 5
ORDER BY region, rnk;

/* ---------------------------------------------------------
   3) Distribution: customer deciles within segment (Window)
   --------------------------------------------------------- */
WITH banded AS (
  SELECT
    customer_id,
    customer_name,
    segment,
    revenue,
    NTILE(10) OVER (PARTITION BY segment ORDER BY revenue DESC) AS decile
  FROM v_customer_revenue
)
SELECT
  segment,
  decile,
  COUNT(*) AS customers,
  SUM(revenue) AS total_revenue,
  ROUND(
    100.0 * SUM(revenue)
    / NULLIF(SUM(SUM(revenue)) OVER (PARTITION BY segment), 0),
    2
  ) AS pct_segment_rev
FROM banded
GROUP BY segment, decile
ORDER BY segment, decile;

/* ---------------------------------------------------------
   4) Benchmarking: monthly revenue vs overall average (Non-correlated subquery)
   --------------------------------------------------------- */
SELECT
  DATE_TRUNC('month', s.order_date) AS order_month,
  SUM(s.quantity * s.unit_price) AS revenue,
  (SELECT AVG(month_rev)
   FROM (
     SELECT SUM(quantity * unit_price) AS month_rev
     FROM sales
     GROUP BY DATE_TRUNC('month', order_date)
   ) t) AS avg_monthly_rev
FROM sales s
GROUP BY DATE_TRUNC('month', s.order_date)
ORDER BY order_month;

/* ---------------------------------------------------------
   5) Share of segment: customer revenue share (Correlated subquery)
   --------------------------------------------------------- */
SELECT
  c.customer_id,
  c.customer_name,
  c.segment,
  SUM(s.quantity * s.unit_price) AS customer_rev,
  (
    SELECT SUM(s2.quantity * s2.unit_price)
    FROM sales s2
    JOIN customers c2 ON c2.customer_id = s2.customer_id
    WHERE c2.segment = c.segment
  ) AS segment_rev,
  ROUND(
    100.0 * SUM(s.quantity * s.unit_price)
    / NULLIF((
      SELECT SUM(s2.quantity * s2.unit_price)
      FROM sales s2
      JOIN customers c2 ON c2.customer_id = s2.customer_id
      WHERE c2.segment = c.segment
    ), 0), 2
  ) AS pct_of_segment
FROM customers c
JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.segment
ORDER BY pct_of_segment DESC;

/* ---------------------------------------------------------
   6) Price/Mix decomposition vs base month (CTEs + subqueries)
   --------------------------------------------------------- */
WITH base_period AS (
  SELECT DATE_TRUNC('month', MIN(order_date)) AS base_month FROM sales
),
current AS (
  SELECT
    p.category,
    DATE_TRUNC('month', s.order_date) AS order_month,
    SUM(s.quantity) AS qty,
    AVG(s.unit_price) AS avg_price
  FROM sales s
  JOIN products p ON p.product_id = s.product_id
  GROUP BY p.category, DATE_TRUNC('month', s.order_date)
),
decomposition AS (
  SELECT
    c.category,
    c.order_month,
    c.qty,
    c.avg_price,
    /* base values via correlated subqueries */
    (SELECT cb.qty
     FROM current cb
     JOIN base_period bp ON TRUE
     WHERE cb.category = c.category AND cb.order_month = bp.base_month) AS base_qty,
    (SELECT cb.avg_price
     FROM current cb
     JOIN base_period bp ON TRUE
     WHERE cb.category = c.category AND cb.order_month = bp.base_month) AS base_price
  FROM current c
)
SELECT
  category,
  order_month,
  qty * avg_price AS revenue,
  (qty - base_qty) * base_price AS volume_effect,
  base_qty * (avg_price - base_price) AS price_effect,
  (qty - base_qty) * (avg_price - base_price) AS mix_effect
FROM decomposition
ORDER BY category, order_month;

/* ---------------------------------------------------------
   7) Cohort retention by signup month (Non-recursive CTE)
   --------------------------------------------------------- */
WITH cohorts AS (
  SELECT DATE_TRUNC('month', signup_date) AS cohort_month, customer_id
  FROM customers
),
activity AS (
  SELECT customer_id, DATE_TRUNC('month', order_date) AS active_month
  FROM sales
  GROUP BY customer_id, DATE_TRUNC('month', order_date)
),
cohort_activity AS (
  SELECT c.cohort_month, a.active_month, COUNT(DISTINCT a.customer_id) AS active_customers
  FROM cohorts c
  JOIN activity a ON a.customer_id = c.customer_id
  GROUP BY c.cohort_month, a.active_month
),
cohort_size AS (
  SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
  FROM cohorts
  GROUP BY cohort_month
)
SELECT
  ca.cohort_month,
  ca.active_month,
  ca.active_customers,
  cs.cohort_customers,
  ROUND(100.0 * ca.active_customers / NULLIF(cs.cohort_customers, 0), 2) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs USING (cohort_month)
ORDER BY cohort_month, active_month;

/* ---------------------------------------------------------
   8) Consecutive monthly growth streaks (Recursive CTE)
   --------------------------------------------------------- */
/* Note: Some engines need alternative recursion; this pattern works in Postgres. */
WITH monthly AS (
  SELECT
    DATE_TRUNC('month', order_date) AS order_month,
    SUM(quantity * unit_price) AS revenue
  FROM sales
  GROUP BY DATE_TRUNC('month', order_date)
),
ordered AS (
  SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS prev_rev
  FROM monthly
),
seed AS (
  SELECT order_month, revenue, prev_rev, 1 AS streak_len
  FROM ordered
  WHERE prev_rev IS NULL OR revenue <= prev_rev
),
rec AS (
  SELECT * FROM seed
  UNION ALL
  SELECT
    o.order_month,
    o.revenue,
    o.prev_rev,
    CASE WHEN o.prev_rev IS NOT NULL AND o.revenue > o.prev_rev
         THEN r.streak_len + 1
         ELSE 1
    END AS streak_len
  FROM ordered o
  JOIN rec r ON o.order_month = (
    SELECT MIN(order_month) FROM ordered WHERE order_month > r.order_month
  )
)
SELECT order_month, revenue, streak_len
FROM rec
ORDER BY order_month;