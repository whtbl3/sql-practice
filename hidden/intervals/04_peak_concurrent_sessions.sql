-- HIDDEN TESTS for problem intervals/04. No QUERY section: the problem's QUERY is used.

-- CASE no sessions
-- INPUT
sessions
| session_id:int | viewer:text | joined_at:timestamp | left_at:timestamp |
|----------------|-------------|---------------------|-------------------|

-- EXPECTED
| max_concurrent | peak_start | peak_end |
|----------------|------------|----------|
| 0              | NULL       | NULL     |

-- CASE a chain of hand-overs never goes above 1
-- INPUT
sessions
| session_id | viewer | joined_at           | left_at             |
|------------|--------|---------------------|---------------------|
| 1          | A      | 2024-05-10 08:00:00 | 2024-05-10 09:00:00 |
| 2          | B      | 2024-05-10 09:00:00 | 2024-05-10 10:00:00 |
| 3          | C      | 2024-05-10 10:00:00 | 2024-05-10 11:00:00 |

-- EXPECTED
| max_concurrent | peak_start          | peak_end            |
|----------------|---------------------|---------------------|
| 1              | 2024-05-10 08:00:00 | 2024-05-10 11:00:00 |

-- CASE the peak is reached twice: report the first one
-- INPUT
sessions
| session_id | viewer | joined_at           | left_at             |
|------------|--------|---------------------|---------------------|
| 1          | A      | 2024-05-10 08:00:00 | 2024-05-10 08:30:00 |
| 2          | B      | 2024-05-10 08:10:00 | 2024-05-10 08:20:00 |
| 3          | C      | 2024-05-10 09:00:00 | 2024-05-10 09:30:00 |
| 4          | D      | 2024-05-10 09:05:00 | 2024-05-10 09:06:00 |

-- EXPECTED
| max_concurrent | peak_start          | peak_end            |
|----------------|---------------------|---------------------|
| 2              | 2024-05-10 08:10:00 | 2024-05-10 08:20:00 |
