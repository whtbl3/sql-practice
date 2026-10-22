-- Problem agg/07: Summary of issues to handle  [Medium]
-- Pattern: UNION ALL of counts from several tables + share of total
-- Variant: UNION ALL summary
--
-- Task: Build a 3-row summary: 'Complaint' (complaints with status 'Pending'), 'Cancelled Order'
--   (orders with status 'Cancelled'), 'Out of Stock Product' (products with status 'Out of Stock'),
--   each with quantity and pct = share of the 3 quantities' total, 1 decimal (NULL if the total is
--   0). Always return all 3 rows. Sort by quantity DESC, type.

-- INPUT
complaints
| complaint_id | status   |
|--------------|----------|
| 1            | Pending  |
| 2            | Pending  |
| 3            | Resolved |

orders
| order_id | status    |
|----------|-----------|
| 1        | Cancelled |
| 2        | Shipped   |
| 3        | Cancelled |
| 4        | Cancelled |
| 5        | Cancelled |

products
| product_id | status       |
|------------|--------------|
| 1          | Out of Stock |
| 2          | In Stock     |
| 3          | Out of Stock |

-- EXPECTED
| type                 | quantity | pct  |
|----------------------|----------|------|
| Cancelled Order      | 4        | 50.0 |
| Complaint            | 2        | 25.0 |
| Out of Stock Product | 2        | 25.0 |

-- QUERY
-- write your query here
WITH t AS (
  SELECT 
    'Complaint' AS type,
    COUNT(*) FILTER (WHERE status = 'Pending') AS quantity
  FROM complaints

  UNION ALL

  SELECT
    'Cancelled Order' AS type,
    COUNT(*) FILTER (WHERE status = 'Cancelled') AS quantity
  FROM orders

  UNION ALL 

  SELECT
    'Out of Stock Product' AS type,
    COUNT(*) FILTER (WHERE status = 'Out of Stock') AS quantity
  FROM products
)
SELECT
  type,
  quantity,
  ROUND(quantity * 100.0 / SUM(quantity) OVER (), 1) AS pct
FROM t
ORDER BY quantity DESC, type