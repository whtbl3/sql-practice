-- Problem subquery/04: Average orders per customer  [Medium]
-- Pattern: Derived table (subquery in FROM): aggregate of an aggregate
-- Variant: two-level aggregation
--
-- Task: Return one row: customers (number of customers), avg_orders (average number of orders per
--   customer, 2 decimals, customers without orders count as 0) and max_orders. Orders whose
--   customer_id is not in customers are ignored.
-- Learn: grinding/sql-subquery-window.md, mục S4

-- INPUT
customers
| customer_id | name |
|-------------|------|
| 1           | Ann  |
| 2           | Bob  |
| 3           | Cy   |
| 4           | Dee  |
| 5           | Eli  |

orders
| order_id | customer_id |
|----------|-------------|
| 1        | 1           |
| 2        | 1           |
| 3        | 1           |
| 4        | 2           |
| 5        | 3           |
| 6        | 3           |

-- EXPECTED
| customers | avg_orders | max_orders |
|-----------|------------|------------|
| 5         | 1.20       | 3          |

-- QUERY
-- write your query here
SELECT
  COUNT(customer_id) AS customers
FROM (
  SELECT customer_id
  FROM customers c
  WHERE c.customer_id IN (
    SELECT o.customer_id
    FROM orders o
    WHERE c.customer_id = o.customer_id
  )
)