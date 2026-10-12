-- Problem sessions/01: Sessionize events by inactivity gap  [Hard]
-- Pattern: LAG gap flag, running SUM as session id
-- Variant: sessionization
--
-- Task: A new session starts when the gap since the user's previous event is MORE than 30 minutes.
--   Return user_id, session_no (1, 2, ... per user), session_start, session_end, events (count).
--   Sort by user_id, session_no.

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
-- write your query here
