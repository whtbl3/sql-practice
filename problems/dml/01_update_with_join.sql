-- Problem dml/01: Raise salary by department location  [Medium]
-- Pattern: UPDATE ... FROM (join while updating)
-- Variant: core: UPDATE with a condition from another table
--
-- Task: Raise the salary by 10% for employees in departments whose location is 'Hanoi'. Employees
--   with a NULL salary stay unchanged. Check the employees table after the statement runs.

-- INPUT
employees
| emp_id | name  | dept_id | salary |
|--------|-------|---------|--------|
| 1      | Alice | 1       | 5000   |
| 2      | Bob   | 1       | 4000   |
| 3      | Carol | 2       | 3500   |
| 4      | David | 3       | 3000   |
| 5      | Eve   | 3       | NULL   |

departments
| dept_id | dept_name | location |
|---------|-----------|----------|
| 1       | IT        | Hanoi    |
| 2       | HR        | Saigon   |
| 3       | Sales     | Hanoi    |

-- EXPECTED
employees
| emp_id | name  | dept_id | salary |
|--------|-------|---------|--------|
| 1      | Alice | 1       | 5500   |
| 2      | Bob   | 1       | 4400   |
| 3      | Carol | 2       | 3500   |
| 4      | David | 3       | 3300   |
| 5      | Eve   | 3       | NULL   |

-- QUERY
-- write your query here
