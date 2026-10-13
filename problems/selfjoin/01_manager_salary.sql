-- Problem selfjoin/01: Employees earning more than their manager  [Medium]
-- Pattern: Self join
-- Variant: core
--
-- Task: Find employees who earn more than their direct manager. Return employee, emp_salary,
--   manager, mgr_salary; sort by employee.

-- INPUT
employees
| emp_id | name  | salary | manager_id |
|--------|-------|--------|------------|
| 1      | Alice | 9000   | NULL       |
| 2      | Bob   | 6000   | 1          |
| 3      | Carol | 9500   | 1          |
| 4      | Dan   | 5000   | 2          |
| 5      | Eve   | 6500   | 2          |

-- EXPECTED
| employee | emp_salary | manager | mgr_salary |
|----------|------------|---------|------------|
| Carol    | 9500       | Alice   | 9000       |
| Eve      | 6500       | Bob     | 6000       |

-- QUERY
-- write your query here
SELECT
  e.name
FROM employees e
WHERE e.salary > (
  SELECT m.salary
  FROM employees m
  WHERE e.emp_id = m.manager_id
) 
