-- HIDDEN TESTS for problem misc/07. No QUERY section: the problem's QUERY is used.

-- CASE no price history at all
-- INPUT
price_history
| product_id:int | valid_from:date | price_vnd:int |
|----------------|-----------------|---------------|

order_lines
| order_id | order_date | product_id | qty |
|----------|------------|------------|-----|
| 1        | 2024-01-01 | 1          | 1   |

-- EXPECTED
| order_id | product_id | order_date | unit_price | line_total |
|----------|------------|------------|------------|------------|
| 1        | 1          | 2024-01-01 | NULL       | NULL       |

-- CASE another product's newer price must not leak in
-- INPUT
price_history
| product_id | valid_from | price_vnd |
|------------|------------|-----------|
| 1          | 2024-01-01 | 10000     |
| 2          | 2024-05-01 | 99000     |
| 1          | 2024-12-31 | 12000     |

order_lines
| order_id | order_date | product_id | qty |
|----------|------------|------------|-----|
| 1        | 2024-06-01 | 1          | 5   |
| 2        | 2024-12-31 | 1          | 1   |
| 3        | 2024-04-30 | 2          | 1   |

-- EXPECTED
| order_id | product_id | order_date | unit_price | line_total |
|----------|------------|------------|------------|------------|
| 1        | 1          | 2024-06-01 | 10000      | 50000      |
| 2        | 1          | 2024-12-31 | 12000      | 12000      |
| 3        | 2          | 2024-04-30 | NULL       | NULL       |
