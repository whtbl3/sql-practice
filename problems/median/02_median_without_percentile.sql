-- Problem median/02: Median salary per department without PERCENTILE functions  [Medium]
-- Pattern: Median: ROW_NUMBER + COUNT OVER -> keep the 1 or 2 middle rows -> AVG
-- Variant: misc/04 with PERCENTILE_CONT / PERCENTILE_DISC forbidden (portable SQL, interview style)
-- @forbid: \bPERCENTILE_(CONT|DISC)\b|\bMEDIAN\s*\(
--
-- Task: For every department return median_salary = the median of its known salaries (NULL
--   salaries are ignored; average of the two middle values when the count is even), rounded to
--   1 decimal. Departments where every salary is NULL are left out. Equal salaries are separate
--   values (4 salaries 20, 25, 25, 40 have median 25). PERCENTILE_CONT / PERCENTILE_DISC are
--   not allowed. Sort by department.
-- Learn: grinding/sql-analytics-patterns.md, mục 10.3

-- INPUT
employees
| emp_id | department  | salary_vnd |
|--------|-------------|------------|
| 1      | Engineering | 25000000   |
| 2      | Engineering | 40000000   |
| 3      | Engineering | 20000000   |
| 4      | Engineering | 25000000   |
| 5      | Sales       | 15000000   |
| 6      | Sales       | NULL       |
| 7      | Sales       | 18000000   |
| 8      | Sales       | 12000000   |
| 9      | Accounting  | 10000000   |
| 10     | Accounting  | 14000000   |
| 11     | HR          | NULL       |

-- EXPECTED
| department  | median_salary |
|-------------|---------------|
| Accounting  | 12000000.0    |
| Engineering | 25000000.0    |
| Sales       | 15000000.0    |

-- QUERY
-- write your query here
