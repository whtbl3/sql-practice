-- HIDDEN TESTS for problem subquery/11. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer:text | order_date:date |
|--------------|---------------|-----------------|

-- EXPECTED
| customer |
|----------|

-- CASE month boundaries
-- INPUT
orders
| order_id:int | customer:text | order_date:date |
|--------------|---------------|-----------------|
| 1            | X             | 2024-01-01      |
| 2            | X             | 2024-02-01      |
| 3            | X             | 2024-03-31      |
| 4            | Y             | 2024-01-31      |
| 5            | Y             | 2024-02-29      |
| 6            | Y             | 2024-04-01      |

-- EXPECTED
| customer |
|----------|
| Y        |

-- CASE two January orders are not January and February
-- INPUT
orders
| order_id:int | customer:text | order_date:date |
|--------------|---------------|-----------------|
| 1            | Z             | 2024-01-02      |
| 2            | Z             | 2024-01-30      |

-- EXPECTED
| customer |
|----------|
