-- Problem churn/02: Monthly churn rate of a subscription service  [Medium]
-- Pattern: Churn: month spine (generate_series) + interval "active on day d" test + COUNT FILTER
-- Variant: contract data with start/end dates instead of order events
--
-- Task: A Vietnamese music streaming app sells monthly subscriptions. A subscription is active
--   on day d when start_date <= d AND (end_date IS NULL OR d < end_date). For every month from
--   2024-01 to 2024-06 (all six months, even with no data) return:
--     active_start   = subscriptions active on the first day of the month
--     churned        = of those, the ones NOT active on the first day of the next month
--     churn_rate_pct = churned / active_start * 100, rounded to 1 decimal (NULL if active_start = 0)
--   Subscriptions that start and end inside the same month are in neither number. Count
--   subscriptions, not customers. month is 'YYYY-MM'. Sort by month.
-- Learn: grinding/sql-churn.md, V2

-- INPUT
subscriptions
| sub_id | customer_id | plan    | start_date | end_date   |
|--------|-------------|---------|------------|------------|
| 1      | 101         | Premium | 2023-11-15 | NULL       |
| 2      | 102         | Basic   | 2023-12-01 | 2024-02-10 |
| 3      | 103         | Basic   | 2024-01-01 | 2024-01-31 |
| 4      | 104         | Premium | 2024-01-15 | 2024-01-25 |
| 5      | 105         | Basic   | 2024-02-20 | 2024-05-01 |
| 6      | 106         | Family  | 2023-06-01 | 2024-03-01 |
| 7      | 107         | Premium | 2024-03-01 | NULL       |
| 8      | 108         | Basic   | 2024-04-10 | 2024-06-30 |
| 9      | 102         | Premium | 2024-02-15 | NULL       |

-- EXPECTED
| month   | active_start | churned | churn_rate_pct |
|---------|--------------|---------|----------------|
| 2024-01 | 4            | 1       | 25.0           |
| 2024-02 | 3            | 2       | 66.7           |
| 2024-03 | 4            | 0       | 0.0            |
| 2024-04 | 4            | 1       | 25.0           |
| 2024-05 | 4            | 0       | 0.0            |
| 2024-06 | 4            | 1       | 25.0           |

-- QUERY
-- write your query here
