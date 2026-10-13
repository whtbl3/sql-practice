-- Problem subquery/08: Top 2 orders per customer with LATERAL  [Hard]
-- Pattern: LEFT JOIN LATERAL (subquery that can see the outer row) + LIMIT
-- Variant: per-row subquery returning many rows
--
-- Task: For each customer return their 2 largest orders (ties: smaller order_id first): name,
--   order_id, amount. A customer without orders appears once with NULL order_id and amount. Sort by
--   name, amount DESC, order_id.
-- Learn: grinding/sql-subquery-window.md, mục S7

-- INPUT
customers
| customer_id | name |
|-------------|------|
| 1           | Ann  |
| 2           | Bob  |
| 3           | Cy   |

orders
| order_id | customer_id | amount |
|----------|-------------|--------|
| 1        | 1           | 50     |
| 2        | 1           | 80     |
| 3        | 1           | 80     |
| 4        | 1           | 10     |
| 5        | 2           | 30     |

-- EXPECTED
| name | order_id | amount |
|------|----------|--------|
| Ann  | 2        | 80     |
| Ann  | 3        | 80     |
| Bob  | 5        | 30     |
| Cy   | NULL     | NULL   |

-- QUERY
-- write your query here
