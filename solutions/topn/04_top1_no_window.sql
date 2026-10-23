-- Problem topn/04: Top earner per department without window functions  [Medium]
-- Pattern: Top-1 per group without window functions (NOT EXISTS / correlated subquery)
-- Variant: the keyword OVER is forbidden, so the checker rejects window functions
--
-- Task: Return the highest-paid employee(s) in each department WITHOUT window functions (the OVER
--   keyword is rejected). If several employees tie for the top salary, return all of them. Ignore
--   employees whose salary is NULL. Return department, name, salary; sort by department, then
--   name.
-- Learn: grinding/sql-top-n.md, không được dùng window
-- @forbid: \bOVER\s*\(

-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 500        |
| 2          | B         | IT              | 500        |
| 3          | C         | IT              | 400        |
| 4          | D         | HR              | 300        |
| 5          | E         | HR              | NULL       |
| 6          | F         | Sales           | 700        |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| HR         | D    | 300    |
| IT         | A    | 500    |
| IT         | B    | 500    |
| Sales      | F    | 700    |

-- QUERY
SELECT e.department, e.name, e.salary
FROM employees e
WHERE e.salary IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM employees x
    WHERE x.department = e.department AND x.salary > e.salary
  )
ORDER BY e.department, e.name;
