-- HIDDEN TESTS for problem gaps/02. No QUERY section: the problem's QUERY is used.

-- CASE no orders on or before the as-of date
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2025-02-01      |

-- EXPECTED
| customer_id:int | gap_start:date | gap_end:date | gap_days:int | gap_type:text |
|-----------------|----------------|--------------|--------------|---------------|

-- CASE a future order must not close the open gap
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-03 |
| 3        | 1           | 2025-01-01 |

-- EXPECTED
| customer_id | gap_start  | gap_end    | gap_days | gap_type |
|-------------|------------|------------|----------|----------|
| 1           | 2024-01-03 | 2024-12-31 | 363      | open     |

-- CASE same-day orders, tie between a closed and the open gap
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-12-01 |
| 2        | 1           | 2024-12-01 |
| 3        | 1           | 2024-12-16 |
| 4        | 2           | 2024-12-30 |
| 5        | 2           | 2024-12-30 |

-- EXPECTED
| customer_id | gap_start  | gap_end    | gap_days | gap_type |
|-------------|------------|------------|----------|----------|
| 1           | 2024-12-01 | 2024-12-16 | 15       | closed   |
| 2           | 2024-12-30 | 2024-12-31 | 1        | open     |
