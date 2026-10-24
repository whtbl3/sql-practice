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
-- write your query here
