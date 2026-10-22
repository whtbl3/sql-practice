-- HIDDEN TESTS for problem ltv/04. No QUERY section: the problem's QUERY is used.

-- CASE no counted orders
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-07-05 | 100000     | delivered |

-- EXPECTED
| cohort_month:text | month_offset:int | cohort_size:int | cum_ltv:numeric |
|-------------------|------------------|-----------------|-----------------|

-- CASE a cohort from the previous year spans the new year; all its revenue is in month 0
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2023-11-10 | 300000     | delivered |
| 2        | 2           | 2023-11-11 | 0          | delivered |
| 3        | 3           | 2023-11-12 | 100000     | delivered |

-- EXPECTED
| cohort_month | month_offset | cohort_size | cum_ltv |
|--------------|--------------|-------------|---------|
| 2023-11      | 0            | 3           | 133333  |
| 2023-11      | 1            | 3           | 133333  |
| 2023-11      | 2            | 3           | 133333  |
| 2023-11      | 3            | 3           | 133333  |
| 2023-11      | 4            | 3           | 133333  |
| 2023-11      | 5            | 3           | 133333  |
| 2023-11      | 6            | 3           | 133333  |
| 2023-11      | 7            | 3           | 133333  |
