-- HIDDEN TESTS for problem window/04. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer:text | order_date:date |
|--------------|---------------|-----------------|

-- EXPECTED
| customer | order_date | prev_order_date | days_since_prev | next_order_date |
|----------|------------|-----------------|-----------------|-----------------|

-- CASE customers interleaved in time do not leak into each other
-- INPUT
orders
| order_id:int | customer:text | order_date:date |
|--------------|---------------|-----------------|
| 1            | A             | 2024-01-01      |
| 2            | B             | 2024-01-02      |
| 3            | A             | 2024-01-05      |

-- EXPECTED
| customer | order_date | prev_order_date | days_since_prev | next_order_date |
|----------|------------|-----------------|-----------------|-----------------|
| A        | 2024-01-01 | NULL            | NULL            | 2024-01-05      |
| A        | 2024-01-05 | 2024-01-01      | 4               | NULL            |
| B        | 2024-01-02 | NULL            | NULL            | NULL            |

-- CASE across a leap day
-- INPUT
orders
| order_id:int | customer:text | order_date:date |
|--------------|---------------|-----------------|
| 1            | A             | 2024-03-01      |
| 2            | A             | 2024-02-28      |

-- EXPECTED
| customer | order_date | prev_order_date | days_since_prev | next_order_date |
|----------|------------|-----------------|-----------------|-----------------|
| A        | 2024-02-28 | NULL            | NULL            | 2024-03-01      |
| A        | 2024-03-01 | 2024-02-28      | 2               | NULL            |
