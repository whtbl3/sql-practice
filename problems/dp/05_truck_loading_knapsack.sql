-- Problem dp/05: Pack the most valuable load (0/1 knapsack)  [Hard]
-- Pattern: DP / search with a recursive CTE: one step per item, branch take / skip, prune by capacity
-- Variant: small data: enumerate every feasible subset, then keep the best one
--
-- Task: A trekking group in Sa Pa can carry at most 10 kg of shared gear. Each item can be taken
--   at most once. Choose items with total weight_kg <= 10 that maximise the total value. Return
--   ONE row: best_value, total_weight and items (the chosen names in item_id order, joined with
--   ', '). On a tie prefer the lighter load, then the set whose item_id list comes first.
-- Learn: grinding/sql-recursive.md, mục 3.6

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
-- write your query here
