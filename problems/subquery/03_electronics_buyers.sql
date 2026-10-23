-- Problem subquery/03: Customers who bought electronics  [Medium]
-- Pattern: Semi-join with IN / EXISTS (no duplicates from the join)
-- Variant: semi-join
--
-- Task: Return the name of every customer who ordered at least one product in category
--   'Electronics'. Each customer appears once, but two different customers with the same name are
--   two rows. Sort by name, then customer_id.
-- Learn: grinding/sql-subquery.md, B3

-- INPUT
customers
| customer_id | name |
|-------------|------|
| 1           | Ann  |
| 2           | Bob  |
| 3           | Cy   |
| 4           | Ann  |

orders
| order_id | customer_id | product_id |
|----------|-------------|------------|
| 1        | 1           | 10         |
| 2        | 1           | 11         |
| 3        | 1           | 10         |
| 4        | 2           | 12         |
| 5        | 3           | 11         |
| 6        | 4           | 10         |

products
| product_id | category    |
|------------|-------------|
| 10         | Electronics |
| 11         | Electronics |
| 12         | Books       |

-- EXPECTED
| name |
|------|
| Ann  |
| Ann  |
| Cy   |

-- QUERY
-- write your query here
SELECT
  name
FROM customers
WHERE EXISTS (
  SELECT 1
  FROM orders
  JOIN products
  ON orders.product_id = products.product_id
  WHERE category = 'Electronics' AND customers.customer_id = orders.customer_id
)
ORDER BY name, customer_id