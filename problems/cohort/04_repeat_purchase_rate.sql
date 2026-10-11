-- Problem cohort/04: Repeat purchase rate within 30 days  [Hard]
-- Pattern: Cohort metric with ROW_NUMBER (1st and 2nd order per customer)
-- Variant: metric = second order within 30 days of the first, not month-by-month retention
--
-- Task: A customer's cohort is the month of their first order. For each cohort_month ('YYYY-MM')
--   return customers (cohort size), repeaters (customers whose SECOND order was placed at most 30
--   days after their FIRST order) and repeat_rate_pct = repeaters / customers * 100 rounded to 1
--   decimal. Break ties between orders on the same date by order_id. Sort by cohort_month.

-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-01-05      |
| 2            | 1               | 2024-01-25      |
| 3            | 2               | 2024-01-10      |
| 4            | 2               | 2024-03-01      |
| 5            | 3               | 2024-01-20      |
| 6            | 4               | 2024-02-01      |
| 7            | 4               | 2024-03-02      |
| 8            | 4               | 2024-06-01      |
| 9            | 5               | 2024-02-10      |

-- EXPECTED
| cohort_month | customers | repeaters | repeat_rate_pct |
|--------------|-----------|-----------|-----------------|
| 2024-01      | 3         | 1         | 33.3            |
| 2024-02      | 2         | 1         | 50.0            |

-- QUERY
-- write your query here
