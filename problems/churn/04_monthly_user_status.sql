-- Problem churn/04: new / retained / resurrected / churned per user and month  [Hard]
-- Pattern: Churn: calendar spine (users x every month) + LAG(active flag) + CASE
-- Variant: inactive months need a row too, otherwise 'churned' can never be detected
--
-- Task: An English-learning app counts a user as active in a month when they have at least one
--   row in activity that month. Report months run from the earliest to the latest month found
--   in activity (every month in between, even if nobody was active). For each user and each
--   report month from the user's first active month onwards, the status is the FIRST that applies:
--     'new'          active this month and it is the user's first active month
--     'retained'     active this month and active the previous month
--     'resurrected'  active this month, not active the previous month
--     'churned'      not active this month but active the previous month
--   and no row at all when the user is inactive in both months. Return month ('YYYY-MM'),
--   user_id, status. Sort by month, user_id.
-- Learn: grinding/sql-churn.md, B1–B3

-- INPUT
activity
| user_id | activity_date |
|---------|---------------|
| 1       | 2024-01-03    |
| 1       | 2024-01-20    |
| 1       | 2024-02-14    |
| 1       | 2024-03-01    |
| 1       | 2024-05-30    |
| 2       | 2024-02-29    |
| 3       | 2024-01-31    |
| 3       | 2024-04-01    |
| 4       | 2024-03-10    |
| 4       | 2024-04-10    |
| 4       | 2024-05-10    |
| 5       | 2024-05-01    |
| 5       | 2024-05-02    |

-- EXPECTED
| month   | user_id | status      |
|---------|---------|-------------|
| 2024-01 | 1       | new         |
| 2024-01 | 3       | new         |
| 2024-02 | 1       | retained    |
| 2024-02 | 2       | new         |
| 2024-02 | 3       | churned     |
| 2024-03 | 1       | retained    |
| 2024-03 | 2       | churned     |
| 2024-03 | 4       | new         |
| 2024-04 | 1       | churned     |
| 2024-04 | 3       | resurrected |
| 2024-04 | 4       | retained    |
| 2024-05 | 1       | resurrected |
| 2024-05 | 3       | churned     |
| 2024-05 | 4       | retained    |
| 2024-05 | 5       | new         |

-- QUERY
-- write your query here
