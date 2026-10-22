-- HIDDEN TESTS for problem gaps/01. No QUERY section: the problem's QUERY is used.

-- CASE no orders
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|

-- EXPECTED
| customer_id:int | purchase_days:int | min_gap:int | avg_gap:numeric | max_gap:int |
|-----------------|-------------------|-------------|-----------------|-------------|

-- CASE only same-day orders: a single purchase day is left out
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-05-05 |
| 2        | 1           | 2024-05-05 |
| 3        | 1           | 2024-05-05 |
| 4        | 2           | 2024-05-01 |
| 5        | 2           | 2024-05-04 |

-- EXPECTED
| customer_id | purchase_days | min_gap | avg_gap | max_gap |
|-------------|---------------|---------|---------|---------|
| 2           | 2             | 3       | 3.0     | 3       |

-- CASE rows not sorted by date, leap day and an average that needs rounding
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 9           | 2024-03-01 |
| 2        | 9           | 2024-02-28 |
| 3        | 9           | 2024-01-01 |
| 4        | 9           | 2024-03-02 |

-- EXPECTED
| customer_id | purchase_days | min_gap | avg_gap | max_gap |
|-------------|---------------|---------|---------|---------|
| 9           | 4             | 1       | 20.3    | 58      |
