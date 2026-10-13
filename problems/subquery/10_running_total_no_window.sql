-- Problem subquery/10: Running total without window functions  [Medium]
-- Pattern: Correlated subquery with an inequality (x.id <= t.id)
-- Variant: the keyword OVER is forbidden
--
-- Task: Return txn_id, amount and running_total (sum of amount over all transactions with txn_id <=
--   this one) WITHOUT window functions (OVER is rejected). Sort by txn_id.
-- @forbid: \bOVER\s*\(
-- Learn: grinding/sql-subquery-window.md, mục S2

-- INPUT
transactions
| txn_id | amount |
|--------|--------|
| 1      | 100    |
| 2      | -30    |
| 3      | 50     |
| 5      | 20     |

-- EXPECTED
| txn_id | amount | running_total |
|--------|--------|---------------|
| 1      | 100    | 100           |
| 2      | -30    | 70            |
| 3      | 50     | 120           |
| 5      | 20     | 140           |

-- QUERY
-- write your query here
