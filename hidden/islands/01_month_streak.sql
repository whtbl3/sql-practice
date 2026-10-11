-- HIDDEN TESTS for problem islands/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|

-- EXPECTED
| customer_id | longest_streak |
|-------------|----------------|

-- CASE across new year, same month in different years, full 12 months
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2023-12-31      |
| 2            | 1               | 2024-01-01      |
| 3            | 2               | 2023-01-15      |
| 4            | 2               | 2024-01-15      |
| 101          | 3               | 2024-01-15      |
| 102          | 3               | 2024-02-15      |
| 103          | 3               | 2024-03-15      |
| 104          | 3               | 2024-04-15      |
| 105          | 3               | 2024-05-15      |
| 106          | 3               | 2024-06-15      |
| 107          | 3               | 2024-07-15      |
| 108          | 3               | 2024-08-15      |
| 109          | 3               | 2024-09-15      |
| 110          | 3               | 2024-10-15      |
| 111          | 3               | 2024-11-15      |
| 112          | 3               | 2024-12-15      |

-- EXPECTED
| customer_id | longest_streak |
|-------------|----------------|
| 3           | 12             |
| 1           | 2              |
| 2           | 1              |

-- CASE multiple streaks, several orders on one day, ties
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-01-10      |
| 2            | 1               | 2024-02-10      |
| 3            | 1               | 2024-04-10      |
| 4            | 1               | 2024-05-10      |
| 5            | 1               | 2024-06-10      |
| 6            | 1               | 2024-08-10      |
| 7            | 2               | 2024-07-07      |
| 8            | 3               | 2024-03-03      |
| 9            | 4               | 2024-05-01      |
| 10           | 4               | 2024-05-01      |
| 11           | 4               | 2024-05-01      |
| 12           | 4               | 2024-06-02      |

-- EXPECTED
| customer_id | longest_streak |
|-------------|----------------|
| 1           | 3              |
| 4           | 2              |
| 2           | 1              |
| 3           | 1              |
