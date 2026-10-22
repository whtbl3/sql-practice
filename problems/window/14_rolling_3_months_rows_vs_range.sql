-- Problem window/14: 3-month rolling revenue, ROWS vs RANGE  [Medium]
-- Pattern: ROWS BETWEEN 2 PRECEDING vs RANGE BETWEEN INTERVAL '2 months' PRECEDING on a date
-- Variant: missing months: "the last 3 rows" is not "the last 3 months"
--
-- Task: monthly_revenue has one row per month with revenue (month = first day of the month);
--   months without revenue have no row. For every row return month ('YYYY-MM'), revenue,
--   sum_last_3_rows (this row and the 2 rows before it) and sum_last_3_months (revenue of this
--   month and the 2 calendar months before it). Sort by month.
-- Learn: grinding/sql-common-pitfalls.md, mục F2c

-- INPUT
monthly_revenue
| month      | revenue |
|------------|---------|
| 2024-01-01 | 100     |
| 2024-02-01 | 200     |
| 2024-03-01 | 300     |
| 2024-05-01 | 500     |
| 2024-06-01 | 600     |
| 2024-08-01 | 800     |

-- EXPECTED
| month   | revenue | sum_last_3_rows | sum_last_3_months |
|---------|---------|-----------------|-------------------|
| 2024-01 | 100     | 100             | 100               |
| 2024-02 | 200     | 300             | 300               |
| 2024-03 | 300     | 600             | 600               |
| 2024-05 | 500     | 1000            | 800               |
| 2024-06 | 600     | 1400            | 1100              |
| 2024-08 | 800     | 1900            | 1400              |

-- QUERY
-- write your query here
