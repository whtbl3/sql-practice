-- Problem recursive/02: Reporting path and depth  [Medium]
-- Pattern: Recursive CTE (carry a path down the tree)
-- Variant: path building
--
-- Task: For every employee return name, depth (0 for someone with no manager) and path, the chain
--   of names from the top manager down to the employee, joined with ' > '. Sort by emp_id.
-- Learn: grinding/sql-recursive-cte.md, B1–B2

-- INPUT
employees
| emp_id | name  | manager_id |
|--------|-------|------------|
| 1      | Alice | NULL       |
| 2      | Bob   | 1          |
| 3      | Carol | 1          |
| 4      | Dan   | 2          |
| 5      | Eve   | 4          |

-- EXPECTED
| name  | depth | path                    |
|-------|-------|-------------------------|
| Alice | 0     | Alice                   |
| Bob   | 1     | Alice > Bob             |
| Carol | 1     | Alice > Carol           |
| Dan   | 2     | Alice > Bob > Dan       |
| Eve   | 3     | Alice > Bob > Dan > Eve |

-- QUERY
WITH RECURSIVE chain AS (
    SELECT emp_id, name, 0 AS depth, name::text AS path
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.name, c.depth + 1, c.path || ' > ' || e.name
    FROM employees e
    JOIN chain c ON e.manager_id = c.emp_id
)
SELECT name, depth, path
FROM chain
ORDER BY emp_id;
