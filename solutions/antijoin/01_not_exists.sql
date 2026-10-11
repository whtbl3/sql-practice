-- Problem antijoin/01: Customers without a completed order  [Medium]
-- Pattern: Anti-join (NOT EXISTS instead of NOT IN when NULLs are present)
-- Variant: core: NULL in the subquery column
--
-- Task: Find customers who have never had an order with status 'Completed' (including customers
--   with no orders at all). Note that orders contains a row whose customer_id is NULL. Return
--   name; sort by name.

-- INPUT
customers
| customer_id | name  |
|-------------|-------|
| 1           | Alice |
| 2           | Bob   |
| 3           | Carol |
| 4           | Dan   |

orders
| order_id | customer_id | status    |
|----------|-------------|-----------|
| 1        | 1           | Completed |
| 2        | 1           | Cancelled |
| 3        | 2           | Cancelled |
| 4        | 3           | Completed |
| 5        | NULL        | Completed |

-- EXPECTED
| name |
|------|
| Bob  |
| Dan  |

-- QUERY
SELECT c.name
FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM orders o
  WHERE o.customer_id = c.customer_id AND o.status = 'Completed'
)
ORDER BY c.name;
