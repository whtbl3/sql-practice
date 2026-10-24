-- Problem window/12: Record-breaking months  [Medium]
-- Pattern: Custom frame that excludes the current row (MAX ... 1 PRECEDING)
-- Variant: running max
--
-- Task: A month sets a record if its revenue is higher than every earlier month (the first month
--   always counts). Return month, revenue and previous_best (highest revenue of all earlier months,
--   NULL for the first) for record months only. Sort by month.
-- Learn: grinding/sql-window.md, V5

-- INPUT
monthly_revenue
| month      | revenue |
|------------|---------|
| 2024-01-01 | 100     |
| 2024-02-01 | 80      |
| 2024-03-01 | 120     |
| 2024-04-01 | 120     |
| 2024-05-01 | 150     |
| 2024-06-01 | 90      |

-- EXPECTED
| month      | revenue | previous_best |
|------------|---------|---------------|
| 2024-01-01 | 100     | NULL          |
| 2024-03-01 | 120     | 100           |
| 2024-05-01 | 150     | 120           |

-- QUERY
-- write your query here
