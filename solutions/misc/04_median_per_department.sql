-- Problem misc/04: Median salary per department  [Hard]
-- Pattern: Ordered-set aggregate (PERCENTILE_CONT) or window row counting
-- Variant: median
--
-- Task: Compute the median salary of each department (average of the two middle values when the
--   count is even), rounded to 1 decimal. NULL salaries are ignored. Sort by department.
-- Learn: grinding/sql-median.md, B1–B4

-- INPUT
employees
| name | department | salary |
|------|------------|--------|
| A    | IT         | 4000   |
| B    | IT         | 5000   |
| C    | IT         | 6000   |
| D    | IT         | 7000   |
| E    | HR         | 3000   |
| F    | HR         | 3200   |
| G    | HR         | 4000   |
| H    | Ops        | 2500   |

-- EXPECTED
| department | median_salary |
|------------|---------------|
| HR         | 3200.0        |
| IT         | 5500.0        |
| Ops        | 2500.0        |

-- QUERY
SELECT department,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)::numeric, 1) AS median_salary
FROM employees
GROUP BY department
ORDER BY department;
