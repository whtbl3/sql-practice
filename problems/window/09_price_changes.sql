-- Problem window/09: Detect price changes  [Medium]
-- Pattern: LAG + IS DISTINCT FROM to keep only rows that changed
-- Variant: change detection
--
-- Task: price_history has one snapshot per product per day, and most days repeat the price. Return
--   only the snapshots where the price differs from that product's previous snapshot (NULL counts as
--   a value), plus each product's first snapshot. Return product, changed_on, old_price (previous
--   snapshot's price), new_price. Sort by product, changed_on.
-- Learn: grinding/sql-subquery-window.md, mục W4

-- INPUT
price_history
| product | changed_on | price |
|---------|------------|-------|
| A       | 2024-01-01 | 10    |
| A       | 2024-01-02 | 10    |
| A       | 2024-01-03 | 12    |
| A       | 2024-01-04 | 12    |
| A       | 2024-01-05 | 10    |
| B       | 2024-01-01 | 5     |
| B       | 2024-01-02 | 5     |

-- EXPECTED
| product | changed_on | old_price | new_price |
|---------|------------|-----------|-----------|
| A       | 2024-01-01 | NULL      | 10        |
| A       | 2024-01-03 | 10        | 12        |
| A       | 2024-01-05 | 12        | 10        |
| B       | 2024-01-01 | NULL      | 5         |

-- QUERY
-- write your query here
