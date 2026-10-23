-- Problem ltv/03: How much of lifetime revenue comes in the first month  [Hard]
-- Pattern: LTV: cohort month + FILTER on the cohort month; ratio of sums vs average of ratios
-- Variant: two answers to "first-month share" that differ, side by side
--
-- Task: Only 'delivered' orders count. A customer's cohort is the calendar month of their first
--   counted order; first_month_revenue = their revenue in that calendar month, lifetime_revenue
--   = all their revenue. For every cohort ('YYYY-MM') return cohort_month, customers,
--   first_month_revenue (sum), lifetime_revenue (sum),
--     share_of_totals_pct    = sum of first-month revenue / sum of lifetime revenue * 100
--     avg_customer_share_pct = average over customers of (first-month / lifetime) * 100
--   both rounded to 1 decimal. Sort by cohort_month.
-- Learn: grinding/sql-ltv.md, B2–B3

-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-01-05 | 100000     | delivered |
| 2        | 1           | 2024-02-10 | 300000     | delivered |
| 3        | 1           | 2024-04-10 | 600000     | delivered |
| 4        | 2           | 2024-01-28 | 500000     | delivered |
| 5        | 3           | 2024-02-01 | 200000     | delivered |
| 6        | 3           | 2024-02-20 | 200000     | delivered |
| 7        | 3           | 2024-03-05 | 600000     | delivered |
| 8        | 4           | 2024-02-14 | 300000     | delivered |
| 9        | 4           | 2024-04-14 | 300000     | delivered |
| 10       | 5           | 2024-01-31 | 900000     | cancelled |
| 11       | 5           | 2024-02-29 | 1000000    | delivered |

-- EXPECTED
| cohort_month | customers | first_month_revenue | lifetime_revenue | share_of_totals_pct | avg_customer_share_pct |
|--------------|-----------|---------------------|------------------|---------------------|------------------------|
| 2024-01      | 2         | 600000              | 1500000          | 40.0                | 55.0                   |
| 2024-02      | 3         | 1700000             | 2600000          | 65.4                | 63.3                   |

-- QUERY
WITH counted AS (
  SELECT customer_id, amount_vnd,
         DATE_TRUNC('month', order_date)::date AS m,
         MIN(DATE_TRUNC('month', order_date)::date) OVER (PARTITION BY customer_id) AS cohort
  FROM orders
  WHERE status = 'delivered'
),
per_customer AS (
  SELECT customer_id, cohort,
         SUM(amount_vnd) FILTER (WHERE m = cohort) AS first_rev,
         SUM(amount_vnd)                           AS life_rev
  FROM counted
  GROUP BY customer_id, cohort
)
SELECT TO_CHAR(cohort, 'YYYY-MM') AS cohort_month,
       COUNT(*)       AS customers,
       SUM(first_rev) AS first_month_revenue,
       SUM(life_rev)  AS lifetime_revenue,
       ROUND(100.0 * SUM(first_rev) / SUM(life_rev), 1)   AS share_of_totals_pct,     -- big customers weigh more
       ROUND(AVG(100.0 * first_rev / life_rev), 1)        AS avg_customer_share_pct   -- every customer weighs 1
FROM per_customer
GROUP BY cohort
ORDER BY cohort;
