-- Problem subquery/11: Ordered in January and February but not March  [Medium]
-- Pattern: Several EXISTS / NOT EXISTS conditions on the same table
-- Variant: conditions across different rows
--
-- Task: Return customers who ordered in January 2024 AND in February 2024 but NOT in March 2024.
--   Each customer once, sorted by customer.
-- Learn: grinding/sql-subquery-window.md, mục S3

-- INPUT
orders
| order_id | customer | order_date |
|----------|----------|------------|
| 1        | Ann      | 2024-01-05 |
| 2        | Ann      | 2024-02-10 |
| 3        | Bob      | 2024-01-07 |
| 4        | Bob      | 2024-02-01 |
| 5        | Bob      | 2024-03-03 |
| 6        | Cy       | 2024-02-20 |
| 7        | Dee      | 2024-01-01 |
| 8        | Dee      | 2024-01-31 |
| 9        | Dee      | 2024-02-29 |
| 10       | Eli      | 2024-01-15 |
| 11       | Eli      | 2023-02-10 |

-- EXPECTED
| customer |
|----------|
| Ann      |
| Dee      |

-- QUERY
-- write your query here
SELECT DISTINCT
  customer
FROM orders o1
WHERE NOT EXISTS (
  SELECT 1
  FROM orders o2
  WHERE o1.customer = o2.customer 
    AND to_char(o2.order_date, 'YYYY-MM') = '2024-03'
) AND EXISTS (
  SELECT 1
  FROM orders o2
  WHERE o1.customer = o2.customer
    AND to_char(o2.order_date, 'YYYY-MM') = '2024-01'
) AND EXISTS (
  SELECT 1
  FROM orders o2
  WHERE o1.customer = o2.customer
    AND to_char(o2.order_date, 'YYYY-MM') = '2024-02'
)