-- Problem gaps/04: Unusually long absence compared with the customer's own rhythm  [Hard]
-- Pattern: Gaps: LAG gaps -> PERCENTILE_CONT(0.5) WITHIN GROUP per customer -> compare with days since last
-- Variant: a personal threshold (2 x own median gap) instead of one fixed cut-off for everybody
--
-- Task: A pharmacy chain wants to call regular customers who are late. As-of date = 2024-12-31.
--   Using distinct purchase days, a customer's gaps are the days between consecutive purchase
--   days. Only customers with at least 3 gaps are considered. median_gap = the median of their
--   gaps (average of the two middle values when the count is even); days_since_last = as-of
--   date - last purchase day. A customer is late when days_since_last > 2 * median_gap.
--   Return only late customers: customer_id, median_gap (1 decimal), days_since_last and
--   ratio = days_since_last / median_gap (1 decimal). Sort by ratio DESC, customer_id.
-- Learn: grinding/sql-purchase-gaps.md, B3

-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-11-08 |
| 2        | 1           | 2024-11-15 |
| 3        | 1           | 2024-11-22 |
| 4        | 1           | 2024-11-30 |
| 5        | 2           | 2024-09-10 |
| 6        | 2           | 2024-10-10 |
| 7        | 2           | 2024-11-10 |
| 8        | 2           | 2024-12-10 |
| 9        | 3           | 2024-07-21 |
| 10       | 3           | 2024-07-31 |
| 11       | 3           | 2024-11-08 |
| 12       | 3           | 2024-11-20 |
| 13       | 3           | 2024-12-04 |
| 14       | 4           | 2024-01-01 |
| 15       | 4           | 2024-01-05 |
| 16       | 4           | 2024-01-09 |
| 17       | 5           | 2024-12-06 |
| 18       | 5           | 2024-12-11 |
| 19       | 5           | 2024-12-16 |
| 20       | 5           | 2024-12-21 |
| 21       | 6           | 2024-11-25 |
| 22       | 6           | 2024-11-27 |
| 23       | 6           | 2024-11-27 |
| 24       | 6           | 2024-11-29 |
| 25       | 6           | 2024-12-01 |

-- EXPECTED
| customer_id | median_gap | days_since_last | ratio |
|-------------|------------|-----------------|-------|
| 6           | 2.0        | 30              | 15.0  |
| 1           | 7.0        | 31              | 4.4   |
| 3           | 13.0       | 27              | 2.1   |

-- QUERY
-- write your query here
