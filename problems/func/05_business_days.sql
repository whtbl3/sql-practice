-- Problem func/05: Business days between two dates  [Medium]
-- Pattern: Scalar function that reads a table (STABLE), generate_series over dates
-- Variant: weekends + holiday table, reversed range
--
-- Task: Create business_days(p_from DATE, p_to DATE) RETURNS INT: the number of days from p_from to
--   p_to (both included) that are Monday-Friday and not in the holidays table. If p_from is after
--   p_to return 0.
-- Learn: grinding/sql-functions-procedures.md, mục 3.4

-- INPUT
holidays
| holiday_date:date | name:text |
|-------------------|-----------|
| 2024-01-01        | New Year  |
| 2024-02-12        | Tet       |

requests
| request_id:int | opened:date | closed:date |
|----------------|-------------|-------------|
| 1              | 2024-01-01  | 2024-01-05  |
| 2              | 2024-01-05  | 2024-01-08  |
| 3              | 2024-01-06  | 2024-01-07  |
| 4              | 2024-02-09  | 2024-02-14  |
| 5              | 2024-03-10  | 2024-03-01  |

-- EXPECTED
| request_id | days |
|------------|------|
| 1          | 4    |
| 2          | 2    |
| 3          | 0    |
| 4          | 3    |
| 5          | 0    |

-- CALL
SELECT request_id, business_days(opened, closed) AS days FROM requests ORDER BY request_id;

-- QUERY
-- write your query here
