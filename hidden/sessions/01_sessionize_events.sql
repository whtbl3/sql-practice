-- HIDDEN TESTS for problem sessions/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
events
| user_id:int | event_time:timestamp |
|-------------|----------------------|

-- EXPECTED
| user_id | session_no | session_start | session_end | events |
|---------|------------|---------------|-------------|--------|

-- CASE a gap of exactly 30 minutes stays in the same session
-- INPUT
events
| user_id:int | event_time:timestamp |
|-------------|----------------------|
| 1           | 2024-01-01 09:00:00  |
| 1           | 2024-01-01 09:30:00  |
| 1           | 2024-01-01 10:00:01  |

-- EXPECTED
| user_id | session_no | session_start       | session_end         | events |
|---------|------------|---------------------|---------------------|--------|
| 1       | 1          | 2024-01-01 09:00:00 | 2024-01-01 09:30:00 | 2      |
| 1       | 2          | 2024-01-01 10:00:01 | 2024-01-01 10:00:01 | 1      |

-- CASE unsorted input and a session crossing midnight
-- INPUT
events
| user_id:int | event_time:timestamp |
|-------------|----------------------|
| 7           | 2024-01-02 00:10:00  |
| 7           | 2024-01-01 23:50:00  |
| 7           | 2024-01-03 08:00:00  |

-- EXPECTED
| user_id | session_no | session_start       | session_end         | events |
|---------|------------|---------------------|---------------------|--------|
| 7       | 1          | 2024-01-01 23:50:00 | 2024-01-02 00:10:00 | 2      |
| 7       | 2          | 2024-01-03 08:00:00 | 2024-01-03 08:00:00 | 1      |
