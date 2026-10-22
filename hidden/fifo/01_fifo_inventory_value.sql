-- HIDDEN TESTS for problem fifo/01. No QUERY section: the problem's QUERY is used.

-- CASE no sales at all
-- INPUT
purchases
| lot_id | product | purchase_date | qty | unit_cost_vnd |
|--------|---------|---------------|-----|---------------|
| 1      | A       | 2024-01-01    | 5   | 1000          |
| 2      | A       | 2024-01-02    | 5   | 2000          |

sales
| sale_id:int | product:text | sale_date:date | qty:int |
|-------------|--------------|----------------|---------|

-- EXPECTED
| product | remaining_qty | inventory_value_vnd |
|---------|---------------|---------------------|
| A       | 10            | 15000               |

-- CASE a sale that ends exactly at a lot boundary, and two lots on the same day
-- INPUT
purchases
| lot_id | product | purchase_date | qty | unit_cost_vnd |
|--------|---------|---------------|-----|---------------|
| 2      | A       | 2024-01-01    | 10  | 300           |
| 1      | A       | 2024-01-01    | 10  | 100           |
| 3      | A       | 2024-01-05    | 10  | 500           |

sales
| sale_id | product | sale_date  | qty |
|---------|---------|------------|-----|
| 1       | A       | 2024-01-06 | 4   |
| 2       | A       | 2024-01-07 | 6   |

-- EXPECTED
| product | remaining_qty | inventory_value_vnd |
|---------|---------------|---------------------|
| A       | 20            | 8000                |
