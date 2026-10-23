-- Problem gaps/01: Days between purchases, per customer  [Easy]
-- Pattern: Gaps: DISTINCT purchase days -> LAG -> MIN / AVG / MAX per customer
-- Variant: one summary row per customer (window/04 lists every order); same-day orders are one purchase
--
-- Task: A bakery chain looks at how often customers come back. A purchase day is a date on which
--   the customer has at least one order (several orders on the same day = one purchase day).
--   A gap is the number of days between two consecutive purchase days of the same customer.
--   For every customer with at least 2 purchase days return customer_id, purchase_days,
--   min_gap, avg_gap (rounded to 1 decimal) and max_gap. Sort by customer_id.
-- Learn: grinding/sql-purchase-gaps.md, B1–B3

-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-11 |
| 3        | 1           | 2024-01-31 |
| 4        | 1           | 2024-03-01 |
| 5        | 2           | 2024-02-01 |
| 6        | 2           | 2024-02-01 |
| 7        | 2           | 2024-02-05 |
| 8        | 3           | 2024-03-10 |
| 9        | 4           | 2024-01-05 |
| 10       | 4           | 2024-04-05 |
| 11       | 4           | 2024-04-06 |
| 12       | 5           | 2023-12-30 |
| 13       | 5           | 2024-01-02 |
| 14       | 6           | 2024-01-01 |
| 15       | 6           | 2024-01-02 |
| 16       | 6           | 2024-01-04 |

-- EXPECTED
| customer_id | purchase_days | min_gap | avg_gap | max_gap |
|-------------|---------------|---------|---------|---------|
| 1           | 4             | 10      | 20.0    | 30      |
| 2           | 2             | 4       | 4.0     | 4       |
| 4           | 3             | 1       | 46.0    | 91      |
| 5           | 2             | 3       | 3.0     | 3       |
| 6           | 3             | 1       | 1.5     | 2       |

-- QUERY
-- write your query here
