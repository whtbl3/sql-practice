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
-- Learn: grinding/sql-analytics-patterns.md, mục 8.5

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
WITH act AS (                                       -- one row per (user, active month)
  SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m
  FROM activity
),
months AS (                                         -- the calendar spine, gaps included
  SELECT generate_series(MIN(m), MAX(m), INTERVAL '1 month')::date AS m
  FROM act
),
firsts AS (
  SELECT user_id, MIN(m) AS first_m FROM act GROUP BY user_id
),
grid AS (                                           -- every user x every month since their first
  SELECT f.user_id, mo.m, f.first_m,
         a.user_id IS NOT NULL AS active
  FROM firsts f
  JOIN months mo ON mo.m >= f.first_m
  LEFT JOIN act a ON a.user_id = f.user_id AND a.m = mo.m
),
labeled AS (
  SELECT user_id, m,
         CASE
           WHEN active AND m = first_m THEN 'new'
           WHEN active AND LAG(active) OVER w THEN 'retained'
           WHEN active THEN 'resurrected'
           WHEN LAG(active) OVER w THEN 'churned'
         END AS status                              -- NULL: inactive two months in a row
  FROM grid
  WINDOW w AS (PARTITION BY user_id ORDER BY m)
)
SELECT TO_CHAR(m, 'YYYY-MM') AS month, user_id, status
FROM labeled
WHERE status IS NOT NULL
ORDER BY m, user_id;
