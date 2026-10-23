-- Problem rfm/02: Diamond / Gold / Standard membership tiers  [Medium]
-- Pattern: RFM: time window + pre-aggregated refunds + CASE with AND conditions
-- Variant: business tiers instead of 1-5 scores; every member listed
--
-- Task: A coffee chain sets each member's 2025 tier from their 2024 activity. Count only orders
--   with status = 'delivered' and order_date in 2024. orders_2024 = number of those orders;
--   net_spend = their total amount_vnd minus all refunds (refund_vnd) made on those orders
--   (an order may have several refunds; a refunded order still counts in orders_2024).
--   Tier = the FIRST rule that matches:
--     'Diamond'  net_spend >= 10000000 AND orders_2024 >= 5
--     'Gold'       net_spend >= 3000000
--     'Standard'     everything else (including members with no orders)
--   Return customer_id, full_name, orders_2024, net_spend (0 if none), tier for EVERY member.
--   Sort by net_spend DESC, customer_id.
-- Learn: grinding/sql-rfm.md, B1–B2

-- INPUT
customers
| customer_id | full_name     |
|-------------|---------------|
| 1           | Andrew Walker |
| 2           | Bella Turner  |
| 3           | Chris Lewis   |
| 4           | Daniel Price  |
| 5           | Hannah Vaughn |

orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-02-10 | 2000000    | delivered |
| 2        | 1           | 2024-04-05 | 2500000    | delivered |
| 3        | 1           | 2024-06-18 | 1500000    | delivered |
| 4        | 1           | 2024-09-09 | 3000000    | delivered |
| 5        | 1           | 2024-11-30 | 1500000    | delivered |
| 6        | 2           | 2024-01-15 | 2000000    | delivered |
| 7        | 2           | 2024-03-03 | 2000000    | delivered |
| 8        | 2           | 2024-05-20 | 2000000    | delivered |
| 9        | 2           | 2024-07-07 | 2000000    | delivered |
| 10       | 2           | 2024-10-10 | 2000000    | delivered |
| 11       | 2           | 2024-12-24 | 2000000    | delivered |
| 12       | 2           | 2024-12-25 | 5000000    | cancelled |
| 13       | 3           | 2024-08-08 | 7000000    | delivered |
| 14       | 3           | 2024-12-31 | 5000000    | delivered |
| 15       | 4           | 2023-12-31 | 5000000    | delivered |
| 16       | 4           | 2025-01-02 | 4000000    | delivered |

refunds
| refund_id | order_id | refund_vnd |
|-----------|----------|------------|
| 1         | 3        | 400000     |
| 2         | 3        | 200000     |
| 3         | 15       | 1000000    |

-- EXPECTED
| customer_id | full_name     | orders_2024 | net_spend | tier     |
|-------------|---------------|-------------|-----------|----------|
| 2           | Bella Turner  | 6           | 12000000  | Diamond  |
| 3           | Chris Lewis   | 2           | 12000000  | Gold     |
| 1           | Andrew Walker | 5           | 9900000   | Gold     |
| 4           | Daniel Price  | 0           | 0         | Standard |
| 5           | Hannah Vaughn | 0           | 0         | Standard |

-- QUERY
-- write your query here
