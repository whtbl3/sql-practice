-- Problem subquery/06: Third highest salary per department, no window  [Hard]
-- Pattern: Correlated COUNT(DISTINCT) subquery (classic Nth-highest)
-- Variant: the keywords OVER, LIMIT and OFFSET are forbidden
--
-- Task: For each department return the third highest DISTINCT salary as third_highest. Departments
--   with fewer than 3 distinct salaries are left out. NULL salaries are ignored. Window functions,
--   LIMIT and OFFSET are rejected. Sort by department.
-- @forbid: \bOVER\s*\(|\bLIMIT\b|\bOFFSET\b
-- Learn: grinding/sql-subquery.md, B2

-- INPUT
employees
| name | department | salary |
|------|------------|--------|
| a    | IT         | 100    |
| b    | IT         | 200    |
| c    | IT         | 200    |
| d    | IT         | 300    |
| e    | IT         | 400    |
| f    | HR         | 50     |
| g    | HR         | 60     |
| h    | Ops        | 10     |
| i    | Ops        | 20     |
| j    | Ops        | 30     |

-- EXPECTED
| department | third_highest |
|------------|---------------|
| IT         | 200           |
| Ops        | 10            |

-- QUERY
-- write your query here
SELECT DISTINCT
  e1.department, e1.salary AS third_highest
FROM employees e1
WHERE (
  SELECT
    COUNT(DISTINCT e2.salary)
  FROM employees e2
  WHERE e2.department = e1.department
    AND e2.salary > e1.salary
) = 2
ORDER BY third_highest DESC