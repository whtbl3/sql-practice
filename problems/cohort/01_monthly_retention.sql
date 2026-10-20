-- Problem cohort/01: Monthly cohort retention  [Hard]
-- Pattern: Cohort: MIN() OVER + month offset + FIRST_VALUE
-- Variant: core: cohort = month of the first order
--
-- Task: A customer's cohort is the month of their first order. For every (cohort_month,
--   month_offset) with activity return active_customers (distinct customers with an order) and
--   retention_pct = active_customers / cohort size * 100, rounded to 1 decimal. month_offset is
--   the number of months since the cohort month (0, 1, 2, ...). cohort_month is formatted 'YYYY-
--   MM'. Sort by cohort_month, month_offset.
-- Learn: grinding/sql-analytics-patterns.md, mục 3.2

-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2023-11-10 |
| 2        | 1           | 2023-12-05 |
| 3        | 1           | 2024-01-15 |
| 4        | 1           | 2024-02-20 |
| 5        | 2           | 2024-01-08 |
| 6        | 2           | 2024-03-12 |
| 7        | 3           | 2024-01-20 |

-- EXPECTED
| cohort_month | month_offset | active_customers | retention_pct |
|--------------|--------------|------------------|---------------|
| 2023-11      | 0            | 1                | 100.0         |
| 2023-11      | 1            | 1                | 100.0         |
| 2023-11      | 2            | 1                | 100.0         |
| 2023-11      | 3            | 1                | 100.0         |
| 2024-01      | 0            | 2                | 100.0         |
| 2024-01      | 2            | 1                | 50.0          |

-- QUERY
-- write your query here
