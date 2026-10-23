-- Problem misc/08: Invalid status transitions of an order state machine  [Hard]
-- Pattern: State machine: LAG(status) -> (from, to) pairs -> NOT EXISTS in an allowed-transitions table (NULL-safe)
-- Variant: the start state is a transition from NULL; duplicates and skipped steps are errors
--
-- Task: An e-commerce order moves created -> paid -> shipped -> delivered. allowed lists every
--   legal (from_status, to_status) pair; from_status NULL means "first event of the order".
--   For each order, sort its events by event_time; every event forms the pair (status of the
--   previous event or NULL, its own status). Return every event whose pair is not in allowed:
--   order_id, event_time, from_status, to_status. Sort by order_id, event_time.
-- Learn: grinding/sql-state-machine.md, B1–B2

-- INPUT
allowed
| from_status | to_status |
|-------------|-----------|
| NULL        | created   |
| created     | paid      |
| paid        | shipped   |
| shipped     | delivered |

order_events
| order_id | event_time          | status    |
|----------|---------------------|-----------|
| 1        | 2024-05-01 08:00:00 | created   |
| 1        | 2024-05-01 08:05:00 | paid      |
| 1        | 2024-05-01 10:00:00 | shipped   |
| 1        | 2024-05-02 09:00:00 | delivered |
| 2        | 2024-05-01 09:00:00 | created   |
| 2        | 2024-05-01 11:00:00 | shipped   |
| 2        | 2024-05-03 15:00:00 | delivered |
| 3        | 2024-05-02 07:00:00 | paid      |
| 3        | 2024-05-02 08:00:00 | shipped   |
| 4        | 2024-05-02 10:00:00 | paid      |
| 4        | 2024-05-02 09:00:00 | created   |
| 4        | 2024-05-02 10:01:00 | paid      |
| 4        | 2024-05-04 12:00:00 | delivered |
| 5        | 2024-05-03 08:00:00 | created   |
| 5        | 2024-05-03 08:10:00 | paid      |
| 5        | 2024-05-03 08:20:00 | created   |

-- EXPECTED
| order_id | event_time          | from_status | to_status |
|----------|---------------------|-------------|-----------|
| 2        | 2024-05-01 11:00:00 | created     | shipped   |
| 3        | 2024-05-02 07:00:00 | NULL        | paid      |
| 4        | 2024-05-02 10:01:00 | paid        | paid      |
| 4        | 2024-05-04 12:00:00 | paid        | delivered |
| 5        | 2024-05-03 08:20:00 | paid        | created   |

-- QUERY
WITH pairs AS (
  SELECT order_id, event_time,
         LAG(status) OVER (PARTITION BY order_id ORDER BY event_time) AS from_status,   -- NULL on the first event
         status AS to_status
  FROM order_events
)
SELECT p.order_id, p.event_time, p.from_status, p.to_status
FROM pairs p
WHERE NOT EXISTS (
  SELECT 1 FROM allowed a
  WHERE a.from_status IS NOT DISTINCT FROM p.from_status       -- NULL = NULL is unknown; this is true
    AND a.to_status = p.to_status
)
ORDER BY p.order_id, p.event_time;
