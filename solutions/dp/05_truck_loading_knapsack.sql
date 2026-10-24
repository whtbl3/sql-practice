-- Problem dp/05: Pack the most valuable load (0/1 knapsack)  [Hard]
-- Pattern: DP / search with a recursive CTE: one step per item, branch take / skip, prune by capacity
-- Variant: small data: enumerate every feasible subset, then keep the best one
--
-- Task: A trekking group in Sa Pa can carry at most 10 kg of shared gear. Each item can be taken
--   at most once. Choose items with total weight_kg <= 10 that maximise the total value. Return
--   ONE row: best_value, total_weight and items (the chosen names in item_id order, joined with
--   ', '). On a tie prefer the lighter load, then the set whose item_id list comes first.
-- Learn: grinding/sql-dp.md, V4

-- INPUT
items
| item_id | name         | weight_kg | value |
|---------|--------------|-----------|-------|
| 1       | Tent         | 5         | 60    |
| 2       | Gas stove    | 3         | 50    |
| 3       | Water        | 4         | 70    |
| 4       | Flashlight   | 2         | 30    |
| 5       | Sleeping bag | 4         | 40    |
| 6       | Camera       | 1         | 25    |

-- EXPECTED
| best_value | total_weight | items                                |
|------------|--------------|--------------------------------------|
| 175        | 10           | Gas stove, Water, Flashlight, Camera |

-- QUERY
WITH RECURSIVE ordered AS (
  SELECT ROW_NUMBER() OVER (ORDER BY item_id) AS k, item_id, name, weight_kg, value FROM items
),
pack(k, weight, value, ids) AS (                    -- after deciding items 1..k
  SELECT 0::bigint, 0::bigint, 0::bigint, ARRAY[]::int[]
  UNION ALL
  SELECT o.k,
         p.weight + CASE WHEN t.take THEN o.weight_kg ELSE 0 END,
         p.value  + CASE WHEN t.take THEN o.value     ELSE 0 END,
         CASE WHEN t.take THEN p.ids || o.item_id::int ELSE p.ids END
  FROM pack p
  JOIN ordered o ON o.k = p.k + 1
  CROSS JOIN (VALUES (TRUE), (FALSE)) AS t(take)    -- two branches, but the CTE is referenced only once
  WHERE p.weight + CASE WHEN t.take THEN o.weight_kg ELSE 0 END <= 10   -- prune overweight branches early
),
best AS (
  SELECT * FROM pack
  WHERE k = (SELECT COUNT(*) FROM items)            -- every item decided
  ORDER BY value DESC, weight, ids
  LIMIT 1
)
SELECT b.value AS best_value, b.weight AS total_weight,
       (SELECT STRING_AGG(i.name, ', ' ORDER BY i.item_id) FROM items i WHERE i.item_id = ANY (b.ids)) AS items
FROM best b;
