-- Problem antijoin/03: Lapsed customers  [Medium]
-- Pattern: EXISTS and NOT EXISTS on the same table
-- Variant: anti join with a date cut-off
--
-- Task: A customer is lapsed if they ordered before 2024-06-01 and have no order on or after
--   2024-06-01. Customers with no orders at all are not lapsed. Return name, sorted by name.

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
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-03-01 |
| 2        | 1           | 2024-07-01 |
| 3        | 2           | 2024-02-10 |
| 4        | 2           | 2024-05-20 |
| 5        | 3           | 2024-08-01 |
| 6        | 5           | 2024-01-05 |

-- EXPECTED
| name |
|------|
| Bob  |
| Eli  |

-- QUERY
-- write your query here
SELECT
  c.name
FROM customers c 
WHERE 
  EXISTS (SELECT 1 FROM orders o WHERE c.customer_id = o.customer_id AND order_date <= '2024-06-01')
  AND
  NOT EXISTS (SELECT 1 FROM orders o WHERE c.customer_id = o.customer_id AND order_date >= '2024-06-01')
ORDER BY c.name