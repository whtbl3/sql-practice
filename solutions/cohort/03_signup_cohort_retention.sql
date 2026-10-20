-- Problem cohort/03: Retention by signup month  [Hard]
-- Pattern: Cohort / retention with a separate users table
-- Variant: cohort = signup month; the cohort size includes users who never had an event
--
-- Task: Users belong to the cohort of their signup month. For every (cohort_month, month_offset)
--   with at least one active user return active_users (distinct users with an event in that
--   month) and retention_pct = active_users / cohort size * 100 rounded to 1 decimal, where
--   cohort size counts ALL users who signed up that month, including users with no events.
--   month_offset = months between the signup month and the event month; events before the signup
--   month are ignored. cohort_month is 'YYYY-MM'. Sort by cohort_month, month_offset.
-- Learn: grinding/sql-analytics-patterns.md, mục 3.5a

-- INPUT
users
| user_id:int | signup_date:date |
|-------------|------------------|
| 1           | 2024-01-10       |
| 2           | 2024-01-20       |
| 3           | 2024-01-25       |
| 4           | 2024-02-05       |

events
| user_id:int | event_date:date |
|-------------|-----------------|
| 1           | 2024-01-12      |
| 1           | 2024-02-01      |
| 1           | 2024-02-15      |
| 2           | 2023-12-30      |
| 2           | 2024-03-02      |
| 4           | 2024-02-20      |
| 4           | 2024-04-01      |

-- EXPECTED
| cohort_month | month_offset | active_users | retention_pct |
|--------------|--------------|--------------|---------------|
| 2024-01      | 0            | 1            | 33.3          |
| 2024-01      | 1            | 1            | 33.3          |
| 2024-01      | 2            | 1            | 33.3          |
| 2024-02      | 0            | 1            | 100.0         |
| 2024-02      | 2            | 1            | 100.0         |

-- QUERY
WITH u AS (
  SELECT user_id, DATE_TRUNC('month', signup_date)::date AS cohort FROM users
),
sizes AS (
  SELECT cohort, COUNT(*) AS cohort_size FROM u GROUP BY cohort
),
act AS (
  SELECT u.cohort,
         (EXTRACT(YEAR FROM e.event_date)::int * 12 + EXTRACT(MONTH FROM e.event_date)::int)
       - (EXTRACT(YEAR FROM u.cohort)::int * 12 + EXTRACT(MONTH FROM u.cohort)::int) AS month_offset,
         COUNT(DISTINCT u.user_id) AS active_users
  FROM u JOIN events e ON e.user_id = u.user_id
  GROUP BY u.cohort, month_offset
)
SELECT TO_CHAR(a.cohort, 'YYYY-MM') AS cohort_month, a.month_offset, a.active_users,
       ROUND(100.0 * a.active_users / s.cohort_size, 1) AS retention_pct
FROM act a
JOIN sizes s ON s.cohort = a.cohort
WHERE a.month_offset >= 0
ORDER BY cohort_month, a.month_offset;
