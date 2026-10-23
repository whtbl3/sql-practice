-- Problem intervals/03: Merge overlapping or adjacent incident periods  [Hard]
-- Pattern: Intervals: running MAX(end) over the earlier rows -> new-group flag -> SUM(flag) as group id
-- Variant: gaps & islands on ranges; compare with the running max end, not just the previous row's end
--
-- Task: A hosting company logs server incidents as date ranges [start_date, end_date] (both
--   included). Per server, merge incidents that overlap or touch (an incident that starts the
--   day after another one's end continues the same outage). For every merged outage return
--   server, outage_start, outage_end, days (end - start + 1) and incidents (number of logged
--   incidents merged into it). Sort by server, outage_start.
-- Learn: grinding/sql-intervals.md, B4

-- INPUT
incidents
| incident_id | server | start_date | end_date   |
|-------------|--------|------------|------------|
| 1           | web-01 | 2024-01-01 | 2024-01-03 |
| 2           | web-01 | 2024-01-02 | 2024-01-05 |
| 3           | web-01 | 2024-01-06 | 2024-01-06 |
| 4           | web-01 | 2024-01-10 | 2024-01-12 |
| 5           | web-01 | 2024-01-11 | 2024-01-11 |
| 6           | db-01  | 2024-01-01 | 2024-01-31 |
| 7           | db-01  | 2024-01-05 | 2024-01-07 |
| 8           | db-01  | 2024-01-20 | 2024-01-25 |
| 9           | db-01  | 2024-02-02 | 2024-02-03 |

-- EXPECTED
| server | outage_start | outage_end | days | incidents |
|--------|--------------|------------|------|-----------|
| db-01  | 2024-01-01   | 2024-01-31 | 31   | 3         |
| db-01  | 2024-02-02   | 2024-02-03 | 2    | 1         |
| web-01 | 2024-01-01   | 2024-01-06 | 6    | 3         |
| web-01 | 2024-01-10   | 2024-01-12 | 3    | 2         |

-- QUERY
-- write your query here
