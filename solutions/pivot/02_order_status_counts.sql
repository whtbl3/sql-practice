-- Problem pivot/02: Order status counts per customer  [Medium]
-- Pattern: Pivot with conditional aggregation (COUNT FILTER)
-- Variant: count variant
--
-- Task: For each customer, count orders per status as three columns pending, shipped, cancelled (0
--   when none). Orders with any other status count in none of them. Sort by customer.

-- INPUT
orders
| order_id | customer | status    |
|----------|----------|-----------|
| 1        | Ann      | shipped   |
| 2        | Ann      | shipped   |
| 3        | Ann      | cancelled |
| 4        | Bob      | pending   |
| 5        | Bob      | shipped   |
| 6        | Cy       | cancelled |

-- EXPECTED
| customer | pending | shipped | cancelled |
|----------|---------|---------|-----------|
| Ann      | 0       | 2       | 1         |
| Bob      | 1       | 1       | 0         |
| Cy       | 0       | 0       | 1         |

-- QUERY
SELECT customer,
       COUNT(*) FILTER (WHERE status = 'pending')   AS pending,
       COUNT(*) FILTER (WHERE status = 'shipped')   AS shipped,
       COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled
FROM orders
GROUP BY customer
ORDER BY customer;
