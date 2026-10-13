-- Problem window/02: Each employee next to the department average  [Easy]
-- Pattern: Aggregate as a window: AVG/COUNT OVER (PARTITION BY)
-- Variant: window vs GROUP BY
--
-- Task: Keep every employee row and add dept_avg (department average salary, 1 decimal),
--   diff_from_avg (salary - dept_avg, 1 decimal) and dept_headcount (employees in the department,
--   including those with a NULL salary). Sort by department, name.
-- Learn: grinding/sql-subquery-window.md, mục W2

-- INPUT
employees
| name | department | salary |
|------|------------|--------|
| Ann  | IT         | 5000   |
| Bob  | IT         | 7000   |
| Cy   | IT         | 6000   |
| Dee  | HR         | 4000   |
| Eli  | HR         | 5000   |
| Fay  | Ops        | 3000   |

-- EXPECTED
| name | department | salary | dept_avg | diff_from_avg | dept_headcount |
|------|------------|--------|----------|---------------|----------------|
| Dee  | HR         | 4000   | 4500.0   | -500.0        | 2              |
| Eli  | HR         | 5000   | 4500.0   | 500.0         | 2              |
| Ann  | IT         | 5000   | 6000.0   | -1000.0       | 3              |
| Bob  | IT         | 7000   | 6000.0   | 1000.0        | 3              |
| Cy   | IT         | 6000   | 6000.0   | 0.0           | 3              |
| Fay  | Ops        | 3000   | 3000.0   | 0.0           | 1              |

-- QUERY
-- write your query here
