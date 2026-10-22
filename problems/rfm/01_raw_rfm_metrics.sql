-- Problem rfm/01: Raw R, F, M metrics for a grocery chain  [Easy]
-- Pattern: RFM: one GROUP BY customer_id + a given as-of date
-- Variant: metrics only, no scoring yet
--
-- Task: A Vietnamese grocery chain closes its books on 2024-12-31 (the as-of date). Only
--   orders with status = 'delivered' count ('cancelled' and 'returned' do not). For every
--   customer with at least one delivered order return recency_days (as-of date minus the date
--   of their latest delivered order; an order on the as-of date gives 0), frequency (number of
--   delivered orders) and monetary (sum of amount_vnd). Sort by customer_id.
-- Learn: grinding/sql-analytics-patterns.md, mục 2.1–2.3

-- INPUT
orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 101         | 2024-12-20 | 350000     | delivered |
| 2        | 101         | 2024-11-02 | 1200000    | delivered |
| 3        | 101         | 2024-12-28 | 90000      | cancelled |
| 4        | 102         | 2024-10-15 | 2500000    | delivered |
| 5        | 103         | 2024-12-31 | 150000     | delivered |
| 6        | 103         | 2024-12-05 | 150000     | returned  |
| 7        | 104         | 2024-09-01 | 800000     | cancelled |
| 8        | 105         | 2024-06-30 | 450000     | delivered |
| 9        | 105         | 2024-07-15 | 600000     | delivered |
| 10       | 105         | 2024-08-01 | 200000     | delivered |

-- EXPECTED
| customer_id | recency_days | frequency | monetary |
|-------------|--------------|-----------|----------|
| 101         | 11           | 2         | 1550000  |
| 102         | 77           | 1         | 2500000  |
| 103         | 0            | 1         | 150000   |
| 105         | 152          | 3         | 1250000  |

-- QUERY
-- write your query here
