-- Problem cohort/06: RFM with fixed thresholds  [Hard]
-- Pattern: RFM: LEFT JOIN from customers + CASE thresholds instead of NTILE
-- Variant: business-defined cut-offs, a given as-of date, customers without orders still listed
--
-- Task: The as-of date is 2024-07-01. Only Completed orders placed BEFORE the as-of date count.
--   For EVERY customer (including those with no counted orders) return recency_days (as-of date
--   minus latest counted order date; NULL if none), frequency and monetary (0 if none), then:
--     r_score: recency_days <= 30 -> 3, <= 90 -> 2, otherwise (or no orders) -> 1
--     f_score: frequency >= 3 -> 3, >= 2 -> 2, otherwise -> 1
--     m_score: monetary >= 1000 -> 3, >= 300 -> 2, otherwise -> 1
--   and rfm_code = the three scores concatenated as text, e.g. '323'.
--   Return customer_id, recency_days, frequency, monetary, r_score, f_score, m_score, rfm_code.
--   Sort by customer_id.
-- Learn: grinding/sql-rfm.md, B1–B3

-- INPUT
customers
| customer_id | name |
|-------------|------|
| 1           | An   |
| 2           | Binh |
| 3           | Chi  |
| 4           | Dung |
| 5           | Em   |
| 6           | Giang|

orders
| order_id | customer_id | order_date | total_amount | status    |
|----------|-------------|------------|--------------|-----------|
| 1        | 1           | 2024-04-01 | 300          | Completed |
| 2        | 1           | 2024-05-15 | 350          | Completed |
| 3        | 1           | 2024-06-20 | 400          | Completed |
| 4        | 2           | 2024-06-01 | 120          | Completed |
| 5        | 2           | 2024-07-03 | 900          | Completed |
| 6        | 3           | 2024-02-10 | 700          | Completed |
| 7        | 3           | 2024-04-20 | 500          | Completed |
| 8        | 4           | 2024-06-28 | 2000         | Cancelled |
| 9        | 6           | 2023-12-01 | 50           | Completed |

-- EXPECTED
| customer_id | recency_days:int | frequency | monetary | r_score | f_score | m_score | rfm_code |
|-------------|------------------|-----------|----------|---------|---------|---------|----------|
| 1           | 11               | 3         | 1050     | 3       | 3       | 3       | 333      |
| 2           | 30               | 1         | 120      | 3       | 1       | 1       | 311      |
| 3           | 72               | 2         | 1200     | 2       | 2       | 3       | 223      |
| 4           | NULL             | 0         | 0        | 1       | 1       | 1       | 111      |
| 5           | NULL             | 0         | 0        | 1       | 1       | 1       | 111      |
| 6           | 213              | 1         | 50       | 1       | 1       | 1       | 111      |

-- QUERY
-- write your query here
WITH rfm AS (
  SELECT
    c.customer_id,
    DATE '2024-07-01' - MAX(o.order_date) AS recency_days,
    COUNT(o.customer_id) AS frequency,
    COALESCE(SUM(o.total_amount), 0) AS monetary
  FROM customers c LEFT JOIN orders o ON c.customer_id = o.customer_id
  AND o.order_date < '2024-07-01'
  AND o.status = 'Completed'
  GROUP BY c.customer_id
),
labled AS (
  SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    CASE 
      WHEN recency_days <= 30 THEN 3
      WHEN recency_days <= 90 THEN 2
      ELSE 1
    END AS r_score,
    CASE
      WHEN frequency >= 3 THEN 3
      WHEN frequency >= 2 THEN 2
      ELSE 1
    END AS f_score,
    CASE
      WHEN monetary >= 1000 THEN 3
      WHEN monetary >= 300 THEN 2
      ELSE 1
    END AS m_score
  FROM rfm
  ORDER BY 1
)
SELECT 
  customer_id,
  recency_days,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  CONCAT(r_score, f_score, m_score) AS rfm_code
FROM labled
ORDER BY customer_id;