-- HIDDEN TESTS for problem ltv/02. No QUERY section: the problem's QUERY is used.

-- CASE nobody is mature yet
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-12-01 | 100000     | delivered |

-- EXPECTED
| acquisition_month:text | customers:int | avg_value_90d:numeric |
|------------------------|---------------|-----------------------|

-- CASE day 89 is inside the window, day 90 is outside; leap February
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-02-01 | 100000     | delivered |
| 2        | 1           | 2024-04-30 | 10000      | delivered |
| 3        | 1           | 2024-05-01 | 999000     | delivered |
| 4        | 2           | 2024-02-29 | 50000      | delivered |
| 5        | 2           | 2024-02-29 | 50001      | delivered |

-- EXPECTED
| acquisition_month | customers | avg_value_90d |
|-------------------|-----------|---------------|
| 2024-02           | 2         | 105001        |

-- CASE the first order is cancelled: the customer starts in the next month
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-03-31 | 500000     | cancelled |
| 2        | 1           | 2024-04-01 | 200000     | delivered |
| 3        | 2           | 2024-04-15 | 300000     | returned  |

-- EXPECTED
| acquisition_month | customers | avg_value_90d |
|-------------------|-----------|---------------|
| 2024-04           | 1         | 200000        |
