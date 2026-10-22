-- HIDDEN TESTS for problem churn/03. No QUERY section: the problem's QUERY is used.

-- CASE no orders
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|

-- EXPECTED
| customer_id:int | last_active_month:text | returned_month:text | silent_months:int |
|-----------------|------------------------|---------------------|-------------------|

-- CASE exactly 1 vs exactly 2 silent months, across a year boundary
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2023-11-30 |
| 2        | 1           | 2024-01-01 |
| 3        | 2           | 2023-11-01 |
| 4        | 2           | 2024-02-29 |

-- EXPECTED
| customer_id | last_active_month | returned_month | silent_months |
|-------------|-------------------|----------------|---------------|
| 2           | 2023-11           | 2024-02        | 2             |

-- CASE many orders in the same months must not create extra comebacks
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 7           | 2024-01-03 |
| 2        | 7           | 2024-01-04 |
| 3        | 7           | 2024-01-05 |
| 4        | 7           | 2024-06-10 |
| 5        | 7           | 2024-06-11 |
| 6        | 7           | 2024-07-01 |

-- EXPECTED
| customer_id | last_active_month | returned_month | silent_months |
|-------------|-------------------|----------------|---------------|
| 7           | 2024-01           | 2024-06        | 4             |
