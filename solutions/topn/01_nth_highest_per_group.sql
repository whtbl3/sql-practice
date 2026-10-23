-- Problem topn/01: Second highest salary per department  [Medium]
-- Pattern: Top-N per group + ties (DENSE_RANK)
-- Variant: core: ties share a rank, nth distinct value
--
-- Task: For each department, return the employees whose salary is the SECOND highest distinct
--   salary in that department (two people sharing the top salary both hold rank 1). Ignore
--   employees whose salary is NULL. Skip departments with no second salary level. Return
--   department, name, salary; sort by department, then name.
-- Learn: grinding/sql-top-n.md, B1–B3

-- INPUT
employees
| emp_id | name  | department | salary |
|--------|-------|------------|--------|
| 1      | Alice | IT         | 5000   |
| 2      | Bob   | IT         | 5000   |
| 3      | Carl  | IT         | 4000   |
| 4      | Dan   | IT         | 3000   |
| 5      | Eve   | HR         | 3500   |
| 6      | Fay   | HR         | 3000   |
| 7      | Gus   | Sales      | 4500   |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| HR         | Fay  | 3000   |
| IT         | Carl | 4000   |

-- QUERY
SELECT department, name, salary
FROM (
  SELECT department, name, salary,
         DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rk
  FROM employees
  WHERE salary IS NOT NULL
) t
WHERE rk = 2
ORDER BY department, name;
