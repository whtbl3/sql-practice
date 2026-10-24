-- Problem dp/02: Most profitable run of consecutive days (maximum subarray)  [Medium]
-- Pattern: DP / Kadane in SQL: prefix sums, best = max over j of (prefix_j - smallest earlier prefix)
-- Variant: also report which days form the best run
--
-- Task: daily_profit holds a food stall's daily profit in millions of VND (can be negative), one
--   row per day. Find the run of consecutive rows (at least one day) with the highest total
--   profit. Return ONE row: start_day, end_day, total_profit. On a tie keep the earliest
--   start_day, then the earliest end_day. No rows when the table is empty.
-- Learn: grinding/sql-dp.md, V2

-- INPUT
daily_profit
| day        | profit_m |
|------------|----------|
| 2024-03-01 | -2       |
| 2024-03-02 | 1        |
| 2024-03-03 | -3       |
| 2024-03-04 | 4        |
| 2024-03-05 | -1       |
| 2024-03-06 | 2        |
| 2024-03-07 | 1        |
| 2024-03-08 | -5       |
| 2024-03-09 | 4        |

-- EXPECTED
| start_day  | end_day    | total_profit |
|------------|------------|--------------|
| 2024-03-04 | 2024-03-07 | 6            |

-- QUERY
WITH numbered AS (
  SELECT day, ROW_NUMBER() OVER (ORDER BY day) AS i,
         SUM(profit_m) OVER (ORDER BY day) AS prefix         -- profit of days 1..i
  FROM daily_profit
),
prefixes AS (                                       -- add prefix 0 "before day 1" so a run can start on day 1
  SELECT i, prefix, day FROM numbered
  UNION ALL
  SELECT 0, 0, NULL
)
SELECT s.day AS start_day, e.day AS end_day, e.prefix - p.prefix AS total_profit
FROM prefixes p                                     -- run = days p.i+1 .. e.i
JOIN numbered e ON e.i > p.i
JOIN numbered s ON s.i = p.i + 1
ORDER BY total_profit DESC, start_day, end_day
LIMIT 1;
