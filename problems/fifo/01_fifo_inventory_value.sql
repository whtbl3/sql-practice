-- Problem fifo/01: Inventory value under FIFO  [Medium]
-- Pattern: FIFO: running SUM(qty) of lots (oldest first) - total sold -> what is left in each lot
-- Variant: only the totals matter: what remains and what it cost
--
-- Task: A rice and spice wholesaler values stock with FIFO: sales always take the oldest lots
--   first (by purchase_date, then lot_id). Total sales never exceed total purchases. For every
--   product in purchases return product, remaining_qty and inventory_value_vnd = sum over the
--   remaining units of their lot's unit_cost_vnd (0 and 0 when everything is sold).
--   Sort by product.
-- Learn: grinding/sql-analytics-patterns.md, mục 13.2

-- INPUT
purchases
| lot_id | product    | purchase_date | qty | unit_cost_vnd |
|--------|------------|---------------|-----|---------------|
| 1      | ST25 rice  | 2024-01-05    | 100 | 20000         |
| 3      | ST25 rice  | 2024-02-10    | 80  | 21000         |
| 2      | ST25 rice  | 2024-01-20    | 50  | 22000         |
| 4      | Fish sauce | 2024-01-03    | 50  | 35000         |
| 5      | Fish sauce | 2024-01-04    | 50  | 36000         |
| 6      | Coffee     | 2024-01-08    | 30  | 120000        |

sales
| sale_id | product    | sale_date  | qty |
|---------|------------|------------|-----|
| 1       | ST25 rice  | 2024-01-25 | 60  |
| 2       | ST25 rice  | 2024-02-15 | 70  |
| 3       | Fish sauce | 2024-01-30 | 100 |

-- EXPECTED
| product    | remaining_qty | inventory_value_vnd |
|------------|---------------|---------------------|
| Coffee     | 30            | 3600000             |
| Fish sauce | 0             | 0                   |
| ST25 rice  | 100           | 2120000             |

-- QUERY
-- write your query here
