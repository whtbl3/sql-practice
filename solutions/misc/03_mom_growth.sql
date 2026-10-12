-- Problem misc/03: Month-over-month growth  [Medium]
-- Pattern: Window function LAG
-- Variant: previous row comparison
--
-- Task: For each month return revenue, prev_revenue (previous row's revenue) and pct_change =
--   (revenue - prev_revenue) * 100 / prev_revenue rounded to 1 decimal. pct_change is NULL for the
--   first month and when prev_revenue is 0. Sort by month.

-- INPUT
monthly_revenue
| month      | revenue |
|------------|---------|
| 2024-01-01 | 100     |
| 2024-02-01 | 150     |
| 2024-03-01 | 120     |
| 2024-04-01 | 120     |

-- EXPECTED
| month      | revenue | prev_revenue | pct_change |
|------------|---------|--------------|------------|
| 2024-01-01 | 100     | NULL         | NULL       |
| 2024-02-01 | 150     | 100          | 50.0       |
| 2024-03-01 | 120     | 150          | -20.0      |
| 2024-04-01 | 120     | 120          | 0.0        |

-- QUERY
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS pct_change
FROM monthly_revenue
ORDER BY month;
