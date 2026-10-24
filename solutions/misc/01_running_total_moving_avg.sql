-- Problem misc/01: Running total and 3-day moving average  [Medium]
-- Pattern: Window frame (ROWS BETWEEN)
-- Variant: function drill
--
-- Task: For each day (one row per day) compute running_total (revenue from the first day up to
--   that day) and moving_avg_3 (average revenue of that day and up to the 2 previous days,
--   rounded to 2 decimals). Sort by sale_date.
-- Learn: grinding/sql-kpi-report.md, V1

-- INPUT
daily_sales
| sale_date  | amount |
|------------|--------|
| 2024-01-01 | 100    |
| 2024-01-02 | 200    |
| 2024-01-03 | 150    |
| 2024-01-04 | 50     |
| 2024-01-05 | 300    |

-- EXPECTED
| sale_date  | amount | running_total | moving_avg_3 |
|------------|--------|---------------|--------------|
| 2024-01-01 | 100    | 100           | 100.00       |
| 2024-01-02 | 200    | 300           | 150.00       |
| 2024-01-03 | 150    | 450           | 150.00       |
| 2024-01-04 | 50     | 500           | 133.33       |
| 2024-01-05 | 300    | 800           | 166.67       |

-- QUERY
SELECT sale_date, amount,
       SUM(amount) OVER (ORDER BY sale_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
       ROUND(AVG(amount) OVER (ORDER BY sale_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3
FROM daily_sales
ORDER BY sale_date;
