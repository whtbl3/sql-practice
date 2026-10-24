-- Problem ltv/04: Cumulative LTV per customer by cohort age  [Hard]
-- Pattern: LTV: cohort spine (cohort x every month up to the report end) + LEFT JOIN revenue + running SUM / cohort size
-- Variant: a cumulative curve (it never goes down), months without revenue must still appear
--
-- Task: Report end = 2024-06. Only 'delivered' orders up to 2024-06-30 count. A customer's cohort
--   is the month of their first counted order; cohort_size = customers in the cohort. For every
--   cohort and every month_offset from 0 (the cohort month) to the report end, return
--   cohort_month ('YYYY-MM'), month_offset, cohort_size and cum_ltv = total revenue of the
--   cohort's customers from the cohort month up to and including that month, divided by
--   cohort_size, rounded to whole VND. Sort by cohort_month, month_offset.
-- Learn: grinding/sql-ltv.md, V3

-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 7           | 2024-03-03 | 200000     | delivered |
| 2        | 1           | 2024-04-02 | 100000     | delivered |
| 3        | 2           | 2024-04-20 | 300000     | delivered |
| 4        | 1           | 2024-06-11 | 200000     | delivered |
| 5        | 3           | 2024-05-05 | 500000     | delivered |
| 6        | 4           | 2024-05-06 | 100000     | delivered |
| 7        | 4           | 2024-05-07 | 100000     | delivered |
| 8        | 5           | 2024-05-30 | 300000     | delivered |
| 9        | 5           | 2024-06-02 | 300000     | delivered |
| 10       | 6           | 2024-06-15 | 50000      | delivered |
| 11       | 6           | 2024-06-16 | 80000      | cancelled |
| 12       | 2           | 2024-07-01 | 900000     | delivered |

-- EXPECTED
| cohort_month | month_offset | cohort_size | cum_ltv |
|--------------|--------------|-------------|---------|
| 2024-03      | 0            | 1           | 200000  |
| 2024-03      | 1            | 1           | 200000  |
| 2024-03      | 2            | 1           | 200000  |
| 2024-03      | 3            | 1           | 200000  |
| 2024-04      | 0            | 2           | 200000  |
| 2024-04      | 1            | 2           | 200000  |
| 2024-04      | 2            | 2           | 300000  |
| 2024-05      | 0            | 3           | 333333  |
| 2024-05      | 1            | 3           | 433333  |
| 2024-06      | 0            | 1           | 50000   |

-- QUERY
WITH counted AS (
  SELECT customer_id, amount_vnd, DATE_TRUNC('month', order_date)::date AS m
  FROM orders
  WHERE status = 'delivered' AND order_date < DATE '2024-07-01'
),
cohort_of AS (
  SELECT customer_id, MIN(m) AS cohort FROM counted GROUP BY customer_id
),
sizes AS (
  SELECT cohort, COUNT(*) AS cohort_size FROM cohort_of GROUP BY cohort
),
monthly AS (                                        -- revenue of each cohort in each calendar month
  SELECT co.cohort, c.m, SUM(c.amount_vnd) AS revenue
  FROM counted c JOIN cohort_of co ON co.customer_id = c.customer_id
  GROUP BY co.cohort, c.m
),
grid AS (                                           -- the spine: every month from the cohort to the report end
  SELECT s.cohort, s.cohort_size, g.m::date AS m
  FROM sizes s
  CROSS JOIN LATERAL generate_series(s.cohort, DATE '2024-06-01', INTERVAL '1 month') AS g(m)
)
SELECT TO_CHAR(g.cohort, 'YYYY-MM') AS cohort_month,
       (EXTRACT(YEAR FROM g.m)::int * 12 + EXTRACT(MONTH FROM g.m)::int)
     - (EXTRACT(YEAR FROM g.cohort)::int * 12 + EXTRACT(MONTH FROM g.cohort)::int) AS month_offset,
       g.cohort_size,
       ROUND(SUM(COALESCE(mo.revenue, 0)) OVER (PARTITION BY g.cohort ORDER BY g.m)
             / g.cohort_size::numeric) AS cum_ltv                   -- running SUM carries empty months
FROM grid g
LEFT JOIN monthly mo ON mo.cohort = g.cohort AND mo.m = g.m
ORDER BY g.cohort, g.m;
