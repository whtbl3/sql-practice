-- Problem sessions/01: Sessionize events by inactivity gap  [Hard]
-- Pattern: LAG gap flag, running SUM as session id
-- Variant: sessionization
--
-- Task: A new session starts when the gap since the user's previous event is MORE than 30 minutes.
--   Return user_id, session_no (1, 2, ... per user), session_start, session_end, events (count).
--   Sort by user_id, session_no.
-- Learn: grinding/sql-analytics-patterns.md, mục 1.6e

-- INPUT
events
| user_id | event_time          |
|---------|---------------------|
| 1       | 2024-01-01 09:00:00 |
| 1       | 2024-01-01 09:10:00 |
| 1       | 2024-01-01 09:35:00 |
| 1       | 2024-01-01 10:30:00 |
| 1       | 2024-01-01 10:31:00 |
| 2       | 2024-01-01 12:00:00 |

-- EXPECTED
| user_id | session_no | session_start       | session_end         | events |
|---------|------------|---------------------|---------------------|--------|
| 1       | 1          | 2024-01-01 09:00:00 | 2024-01-01 09:35:00 | 3      |
| 1       | 2          | 2024-01-01 10:30:00 | 2024-01-01 10:31:00 | 2      |
| 2       | 1          | 2024-01-01 12:00:00 | 2024-01-01 12:00:00 | 1      |

-- QUERY
WITH flagged AS (
    SELECT user_id, event_time,
           CASE WHEN event_time - LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time)
                     > INTERVAL '30 minutes' THEN 1 ELSE 0 END AS new_session
    FROM events
),
numbered AS (
    SELECT user_id, event_time,
           1 + SUM(new_session) OVER (PARTITION BY user_id ORDER BY event_time) AS session_no
    FROM flagged
)
SELECT user_id, session_no::int AS session_no,
       MIN(event_time) AS session_start, MAX(event_time) AS session_end, COUNT(*) AS events
FROM numbered
GROUP BY user_id, session_no
ORDER BY user_id, session_no;
