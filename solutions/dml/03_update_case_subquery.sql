-- Problem dml/03: Assign customer tiers  [Hard]
-- Pattern: UPDATE + CASE + correlated subquery + COALESCE
-- Variant: UPDATE computed from another table's aggregate
--
-- Task: Update the tier of EVERY customer: total order amount >= 1000 is 'Gold', >= 500 is
--   'Silver', otherwise (including customers with no orders) 'Bronze'. Check the customers table
--   afterwards.

-- INPUT
customers
| customer_id | name  | tier |
|-------------|-------|------|
| 1           | Alice | New  |
| 2           | Bob   | New  |
| 3           | Carol | New  |
| 4           | Dan   | New  |

orders
| order_id | customer_id | amount |
|----------|-------------|--------|
| 1        | 1           | 600    |
| 2        | 1           | 500    |
| 3        | 2           | 300    |
| 4        | 2           | 250    |
| 5        | 3           | 100    |

-- EXPECTED
customers
| customer_id | name  | tier   |
|-------------|-------|--------|
| 1           | Alice | Gold   |
| 2           | Bob   | Silver |
| 3           | Carol | Bronze |
| 4           | Dan   | Bronze |

-- QUERY
UPDATE customers c
SET tier = CASE
  WHEN COALESCE((SELECT SUM(o.amount) FROM orders o WHERE o.customer_id = c.customer_id), 0) >= 1000 THEN 'Gold'
  WHEN COALESCE((SELECT SUM(o.amount) FROM orders o WHERE o.customer_id = c.customer_id), 0) >= 500  THEN 'Silver'
  ELSE 'Bronze'
END;
