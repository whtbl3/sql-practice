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
-- write your query here
