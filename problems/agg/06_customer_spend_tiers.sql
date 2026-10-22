-- Problem agg/06: Customer spending tiers  [Medium]
-- Pattern: CASE on an aggregate result
-- Variant: classification
--
-- Task: Per customer return orders (count), total_spent and tier: 'Gold' if total_spent >= 1000,
--   'Silver' if >= 500, otherwise 'Bronze'. Sort by total_spent DESC, customer.

-- INPUT
orders
| order_id | customer | amount |
|----------|----------|--------|
| 1        | Ann      | 600    |
| 2        | Ann      | 500    |
| 3        | Bob      | 300    |
| 4        | Bob      | 250    |
| 5        | Cy       | 100    |
| 6        | Dee      | 1000   |
| 7        | Eli      | 500    |

-- EXPECTED
| customer | orders | total_spent | tier   |
|----------|--------|-------------|--------|
| Ann      | 2      | 1100        | Gold   |
| Dee      | 1      | 1000        | Gold   |
| Bob      | 2      | 550         | Silver |
| Eli      | 1      | 500         | Silver |
| Cy       | 1      | 100         | Bronze |

-- QUERY
-- write your query here
SELECT
  customer,
  COUNT(*) AS orders,
  SUM(amount) AS total_spent,
  CASE 
    WHEN SUM(amount) >= 1000 THEN 'Gold'
    WHEN SUM(amount) >= 500 THEN 'Silver'
    ELSE 'Bronze'
  END AS tier
FROM orders
GROUP BY customer
ORDER BY total_spent DESC, customer