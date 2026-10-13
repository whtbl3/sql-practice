-- Problem window/07: Rolling 7-day revenue with missing days  [Medium]
-- Pattern: RANGE frame with an INTERVAL offset (ROWS vs RANGE)
-- Variant: calendar-based frame
--
-- Task: The table has one row per day WITH sales (days without sales are missing). For each row
--   return rolling_7d = total revenue from sale_date - 6 days to sale_date (a 7-calendar-day
--   window). Sort by sale_date.
-- Learn: grinding/sql-subquery-window.md, mục W3

-- INPUT
daily_sales
| sale_date  | revenue |
|------------|---------|
| 2024-01-01 | 10      |
| 2024-01-02 | 20      |
| 2024-01-04 | 30      |
| 2024-01-08 | 40      |
| 2024-01-09 | 50      |
| 2024-01-20 | 5       |

-- EXPECTED
| sale_date  | revenue | rolling_7d |
|------------|---------|------------|
| 2024-01-01 | 10      | 10         |
| 2024-01-02 | 20      | 30         |
| 2024-01-04 | 30      | 60         |
| 2024-01-08 | 40      | 90         |
| 2024-01-09 | 50      | 120        |
| 2024-01-20 | 5       | 5          |

-- QUERY
-- write your query here
