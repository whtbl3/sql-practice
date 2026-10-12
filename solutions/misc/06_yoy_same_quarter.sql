-- Problem misc/06: Year-over-year growth by quarter  [Medium]
-- Pattern: Self join on shifted key (not LAG)
-- Variant: YoY
--
-- Task: For each row return yr, qtr, revenue and yoy_pct = growth in % versus the SAME quarter of
--   the previous year, rounded to 1 decimal. NULL when that quarter does not exist (a missing year
--   is not skipped). Sort by yr, qtr.

-- INPUT
quarterly_sales
| yr   | qtr | revenue |
|------|-----|---------|
| 2023 | 1   | 100     |
| 2023 | 2   | 200     |
| 2023 | 3   | 300     |
| 2024 | 1   | 150     |
| 2024 | 2   | 180     |

-- EXPECTED
| yr   | qtr | revenue | yoy_pct |
|------|-----|---------|---------|
| 2023 | 1   | 100     | NULL    |
| 2023 | 2   | 200     | NULL    |
| 2023 | 3   | 300     | NULL    |
| 2024 | 1   | 150     | 50.0    |
| 2024 | 2   | 180     | -10.0   |

-- QUERY
SELECT c.yr, c.qtr, c.revenue,
       ROUND((c.revenue - p.revenue) * 100.0 / NULLIF(p.revenue, 0), 1) AS yoy_pct
FROM quarterly_sales c
LEFT JOIN quarterly_sales p ON p.qtr = c.qtr AND p.yr = c.yr - 1
ORDER BY c.yr, c.qtr;
