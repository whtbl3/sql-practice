-- Problem cohort/08: RFM segment migration between two snapshots  [Hard]
-- Pattern: RFM: CROSS JOIN snapshot dates + LEFT JOIN + conditional aggregation
-- Variant: comparing segments at two as-of dates instead of scoring one snapshot
--
-- Task: Two snapshots: q1 = 2024-04-01 and q2 = 2024-07-01. At each snapshot only Completed
--   orders placed BEFORE the snapshot date count. Label each customer at each snapshot with the
--   FIRST matching rule (recency_days = snapshot date - latest counted order date):
--     'Not Started' no counted orders yet
--     'Champion'    recency_days <= 30 AND frequency >= 3
--     'Active'      recency_days <= 30
--     'At Risk'     frequency >= 3
--     'Lapsed'      everything else
--   Return customer_id, segment_q1, segment_q2 only for customers whose segment changed.
--   Sort by customer_id.
-- Learn: grinding/sql-analytics-patterns.md, mục 2.8

-- INPUT
customers
| customer_id | name  |
|-------------|-------|
| 1           | An    |
| 2           | Binh  |
| 3           | Chi   |
| 4           | Dung  |
| 5           | Em    |
| 6           | Giang |
| 7           | Hoa   |

orders
| order_id | customer_id | order_date | status    |
|----------|-------------|------------|-----------|
| 1        | 1           | 2024-03-10 | Completed |
| 2        | 1           | 2024-03-20 | Completed |
| 3        | 1           | 2024-03-25 | Completed |
| 4        | 1           | 2024-06-15 | Completed |
| 5        | 2           | 2024-03-05 | Completed |
| 6        | 2           | 2024-03-15 | Completed |
| 7        | 2           | 2024-03-28 | Completed |
| 8        | 3           | 2024-02-01 | Completed |
| 9        | 4           | 2024-05-10 | Completed |
| 10       | 4           | 2024-06-20 | Completed |
| 11       | 5           | 2024-03-30 | Completed |
| 12       | 5           | 2024-06-25 | Cancelled |
| 13       | 7           | 2024-07-05 | Completed |

-- EXPECTED
| customer_id | segment_q1  | segment_q2 |
|-------------|-------------|------------|
| 2           | Champion    | At Risk    |
| 4           | Not Started | Active     |
| 5           | Active      | Lapsed     |

-- QUERY
-- write your query here
