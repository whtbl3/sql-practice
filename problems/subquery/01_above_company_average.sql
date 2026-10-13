-- Problem subquery/01: Employees above the company average  [Easy]
-- Pattern: Scalar subquery in WHERE
-- Variant: non-correlated subquery
--
-- Task: Return employees whose salary is above the average salary of all employees (NULL salaries
--   are not part of the average). Sort by salary DESC, name.
-- Learn: grinding/sql-subquery-window.md, mục S1

-- INPUT
employees
| name | salary |
|------|--------|
| Ann  | 5000   |
| Bob  | 7000   |
| Cy   | 6000   |
| Dee  | 4000   |
| Eli  | 8000   |

-- EXPECTED
| name | salary |
|------|--------|
| Eli  | 8000   |
| Bob  | 7000   |

-- QUERY
-- write your query here
SELECT e.name, e.salary
FROM employees e
WHERE e.salary > (
  SELECT
    AVG(m.salary)
  FROM employees m
)
ORDER BY e.salary DESC, e.name 