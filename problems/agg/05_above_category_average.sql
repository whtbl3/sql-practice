-- Problem agg/05: Products above their category average  [Medium]
-- Pattern: Aggregate as a window (AVG OVER PARTITION), then filter
-- Variant: aggregate vs row comparison
--
-- Task: Return products priced strictly above the average price of their category, with that
--   average rounded to 1 decimal as category_avg. NULL prices are ignored. Sort by category, name.

-- INPUT
products
| name    | category | price |
|---------|----------|-------|
| Pen     | office   | 5     |
| Pencil  | office   | 3     |
| Stapler | office   | 12    |
| Mug     | kitchen  | 8     |
| Cup     | kitchen  | 8     |
| Bowl    | kitchen  | 14    |

-- EXPECTED
| name    | category | price | category_avg |
|---------|----------|-------|--------------|
| Bowl    | kitchen  | 14    | 10.0         |
| Stapler | office   | 12    | 6.7          |

-- QUERY
-- write your query here
