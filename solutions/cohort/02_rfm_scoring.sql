-- Problem cohort/02: RFM scoring  [Hard]
-- Pattern: RFM: GROUP BY + fixed as-of date + NTILE
-- Variant: scoring customers instead of measuring retention
--
-- Task: Only count orders with status = 'Completed'. The as-of date is the day after the latest
--   completed order. For each customer return recency_days (days from their latest order to the
--   as-of date), frequency (number of orders), monetary (total amount), and r_score, f_score,
--   m_score using NTILE(3) (higher score = better; break ties by customer_id ascending). Sort by
--   customer_id.
-- Learn: grinding/sql-analytics-patterns.md, mục 2.3

-- INPUT
orders
| order_id | customer_id | order_date | total_amount | status    |
|----------|-------------|------------|--------------|-----------|
| 1        | 1           | 2024-01-05 | 100          | Completed |
| 2        | 1           | 2024-02-10 | 200          | Completed |
| 3        | 2           | 2024-02-20 | 50           | Completed |
| 4        | 3           | 2024-01-15 | 500          | Completed |
| 5        | 3           | 2024-01-20 | 300          | Cancelled |

-- EXPECTED
| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score |
|-------------|--------------|-----------|----------|---------|---------|---------|
| 1           | 11           | 2         | 300      | 2       | 3       | 2       |
| 2           | 1            | 1         | 50       | 3       | 1       | 1       |
| 3           | 37           | 1         | 500      | 1       | 2       | 3       |

-- QUERY
WITH as_of AS (
  SELECT MAX(order_date) + 1 AS as_of_date FROM orders WHERE status = 'Completed'
),
rfm AS (
  SELECT o.customer_id,
         a.as_of_date - MAX(o.order_date) AS recency_days,
         COUNT(*) AS frequency,
         SUM(o.total_amount) AS monetary
  FROM orders o CROSS JOIN as_of a
  WHERE o.status = 'Completed'
  GROUP BY o.customer_id, a.as_of_date
)
SELECT customer_id, recency_days, frequency, monetary,
       NTILE(3) OVER (ORDER BY recency_days DESC, customer_id) AS r_score,
       NTILE(3) OVER (ORDER BY frequency, customer_id)         AS f_score,
       NTILE(3) OVER (ORDER BY monetary, customer_id)          AS m_score
FROM rfm
ORDER BY customer_id;
