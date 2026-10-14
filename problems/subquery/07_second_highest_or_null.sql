-- Problem subquery/07: Second highest salary, or NULL  [Medium]
-- Pattern: Scalar subquery returns NULL on an empty result
-- Variant: always one row
--
-- Task: Return exactly one row with one column second_highest: the second highest DISTINCT salary.
--   If it does not exist, the row must still be returned with NULL. NULL salaries are ignored.
-- Learn: grinding/sql-subquery-window.md, mục S1

-- INPUT
employees
| name | salary |
|------|--------|
| Ann  | 100    |
| Bob  | 300    |
| Cy   | 200    |
| Dee  | 300    |

-- EXPECTED
| second_highest |
|----------------|
| 200            |

-- QUERY
-- write your query here
SELECT  
  e1.salary AS second_highest
FROM employees e1
WHERE (
  SELECT
    COUNT(DISTINCT e2.salary)
  FROM employees e2
  WHERE e2.salary > e1.salary
) = 1
