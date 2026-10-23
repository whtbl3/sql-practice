-- Problem dp/03: Best promotion days, never two days in a row (house robber)  [Hard]
-- Pattern: DP with a recursive CTE: walk the rows in order carrying (best so far, best one step back)
-- Variant: best(i) = GREATEST(best(i-1), best(i-2) + value(i)); recursion stands in for a loop
--
-- Task: A supermarket estimates the extra revenue (millions of VND) a flash sale would bring on
--   each day of a week. To avoid tiring customers, flash sales may not run on two consecutive
--   rows (days in day order). Choose the days to maximise the total extra revenue. Return ONE
--   row: max_extra_revenue (0 when there are no days).
-- Learn: grinding/sql-dp.md, B1–B5

-- INPUT
promo_days
| day        | extra_revenue_m |
|------------|-----------------|
| 2024-04-01 | 6               |
| 2024-04-02 | 7               |
| 2024-04-03 | 1               |
| 2024-04-04 | 30              |
| 2024-04-05 | 8               |
| 2024-04-06 | 2               |
| 2024-04-07 | 4               |

-- EXPECTED
| max_extra_revenue |
|-------------------|
| 41                |

-- QUERY
-- write your query here
