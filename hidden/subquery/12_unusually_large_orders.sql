-- HIDDEN TESTS for problem subquery/12. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer:text | order_date:date | amount:int |
|--------------|---------------|-----------------|------------|

-- EXPECTED
| order_id | customer | amount | prev_avg |
|----------|----------|--------|----------|

-- CASE one order per customer
-- INPUT
orders
| order_id:int | customer:text | order_date:date | amount:int |
|--------------|---------------|-----------------|------------|
| 1            | A             | 2024-01-01      | 5          |
| 2            | B             | 2024-01-01      | 500        |

-- EXPECTED
| order_id | customer | amount | prev_avg |
|----------|----------|--------|----------|

-- CASE same-day orders use order_id
-- INPUT
orders
| order_id:int | customer:text | order_date:date | amount:int |
|--------------|---------------|-----------------|------------|
| 2            | Z             | 2024-01-01      | 30         |
| 1            | Z             | 2024-01-01      | 10         |

-- EXPECTED
| order_id | customer | amount | prev_avg |
|----------|----------|--------|----------|
| 2        | Z        | 30     | 10.0     |
