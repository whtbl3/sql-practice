-- Problem window/04: Previous and next order per customer  [Medium]
-- Pattern: LAG / LEAD with PARTITION BY
-- Variant: offset functions
--
-- Task: For every order return customer, order_date, prev_order_date and next_order_date (the same
--   customer's previous / next order) and days_since_prev (NULL for a first order). Sort by
--   customer, order_date.
-- Learn: grinding/sql-window.md, B4

-- INPUT
orders
| order_id | customer | order_date |
|----------|----------|------------|
| 1        | Ann      | 2024-01-01 |
| 2        | Ann      | 2024-01-15 |
| 3        | Ann      | 2024-02-01 |
| 4        | Bob      | 2024-01-10 |
| 5        | Cy       | 2024-03-01 |
| 6        | Cy       | 2024-03-31 |

-- EXPECTED
| customer | order_date | prev_order_date | days_since_prev | next_order_date |
|----------|------------|-----------------|-----------------|-----------------|
| Ann      | 2024-01-01 | NULL            | NULL            | 2024-01-15      |
| Ann      | 2024-01-15 | 2024-01-01      | 14              | 2024-02-01      |
| Ann      | 2024-02-01 | 2024-01-15      | 17              | NULL            |
| Bob      | 2024-01-10 | NULL            | NULL            | NULL            |
| Cy       | 2024-03-01 | NULL            | NULL            | 2024-03-31      |
| Cy       | 2024-03-31 | 2024-03-01      | 30              | NULL            |

-- QUERY
-- write your query here
