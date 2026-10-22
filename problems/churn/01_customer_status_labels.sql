-- Problem churn/01: Customer status at the as-of date  [Easy]
-- Pattern: Churn: LEFT JOIN with filters in ON + MAX(date) + CASE on days inactive
-- Variant: several labels from the last activity, customers without orders included
--
-- Task: A cosmetics shop reviews its customers on 2024-12-31 (the as-of date). Only orders with
--   status = 'delivered' and order_date <= 2024-12-31 count. For EVERY customer return
--   last_order_date (NULL if none), days_inactive = as-of date - last_order_date (NULL if none)
--   and status = the FIRST rule that matches:
--     'Never bought'        no counted order
--     'Active'  days_inactive <= 30
--     'At risk'      days_inactive <= 90
--     'Lapsed'          everything else
--   Return customer_id, full_name, last_order_date, days_inactive, status. Sort by customer_id.
-- Learn: grinding/sql-analytics-patterns.md, mục 8.2

-- INPUT
customers
| customer_id | full_name |
|-------------|-----------|
| 1           | Anna      |
| 2           | Ben       |
| 3           | Carl      |
| 4           | Dave      |
| 5           | Holly     |
| 6           | Kevin     |

orders
| order_id | customer_id | order_date | status    |
|----------|-------------|------------|-----------|
| 1        | 1           | 2024-12-15 | delivered |
| 2        | 2           | 2024-10-02 | delivered |
| 3        | 3           | 2024-10-01 | delivered |
| 4        | 3           | 2024-12-20 | cancelled |
| 5        | 4           | 2025-01-05 | delivered |
| 6        | 6           | 2024-05-01 | delivered |
| 7        | 6           | 2024-12-01 | delivered |

-- EXPECTED
| customer_id | full_name | last_order_date | days_inactive | status       |
|-------------|-----------|-----------------|---------------|--------------|
| 1           | Anna      | 2024-12-15      | 16            | Active       |
| 2           | Ben       | 2024-10-02      | 90            | At risk      |
| 3           | Carl      | 2024-10-01      | 91            | Lapsed       |
| 4           | Dave      | NULL            | NULL          | Never bought |
| 5           | Holly     | NULL            | NULL          | Never bought |
| 6           | Kevin     | 2024-12-01      | 30            | Active       |

-- QUERY
-- write your query here
