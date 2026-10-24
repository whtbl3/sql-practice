-- Problem recursive/01: Total budget per org unit  [Hard]
-- Pattern: Recursive CTE (descendants of every node)
-- Variant: subtree total
--
-- Task: Each unit has its own budget and a parent unit (NULL for the root). For every unit return
--   name and total_budget = its own budget plus the budgets of all units below it. Sort by name.
-- Learn: grinding/sql-recursive-cte.md, V2

-- INPUT
units
| unit_id | name       | parent_id | budget |
|---------|------------|-----------|--------|
| 1       | HQ         | NULL      | 100    |
| 2       | Sales      | 1         | 50     |
| 3       | Eng        | 1         | 200    |
| 4       | SalesNorth | 2         | 30     |
| 5       | SalesSouth | 2         | 20     |
| 6       | Backend    | 3         | 80     |

-- EXPECTED
| name       | total_budget |
|------------|--------------|
| Backend    | 80           |
| Eng        | 280          |
| HQ         | 480          |
| Sales      | 100          |
| SalesNorth | 30           |
| SalesSouth | 20           |

-- QUERY
-- write your query here
