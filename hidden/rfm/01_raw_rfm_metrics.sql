-- HIDDEN TESTS for problem rfm/01. No QUERY section: the problem's QUERY is used.

-- CASE no orders at all
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | amount_vnd:int | status:text |
|--------------|-----------------|-----------------|----------------|-------------|

-- EXPECTED
| customer_id:int | recency_days:int | frequency:int | monetary:int |
|-----------------|------------------|---------------|--------------|

-- CASE customers with only cancelled or returned orders are left out
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-12-01 | 500000     | cancelled |
| 2        | 2           | 2024-12-02 | 300000     | returned  |
| 3        | 3           | 2024-11-30 | 100000     | delivered |
| 4        | 3           | 2024-12-30 | 999000     | cancelled |

-- EXPECTED
| customer_id | recency_days | frequency | monetary |
|-------------|--------------|-----------|----------|
| 3           | 31           | 1         | 100000   |

-- CASE two orders on the same day, one on the as-of date
-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 7           | 2024-12-31 | 200000     | delivered |
| 2        | 7           | 2024-12-31 | 300000     | delivered |
| 3        | 2           | 2024-01-01 | 50000      | delivered |
| 4        | 2           | 2024-01-01 | 50000      | delivered |

-- EXPECTED
| customer_id | recency_days | frequency | monetary |
|-------------|--------------|-----------|----------|
| 2           | 365          | 2         | 100000   |
| 7           | 0            | 2         | 500000   |
