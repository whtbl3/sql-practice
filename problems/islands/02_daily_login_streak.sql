-- Problem islands/02: Longest daily login streak  [Medium]
-- Pattern: Gaps & Islands (value - ROW_NUMBER)
-- Variant: unit = day (a DATE column) instead of a month
--
-- Task: For each user find the longest run of consecutive calendar days with at least one login
--   (several logins on the same day count once). Return user_id, longest_streak; sort by
--   longest_streak descending, then user_id.
-- Learn: grinding/sql-gaps-islands.md, B1–B5

-- INPUT
logins
| user_id:int | login_date:date |
|-------------|-----------------|
| 1           | 2024-01-01      |
| 1           | 2024-01-02      |
| 1           | 2024-01-03      |
| 1           | 2024-01-05      |
| 2           | 2024-02-28      |
| 2           | 2024-02-29      |
| 2           | 2024-03-01      |
| 2           | 2024-03-01      |
| 3           | 2024-05-05      |
| 3           | 2024-05-05      |

-- EXPECTED
| user_id | longest_streak |
|---------|----------------|
| 1       | 3              |
| 2       | 3              |
| 3       | 1              |

-- QUERY
-- write your query here
WITH grp AS (
  SELECT DISTINCT
    user_id,
    login_date,
    login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
  FROM logins
),
s AS (
  SELECT
    user_id,
    COUNT(grp) AS streak
  FROM grp
  GROUP BY user_id, grp
)
SELECT
  user_id,
  MAX(streak) AS longest_streak
FROM s
GROUP BY user_id
ORDER BY longest_streak DESC, user_id ASC