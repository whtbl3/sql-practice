-- HIDDEN TESTS for problem ltv/03. No QUERY section: the problem's QUERY is used.

-- CASE no delivered orders
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-01-05 | 100000     | cancelled |

-- EXPECTED
| cohort_month:text | customers:int | first_month_revenue:numeric | lifetime_revenue:numeric | share_of_totals_pct:numeric | avg_customer_share_pct:numeric |
|-------------------|---------------|-----------------------------|--------------------------|-----------------------------|--------------------------------|

-- CASE first month is the calendar month, not the first 30 days; across the new year
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2023-12-31 | 100000     | delivered |
| 2        | 1           | 2024-01-01 | 300000     | delivered |
| 3        | 2           | 2023-12-01 | 50000      | delivered |
| 4        | 2           | 2023-12-30 | 50000      | delivered |

-- EXPECTED
| cohort_month | customers | first_month_revenue | lifetime_revenue | share_of_totals_pct | avg_customer_share_pct |
|--------------|-----------|---------------------|------------------|---------------------|------------------------|
| 2023-12      | 2         | 200000              | 500000           | 40.0                | 62.5                   |
