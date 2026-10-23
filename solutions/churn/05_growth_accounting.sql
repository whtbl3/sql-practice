-- Problem churn/05: Growth accounting and quick ratio  [Hard]
-- Pattern: Churn: per-user spine from first month (history before the report) + status + monthly COUNT FILTER
-- Variant: one row per report month; history before the report window decides 'new' vs 'resurrected'
--
-- Task: Same rules as churn/04 (active month = at least one activity row; 'new' = first active
--   month ever, 'retained', 'resurrected', 'churned' = active last month but not this month).
--   The report covers 2024-01 to 2024-06, but activity before 2024-01 is history that still
--   decides the statuses (a user first seen in 2023 is never 'new' in 2024); activity after
--   2024-06 is ignored. For EVERY report month return month ('YYYY-MM'), mau (active users),
--   new_users, retained, resurrected, churned and quick_ratio = (new_users + resurrected) /
--   churned rounded to 2 decimals (NULL when churned = 0). Sort by month.
-- Learn: grinding/sql-churn.md, B2, B4

-- INPUT
activity
| user_id | activity_date |
|---------|---------------|
| 1       | 2023-12-20    |
| 1       | 2024-01-05    |
| 1       | 2024-02-05    |
| 2       | 2023-10-01    |
| 2       | 2024-01-09    |
| 3       | 2024-01-15    |
| 3       | 2024-03-15    |
| 3       | 2024-04-15    |
| 4       | 2024-02-01    |
| 4       | 2024-03-01    |
| 4       | 2024-04-01    |
| 4       | 2024-05-01    |
| 4       | 2024-06-01    |
| 5       | 2024-06-30    |
| 5       | 2024-07-01    |
| 6       | 2023-11-11    |
| 7       | 2024-04-20    |
| 7       | 2024-06-20    |

-- EXPECTED
| month   | mau | new_users | retained | resurrected | churned | quick_ratio |
|---------|-----|-----------|----------|-------------|---------|-------------|
| 2024-01 | 3   | 1         | 1        | 1           | 0       | NULL        |
| 2024-02 | 2   | 1         | 1        | 0           | 2       | 0.50        |
| 2024-03 | 2   | 0         | 1        | 1           | 1       | 1.00        |
| 2024-04 | 3   | 1         | 2        | 0           | 0       | NULL        |
| 2024-05 | 1   | 0         | 1        | 0           | 2       | 0.00        |
| 2024-06 | 3   | 1         | 1        | 1           | 0       | NULL        |

-- QUERY
WITH act AS (
  SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m
  FROM activity
  WHERE activity_date < DATE '2024-07-01'           -- after the report: ignored
),
grid AS (                                           -- each user: every month from their first one to 2024-06
  SELECT f.user_id, g.m::date AS m, f.first_m
  FROM (SELECT user_id, MIN(m) AS first_m FROM act GROUP BY user_id) f
  CROSS JOIN LATERAL generate_series(f.first_m, DATE '2024-06-01', INTERVAL '1 month') AS g(m)
),
flagged AS (
  SELECT g.user_id, g.m, g.first_m, a.user_id IS NOT NULL AS active
  FROM grid g
  LEFT JOIN act a ON a.user_id = g.user_id AND a.m = g.m
),
labeled AS (
  SELECT m,
         CASE
           WHEN active AND m = first_m THEN 'new'
           WHEN active AND LAG(active) OVER w THEN 'retained'
           WHEN active THEN 'resurrected'
           WHEN LAG(active) OVER w THEN 'churned'
         END AS status
  FROM flagged
  WINDOW w AS (PARTITION BY user_id ORDER BY m)
),
report AS (                                         -- the six report months, even if empty
  SELECT generate_series(DATE '2024-01-01', DATE '2024-06-01', INTERVAL '1 month')::date AS m
),
counts AS (
  SELECT r.m,
         COUNT(*) FILTER (WHERE l.status IN ('new', 'retained', 'resurrected')) AS mau,
         COUNT(*) FILTER (WHERE l.status = 'new')         AS new_users,
         COUNT(*) FILTER (WHERE l.status = 'retained')    AS retained,
         COUNT(*) FILTER (WHERE l.status = 'resurrected') AS resurrected,
         COUNT(*) FILTER (WHERE l.status = 'churned')     AS churned
  FROM report r
  LEFT JOIN labeled l ON l.m = r.m                  -- months before 2024-01 drop out here
  GROUP BY r.m
)
SELECT TO_CHAR(m, 'YYYY-MM') AS month, mau, new_users, retained, resurrected, churned,
       ROUND((new_users + resurrected)::numeric / NULLIF(churned, 0), 2) AS quick_ratio
FROM counts
ORDER BY m;
