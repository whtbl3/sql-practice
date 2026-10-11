-- Problem islands/01: Longest monthly order streak  [Hard]
-- Pattern: Gaps & Islands (value - ROW_NUMBER)
-- Variant: core: unit = month, crossing the year boundary
--
-- Task: For each customer find the longest run of consecutive calendar months in which the
--   customer placed at least one order (a run may cross a year boundary; a customer who ordered
--   in only one month has a streak of 1). Return customer_id, longest_streak; sort by
--   longest_streak descending, then customer_id ascending.

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
| 7        | 3           | 2024-01-05 |
| 8        | 3           | 2024-01-25 |
| 9        | 3           | 2024-02-10 |

-- EXPECTED
| customer_id | longest_streak |
|-------------|----------------|
| 1           | 4              |
| 3           | 2              |
| 2           | 1              |

-- QUERY
WITH monthly AS (
  SELECT DISTINCT customer_id,
         EXTRACT(YEAR FROM order_date)::int * 12 + EXTRACT(MONTH FROM order_date)::int AS month_idx
  FROM orders
),
grouped AS (
  SELECT customer_id, month_idx,
         month_idx - ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month_idx) AS grp
  FROM monthly
)
SELECT customer_id, MAX(streak) AS longest_streak
FROM (SELECT customer_id, grp, COUNT(*) AS streak FROM grouped GROUP BY customer_id, grp) s
GROUP BY customer_id
ORDER BY longest_streak DESC, customer_id;
