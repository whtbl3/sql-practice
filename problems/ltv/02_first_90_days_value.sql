-- Problem ltv/02: Value of the first 90 days, mature customers only  [Medium]
-- Pattern: LTV: MIN(date) OVER per customer + window [first, first + 89] + "complete window" filter
-- Variant: a fixed-horizon LTV that compares acquisition months fairly
--
-- Task: As-of date = 2024-12-31. Only 'delivered' orders count. A customer's first_date is their
--   first counted order date; their 90-day window runs from first_date to first_date + 89 days
--   (both included). A customer is mature when the whole window has passed: first_date + 89 <=
--   2024-12-31. Customers that are not mature are left out completely. For every acquisition
--   month (month of first_date, 'YYYY-MM') with at least one mature customer return
--   acquisition_month, customers (mature ones) and avg_value_90d = average over those customers
--   of their total amount_vnd inside the window, rounded to whole VND. Sort by acquisition_month.
-- Learn: grinding/sql-analytics-patterns.md, mục 11.3

-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-01-10 | 300000     | delivered |
| 2        | 1           | 2024-03-15 | 200000     | delivered |
| 3        | 1           | 2024-04-09 | 500000     | delivered |
| 4        | 1           | 2024-06-01 | 100000     | delivered |
| 5        | 2           | 2024-01-20 | 900000     | cancelled |
| 6        | 2           | 2024-01-25 | 400000     | delivered |
| 7        | 3           | 2024-10-02 | 200000     | delivered |
| 8        | 3           | 2024-12-30 | 300000     | delivered |
| 9        | 4           | 2024-10-03 | 100000     | delivered |
| 10       | 5           | 2024-10-04 | 700000     | delivered |
| 11       | 6           | 2024-11-15 | 250000     | delivered |

-- EXPECTED
| acquisition_month | customers | avg_value_90d |
|-------------------|-----------|---------------|
| 2024-01           | 2         | 450000        |
| 2024-10           | 2         | 300000        |

-- QUERY
-- write your query here
