-- HIDDEN TESTS for problem misc/08. No QUERY section: the problem's QUERY is used.

-- CASE every order is valid
-- INPUT
allowed
| from_status | to_status |
|-------------|-----------|
| NULL        | created   |
| created     | paid      |

order_events
| order_id | event_time          | status  |
|----------|---------------------|---------|
| 1        | 2024-05-01 08:00:00 | created |
| 1        | 2024-05-01 08:05:00 | paid    |
| 2        | 2024-05-01 09:00:00 | created |

-- EXPECTED
| order_id:int | event_time:timestamp | from_status:text | to_status:text |
|--------------|----------------------|------------------|----------------|

-- CASE a cancel path in the rules, and an order that starts in the middle
-- INPUT
allowed
| from_status | to_status |
|-------------|-----------|
| NULL        | created   |
| created     | paid      |
| created     | cancelled |
| paid        | cancelled |

order_events
| order_id | event_time          | status    |
|----------|---------------------|-----------|
| 1        | 2024-05-01 08:00:00 | created   |
| 1        | 2024-05-01 08:30:00 | cancelled |
| 2        | 2024-05-01 09:00:00 | cancelled |
| 3        | 2024-05-01 10:00:00 | created   |
| 3        | 2024-05-01 10:10:00 | cancelled |
| 3        | 2024-05-01 10:20:00 | paid      |

-- EXPECTED
| order_id | event_time          | from_status | to_status |
|----------|---------------------|-------------|-----------|
| 2        | 2024-05-01 09:00:00 | NULL        | cancelled |
| 3        | 2024-05-01 10:20:00 | cancelled   | paid      |
