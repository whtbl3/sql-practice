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
-- Learn: grinding/sql-analytics-patterns.md, mục 8.6

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
-- write your query here
