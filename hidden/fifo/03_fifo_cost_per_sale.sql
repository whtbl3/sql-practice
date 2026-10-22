-- HIDDEN TESTS for problem fifo/03. No QUERY section: the problem's QUERY is used.

-- CASE no sales
-- INPUT
purchases
| lot_id | product | purchase_date | qty | unit_cost_vnd |
|--------|---------|---------------|-----|---------------|
| 1      | A       | 2024-01-01    | 5   | 1000          |

sales
| sale_id:int | product:text | sale_date:date | qty:int | unit_price_vnd:int |
|-------------|--------------|----------------|---------|--------------------|

-- EXPECTED
| sale_id:int | product:text | qty:int | cogs_vnd:numeric | revenue_vnd:int | gross_profit_vnd:numeric |
|-------------|--------------|---------|------------------|-----------------|--------------------------|

-- CASE one sale eats three lots; rows given out of order
-- INPUT
purchases
| lot_id | product | purchase_date | qty | unit_cost_vnd |
|--------|---------|---------------|-----|---------------|
| 3      | A       | 2024-01-03    | 10  | 300           |
| 1      | A       | 2024-01-01    | 2   | 100           |
| 2      | A       | 2024-01-02    | 3   | 200           |

sales
| sale_id | product | sale_date  | qty | unit_price_vnd |
|---------|---------|------------|-----|----------------|
| 2       | A       | 2024-01-05 | 1   | 1000           |
| 1       | A       | 2024-01-04 | 7   | 500            |

-- EXPECTED
| sale_id | product | qty | cogs_vnd | revenue_vnd | gross_profit_vnd |
|---------|---------|-----|----------|-------------|------------------|
| 1       | A       | 7   | 1400     | 3500        | 2100             |
| 2       | A       | 1   | 300      | 1000        | 700              |
