-- Problem cohort/01: Monthly cohort retention  [Hard]
-- Pattern: Cohort: MIN() OVER + month offset + FIRST_VALUE
-- Variant: core: cohort = month of the first order
--
-- Task: A customer's cohort is the month of their first order. For every (cohort_month,
--   month_offset) with activity return active_customers (distinct customers with an order) and
--   retention_pct = active_customers / cohort size * 100, rounded to 1 decimal. month_offset is
--   the number of months since the cohort month (0, 1, 2, ...). cohort_month is formatted 'YYYY-
--   MM'. Sort by cohort_month, month_offset.
-- Learn: grinding/sql-analytics-patterns.md, mục 3.2

-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2023-11-10 |
| 2        | 1           | 2023-12-05 |
| 3        | 1           | 2024-01-15 |
| 4        | 1           | 2024-02-20 |
| 5        | 2           | 2024-01-08 |
| 6        | 2           | 2024-03-12 |
| 7        | 3           | 2024-01-20 |

-- EXPECTED
| cohort_month | month_offset | active_customers | retention_pct |
|--------------|--------------|------------------|---------------|
| 2023-11      | 0            | 1                | 100.0         |
| 2023-11      | 1            | 1                | 100.0         |
| 2023-11      | 2            | 1                | 100.0         |
| 2023-11      | 3            | 1                | 100.0         |
| 2024-01      | 0            | 2                | 100.0         |
| 2024-01      | 2            | 1                | 50.0          |

-- QUERY
WITH clean AS (
  SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
  FROM orders
),
c AS (
  SELECT customer_id, order_month,
         MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
  FROM clean
),
a AS (
  SELECT cohort_month,
         (EXTRACT(YEAR FROM order_month)::int * 12 + EXTRACT(MONTH FROM order_month)::int)
       - (EXTRACT(YEAR FROM cohort_month)::int * 12 + EXTRACT(MONTH FROM cohort_month)::int) AS month_offset,
         COUNT(DISTINCT customer_id) AS active_customers
  FROM c
  GROUP BY cohort_month, month_offset
)
SELECT TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month, month_offset, active_customers,
       ROUND(100.0 * active_customers /
             FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1) AS retention_pct
FROM a
ORDER BY cohort_month, month_offset;
