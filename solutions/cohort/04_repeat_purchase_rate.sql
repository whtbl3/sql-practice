-- Problem cohort/04: Repeat purchase rate within 30 days  [Hard]
-- Pattern: Cohort metric with ROW_NUMBER (1st and 2nd order per customer)
-- Variant: metric = second order within 30 days of the first, not month-by-month retention
--
-- Task: A customer's cohort is the month of their first order. For each cohort_month ('YYYY-MM')
--   return customers (cohort size), repeaters (customers whose SECOND order was placed at most 30
--   days after their FIRST order) and repeat_rate_pct = repeaters / customers * 100 rounded to 1
--   decimal. Break ties between orders on the same date by order_id. Sort by cohort_month.
-- Learn: grinding/sql-cohort-retention.md, B3, B5

-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-01-05      |
| 2            | 1               | 2024-01-25      |
| 3            | 2               | 2024-01-10      |
| 4            | 2               | 2024-03-01      |
| 5            | 3               | 2024-01-20      |
| 6            | 4               | 2024-02-01      |
| 7            | 4               | 2024-03-02      |
| 8            | 4               | 2024-06-01      |
| 9            | 5               | 2024-02-10      |

-- EXPECTED
| cohort_month | customers | repeaters | repeat_rate_pct |
|--------------|-----------|-----------|-----------------|
| 2024-01      | 3         | 1         | 33.3            |
| 2024-02      | 2         | 1         | 50.0            |

-- QUERY
WITH r AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn
  FROM orders
),
f AS (
  SELECT customer_id,
         MAX(CASE WHEN rn = 1 THEN order_date END) AS first_date,
         MAX(CASE WHEN rn = 2 THEN order_date END) AS second_date
  FROM r
  WHERE rn <= 2
  GROUP BY customer_id
)
SELECT TO_CHAR(DATE_TRUNC('month', first_date), 'YYYY-MM') AS cohort_month,
       COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE second_date - first_date <= 30) AS repeaters,
       ROUND(100.0 * COUNT(*) FILTER (WHERE second_date - first_date <= 30) / COUNT(*), 1) AS repeat_rate_pct
FROM f
GROUP BY 1
ORDER BY 1;
