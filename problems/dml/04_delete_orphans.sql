-- Problem dml/04: Delete orphan orders  [Medium]
-- Pattern: DELETE + NOT EXISTS (anti-join)
-- Variant: DELETE driven by a missing match
--
-- Task: Delete the rows in orders whose customer_id does not exist in customers. Check the orders
--   table afterwards.

-- INPUT
customers
| customer_id | name  |
|-------------|-------|
| 1           | Alice |
| 2           | Bob   |
| 3           | Carol |

orders
| order_id | customer_id | amount |
|----------|-------------|--------|
| 1        | 1           | 100    |
| 2        | 2           | 200    |
| 3        | 9           | 300    |
| 4        | 1           | 150    |
| 5        | 7           | 50     |

-- EXPECTED
orders
| order_id | customer_id | amount |
|----------|-------------|--------|
| 1        | 1           | 100    |
| 2        | 2           | 200    |
| 4        | 1           | 150    |

-- QUERY
-- write your query here
