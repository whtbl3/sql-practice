-- Problem islands/04: Current activity streak  [Hard]
-- Pattern: Gaps & Islands (pick the island that ends at the latest date)
-- Variant: only the streak that ends on the user's most recent activity day
--
-- Task: For each user return the length of their CURRENT streak: the run of consecutive days
--   (several rows on one day count once) that ends on the user's most recent activity date.
--   Return user_id, current_streak; sort by user_id.

-- INPUT
activity
| user_id:int | activity_date:date |
|-------------|--------------------|
| 1           | 2024-01-01         |
| 1           | 2024-01-02         |
| 1           | 2024-01-03         |
| 2           | 2024-01-01         |
| 2           | 2024-01-02         |
| 2           | 2024-01-03         |
| 2           | 2024-01-10         |
| 3           | 2024-02-01         |
| 3           | 2024-02-01         |
| 3           | 2024-02-02         |

-- EXPECTED
| user_id | current_streak |
|---------|----------------|
| 1       | 3              |
| 2       | 1              |
| 3       | 2              |

-- QUERY
-- write your query here
WITH d AS (
  SELECT DISTINCT
    user_id,
    activity_date
  FROM activity
),
g AS (
  SELECT 
    user_id,
    activity_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY activity_date))::int AS grp
  FROM d
),
s AS (
  SELECT
    user_id,
    grp,
    COUNT(*) AS current_streak
  FROM g
  GROUP BY user_id, grp
)
SELECT user_id, current_streak
FROM s WHERE grp = (SELECT MAX(grp) FROM s sub WHERE s.user_id = sub.user_id)
ORDER BY user_id