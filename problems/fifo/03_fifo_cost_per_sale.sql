-- Problem fifo/03: Cost of goods sold for every sale under FIFO  [Hard]
-- Pattern: FIFO: each sale and each lot as a range of unit positions (running SUM) -> join overlapping ranges
-- Variant: one sale can take units from several lots at different costs
--
-- Task: Same FIFO rule as fifo/01: lots are used oldest first (purchase_date, lot_id) and sales
--   take units in sale order (sale_date, sale_id), per product; there is always enough stock.
--   For every sale return sale_id, product, qty, cogs_vnd (sum of the unit costs of the units it
--   took), revenue_vnd = qty * unit_price_vnd and gross_profit_vnd = revenue - cogs.
--   Sort by sale_id.
-- Learn: grinding/sql-fifo.md, V2

-- INPUT
purchases
| lot_id | product    | purchase_date | qty | unit_cost_vnd |
|--------|------------|---------------|-----|---------------|
| 1      | ST25 rice  | 2024-01-05    | 100 | 20000         |
| 2      | ST25 rice  | 2024-01-20    | 50  | 22000         |
| 3      | ST25 rice  | 2024-02-10    | 80  | 21000         |
| 4      | Fish sauce | 2024-01-03    | 50  | 35000         |
| 5      | Fish sauce | 2024-01-04    | 50  | 36000         |

sales
| sale_id | product    | sale_date  | qty | unit_price_vnd |
|---------|------------|------------|-----|----------------|
| 1       | ST25 rice  | 2024-01-25 | 60  | 30000          |
| 2       | ST25 rice  | 2024-02-15 | 70  | 31000          |
| 3       | ST25 rice  | 2024-02-20 | 40  | 32000          |
| 4       | Fish sauce | 2024-01-10 | 50  | 45000          |
| 5       | Fish sauce | 2024-01-11 | 10  | 45000          |

-- EXPECTED
| sale_id | product    | qty | cogs_vnd | revenue_vnd | gross_profit_vnd |
|---------|------------|-----|----------|-------------|------------------|
| 1       | ST25 rice  | 60  | 1200000  | 1800000     | 600000           |
| 2       | ST25 rice  | 70  | 1460000  | 2170000     | 710000           |
| 3       | ST25 rice  | 40  | 860000   | 1280000     | 420000           |
| 4       | Fish sauce | 50  | 1750000  | 2250000     | 500000           |
| 5       | Fish sauce | 10  | 360000   | 450000      | 90000            |

-- QUERY
-- write your query here
