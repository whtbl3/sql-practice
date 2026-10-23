-- Problem gaps/02: Longest silence, including the one still open  [Medium]
-- Pattern: Gaps: LEAD(date, 1, as-of date) + ROW_NUMBER top-1 per customer
-- Variant: the gap after the last purchase (up to the as-of date) is a candidate too
--
-- Task: As-of date = 2024-12-31; only orders on or before it count. Using distinct purchase days,
--   each customer's silences are: every gap between two consecutive purchase days, plus the open
--   gap from the last purchase day to the as-of date. For every customer with at least one
--   counted order return their longest silence: customer_id, gap_start (purchase day where it
--   starts), gap_end (next purchase day, or the as-of date for the open gap), gap_days and
--   gap_type ('closed' or 'open'). On a tie keep the earliest gap. Sort by customer_id.
-- Learn: grinding/sql-purchase-gaps.md, B2

-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-10 |
| 2        | 1           | 2024-05-10 |
| 3        | 1           | 2024-06-01 |
| 4        | 1           | 2024-12-01 |
| 5        | 2           | 2024-03-01 |
| 6        | 2           | 2024-03-15 |
| 7        | 3           | 2024-12-31 |
| 8        | 4           | 2024-11-01 |
| 9        | 4           | 2024-12-01 |
| 10       | 5           | 2025-01-05 |

-- EXPECTED
| customer_id | gap_start  | gap_end    | gap_days | gap_type |
|-------------|------------|------------|----------|----------|
| 1           | 2024-06-01 | 2024-12-01 | 183      | closed   |
| 2           | 2024-03-15 | 2024-12-31 | 291      | open     |
| 3           | 2024-12-31 | 2024-12-31 | 0        | open     |
| 4           | 2024-11-01 | 2024-12-01 | 30       | closed   |

-- QUERY
WITH days AS (
  SELECT DISTINCT customer_id, order_date
  FROM orders
  WHERE order_date <= DATE '2024-12-31'
),
silences AS (
  SELECT customer_id,
         order_date AS gap_start,
         -- the 3rd argument of LEAD replaces the missing "next row": the last day gets the as-of date
         LEAD(order_date, 1, DATE '2024-12-31') OVER (PARTITION BY customer_id ORDER BY order_date) AS gap_end,
         LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) IS NULL AS is_open
  FROM days
),
ranked AS (
  SELECT *, gap_end - gap_start AS gap_days,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY gap_end - gap_start DESC, gap_start) AS rn
  FROM silences
)
SELECT customer_id, gap_start, gap_end, gap_days,
       CASE WHEN is_open THEN 'open' ELSE 'closed' END AS gap_type
FROM ranked
WHERE rn = 1
ORDER BY customer_id;
