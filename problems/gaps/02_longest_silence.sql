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
-- Learn: grinding/sql-analytics-patterns.md, mục 9.3

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
-- write your query here
