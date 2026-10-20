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
-- write your query here
