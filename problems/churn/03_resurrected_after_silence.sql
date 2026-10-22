-- Problem churn/03: Customers coming back after 2+ silent months  [Medium]
-- Pattern: Churn: distinct active months -> month number (year*12+month) -> LAG -> gap filter
-- Variant: count silent CALENDAR months between active months, not days between orders
--
-- Task: A food-delivery app calls a month "active" for a customer when they placed at least one
--   order in it. A comeback happens when an active month follows the customer's previous active
--   month with at least 2 inactive calendar months in between. For every comeback return
--   customer_id, last_active_month (the previous active month), returned_month and
--   silent_months (number of inactive months in between). Months are 'YYYY-MM'.
--   Sort by customer_id, returned_month.
-- Learn: grinding/sql-analytics-patterns.md, mục 8.4

-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-05 |
| 2        | 1           | 2024-02-11 |
| 3        | 1           | 2024-05-20 |
| 4        | 1           | 2024-06-02 |
| 5        | 2           | 2024-01-15 |
| 6        | 2           | 2024-03-15 |
| 7        | 3           | 2023-11-20 |
| 8        | 3           | 2024-03-03 |
| 9        | 3           | 2024-09-09 |
| 10       | 4           | 2024-02-01 |
| 11       | 4           | 2024-02-28 |
| 12       | 5           | 2024-01-31 |
| 13       | 5           | 2024-04-01 |
| 14       | 6           | 2024-01-01 |
| 15       | 6           | 2024-03-31 |

-- EXPECTED
| customer_id | last_active_month | returned_month | silent_months |
|-------------|-------------------|----------------|---------------|
| 1           | 2024-02           | 2024-05        | 2             |
| 3           | 2023-11           | 2024-03        | 3             |
| 3           | 2024-03           | 2024-09        | 5             |
| 5           | 2024-01           | 2024-04        | 2             |

-- QUERY
-- write your query here
