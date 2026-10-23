-- Problem subquery/04: Average orders per customer  [Medium]
-- Pattern: Derived table (subquery in FROM): aggregate of an aggregate
-- Variant: two-level aggregation
--
-- Task: Return one row: customers (number of customers), avg_orders (average number of orders per
--   customer, 2 decimals, customers without orders count as 0) and max_orders. Orders whose
--   customer_id is not in customers are ignored.
-- Learn: grinding/sql-subquery.md, B4

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
  COUNT(*) AS customers,
  ROUND(AVG(n_orders), 2) AS avg_orders,
  MAX(n_orders) AS max_orders
FROM (
  SELECT
    c.customer_id,
    COUNT(o.order_id) AS n_orders
  FROM customers c
    LEFT JOIN orders o ON o.customer_id = c.customer_id
  GROUP BY c.customer_id
)