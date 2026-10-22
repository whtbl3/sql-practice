-- Problem intervals/04: Peak number of concurrent live-class viewers  [Hard]
-- Pattern: Intervals: events (+1 join, -1 leave) -> net change per timestamp -> running SUM -> max and when
-- Variant: half-open sessions, a leave and a join at the same moment must not double count
--
-- Task: An online English school streams a live class. A viewer is watching during
--   [joined_at, left_at): at the moment someone leaves they are no longer counted, so a viewer
--   leaving at 19:45 and another joining at 19:45 are never counted together. Return ONE row:
--   max_concurrent (the highest number of viewers watching at the same time), peak_start (the
--   first moment that number is reached) and peak_end (the first moment after peak_start when
--   the number drops below max_concurrent). With no sessions return 0, NULL, NULL.
-- Learn: grinding/sql-analytics-patterns.md, mục 12.5

-- INPUT
sessions
| session_id | viewer | joined_at           | left_at             |
|------------|--------|---------------------|---------------------|
| 1          | Hugo   | 2024-05-10 19:00:00 | 2024-05-10 20:00:00 |
| 2          | Mia    | 2024-05-10 19:30:00 | 2024-05-10 19:45:00 |
| 3          | Paul   | 2024-05-10 19:45:00 | 2024-05-10 20:30:00 |
| 4          | Tara   | 2024-05-10 19:40:00 | 2024-05-10 19:50:00 |
| 5          | Kyle   | 2024-05-10 21:00:00 | 2024-05-10 21:10:00 |

-- EXPECTED
| max_concurrent | peak_start          | peak_end            |
|----------------|---------------------|---------------------|
| 3              | 2024-05-10 19:40:00 | 2024-05-10 19:50:00 |

-- QUERY
WITH events AS (
  SELECT joined_at AS ts, 1 AS delta FROM sessions
  UNION ALL
  SELECT left_at,  -1        FROM sessions
),
per_ts AS (                                         -- net change per moment: a leave and a join cancel out
  SELECT ts, SUM(delta) AS delta FROM events GROUP BY ts
),
running AS (
  SELECT ts, SUM(delta) OVER (ORDER BY ts) AS viewers
  FROM per_ts
),
peak AS (
  SELECT ts, viewers FROM running ORDER BY viewers DESC, ts LIMIT 1
)
SELECT COALESCE(MAX(p.viewers), 0) AS max_concurrent,
       MAX(p.ts)                   AS peak_start,
       (SELECT MIN(r.ts) FROM running r
        WHERE r.ts > MAX(p.ts) AND r.viewers < MAX(p.viewers)) AS peak_end
FROM peak p;                                        -- aggregate without GROUP BY: always one row
