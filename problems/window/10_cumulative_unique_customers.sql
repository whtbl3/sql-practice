-- Problem window/10: Cumulative unique customers  [Hard]
-- Pattern: Running distinct count = first-appearance flag + running SUM
-- Variant: COUNT DISTINCT is not a window function
--
-- Task: For every date that has orders, return new_customers (customers whose FIRST order is on
--   that date) and cumulative_customers (distinct customers seen up to and including that date).
--   Sort by order_date.
-- Learn: grinding/sql-subquery-window.md, mục W7

-- INPUT
orders
| order_date | customer |
|------------|----------|
| 2024-01-01 | Ann      |
| 2024-01-01 | Bob      |
| 2024-01-01 | Ann      |
| 2024-01-02 | Ann      |
| 2024-01-03 | Cy       |
| 2024-01-03 | Bob      |
| 2024-01-04 | Dee      |
| 2024-01-04 | Cy       |

-- EXPECTED
| order_date | new_customers | cumulative_customers |
|------------|---------------|----------------------|
| 2024-01-01 | 2             | 2                    |
| 2024-01-02 | 0             | 2                    |
| 2024-01-03 | 1             | 3                    |
| 2024-01-04 | 1             | 4                    |

-- QUERY
-- write your query here
