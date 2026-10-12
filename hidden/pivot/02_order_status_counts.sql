-- HIDDEN TESTS for problem pivot/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer:text | status:text |
|--------------|---------------|-------------|

-- EXPECTED
| customer | pending | shipped | cancelled |
|----------|---------|---------|-----------|

-- CASE unknown status still gives a row of zeros
-- INPUT
orders
| order_id:int | customer:text | status:text |
|--------------|---------------|-------------|
| 1            | Ann           | returned    |
| 2            | Bob           | pending     |

-- EXPECTED
| customer | pending | shipped | cancelled |
|----------|---------|---------|-----------|
| Ann      | 0       | 0       | 0         |
| Bob      | 1       | 0       | 0         |

-- CASE many orders for one customer
-- INPUT
orders
| order_id:int | customer:text | status:text |
|--------------|---------------|-------------|
| 1            | Zed           | pending     |
| 2            | Zed           | pending     |
| 3            | Zed           | pending     |
| 4            | Zed           | pending     |
| 5            | Zed           | shipped     |

-- EXPECTED
| customer | pending | shipped | cancelled |
|----------|---------|---------|-----------|
| Zed      | 4       | 1       | 0         |
