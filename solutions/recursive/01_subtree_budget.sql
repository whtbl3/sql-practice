-- Problem recursive/01: Total budget per org unit  [Hard]
-- Pattern: Recursive CTE (descendants of every node)
-- Variant: subtree total
--
-- Task: Each unit has its own budget and a parent unit (NULL for the root). For every unit return
--   name and total_budget = its own budget plus the budgets of all units below it. Sort by name.
-- Learn: grinding/sql-recursive.md, mục 1.5

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
WITH RECURSIVE tree AS (
    SELECT unit_id AS root_id, unit_id FROM units
    UNION ALL
    SELECT t.root_id, u.unit_id
    FROM tree t
    JOIN units u ON u.parent_id = t.unit_id
)
SELECT r.name, SUM(u.budget) AS total_budget
FROM tree t
JOIN units r ON r.unit_id = t.root_id
JOIN units u ON u.unit_id = t.unit_id
GROUP BY r.unit_id, r.name
ORDER BY r.name;
