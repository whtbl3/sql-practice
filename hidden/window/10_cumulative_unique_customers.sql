-- HIDDEN TESTS for problem window/10. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_date:date | customer:text |
|-----------------|---------------|

-- EXPECTED
| order_date | new_customers | cumulative_customers |
|------------|---------------|----------------------|

-- CASE the same customer every day
-- INPUT
orders
| order_date:date | customer:text |
|-----------------|---------------|
| 2024-01-01      | A             |
| 2024-01-02      | A             |
| 2024-01-03      | A             |

-- EXPECTED
| order_date | new_customers | cumulative_customers |
|------------|---------------|----------------------|
| 2024-01-01 | 1             | 1                    |
| 2024-01-02 | 0             | 1                    |
| 2024-01-03 | 0             | 1                    |

-- CASE many orders from one new customer on one day
-- INPUT
orders
| order_date:date | customer:text |
|-----------------|---------------|
| 2024-02-01      | A             |
| 2024-02-01      | A             |
| 2024-02-01      | A             |
| 2024-02-02      | B             |

-- EXPECTED
| order_date | new_customers | cumulative_customers |
|------------|---------------|----------------------|
| 2024-02-01 | 1             | 1                    |
| 2024-02-02 | 1             | 2                    |
