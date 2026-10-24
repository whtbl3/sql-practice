-- Problem cohort/05: RFM segment labels  [Hard]
-- Pattern: RFM: NTILE scores + CASE labels (specific branch first)
-- Variant: labeling segments on top of the scores from cohort/02
--
-- Task: Score customers exactly as in cohort/02 (Completed orders only, as-of date = the day
--   after the latest completed order, NTILE(3), higher = better, ties by customer_id ascending).
--   Then label each customer with the FIRST rule that matches:
--     'Champions' r_score = 3 AND f_score = 3
--     'Loyal'     r_score >= 2 AND f_score >= 2
--     'New'       r_score = 3 AND f_score = 1
--     'At Risk'   r_score = 1 AND f_score >= 2
--     'Lost'      everything else
--   Return customer_id, r_score, f_score, m_score, segment. Sort by customer_id.
-- Learn: grinding/sql-rfm.md, B4

-- INPUT
orders
| order_id | customer_id | order_date | total_amount | status    |
|----------|-------------|------------|--------------|-----------|
| 1        | 1           | 2024-05-01 | 150          | Completed |
| 2        | 1           | 2024-06-10 | 200          | Completed |
| 3        | 1           | 2024-06-25 | 100          | Completed |
| 4        | 2           | 2024-06-28 | 80           | Completed |
| 5        | 3           | 2024-03-01 | 500          | Completed |
| 6        | 3           | 2024-03-20 | 400          | Completed |
| 7        | 3           | 2024-04-02 | 300          | Completed |
| 8        | 4           | 2024-02-10 | 60           | Completed |
| 9        | 5           | 2024-05-20 | 250          | Completed |
| 10       | 5           | 2024-06-15 | 300          | Completed |
| 11       | 6           | 2024-04-15 | 90           | Completed |
| 12       | 6           | 2024-06-29 | 999          | Cancelled |

-- EXPECTED
| customer_id | r_score | f_score | m_score | segment   |
|-------------|---------|---------|---------|-----------|
| 1           | 3       | 3       | 2       | Champions |
| 2           | 3       | 1       | 1       | New       |
| 3           | 1       | 3       | 3       | At Risk   |
| 4           | 1       | 1       | 1       | Lost      |
| 5           | 2       | 2       | 3       | Loyal     |
| 6           | 2       | 2       | 2       | Loyal     |

-- QUERY
-- write your query here
WITH as_of AS (
  SELECT
    MAX(order_date) + 1 AS as_of_date
  FROM orders
  WHERE status = 'Completed'
),
rfm AS (
  SELECT
    o.customer_id,
    a.as_of_date - MAX(o.order_date) AS recency,
    COUNT(*) AS frequency,
    SUM(o.total_amount) AS monetary
  FROM orders o CROSS JOIN as_of a
  WHERE o.status = 'Completed'
  GROUP BY o.customer_id, a.as_of_date
),
scored AS (
  SELECT
    customer_id,
    NTILE(3) OVER (ORDER BY recency DESC, customer_id ASC) AS r_score,
    NTILE(3) OVER (ORDER BY frequency, customer_id ASC) AS f_score,
    NTILE(3) OVER (ORDER BY monetary, customer_id ASC) AS m_score
  FROM rfm
),
labeled AS (
  SELECT
    customer_id,
    r_score,
    f_score,
    m_score,
    CASE
      WHEN r_score = 3 AND f_score = 3 THEN 'Champions'
      WHEN r_score >= 2 AND f_score >= 2 THEN 'Loyal'
      WHEN r_score = 3 AND f_score = 1 THEN 'New'
      WHEN r_score = 1 AND f_score >= 2 THEN 'At Risk'
      ELSE 'Lost'
    END AS segment
  FROM scored
)
SELECT
  customer_id,
  r_score,
  f_score,
  m_score,
  segment
FROM labeled
ORDER BY customer_id