-- Problem window/03: Running balance with same-day transactions  [Medium]
-- Pattern: Running SUM, and the default RANGE frame with ties
-- Variant: window frame
--
-- Task: Return every transaction with running_balance = sum of amount over all transactions up to
--   and including this one, in order of txn_date then txn_id. Each row must add exactly its own
--   amount, even when several transactions share a date. Sort by txn_date, txn_id.
-- Learn: grinding/sql-subquery-window.md, mục W3

-- INPUT
transactions
| txn_id | txn_date   | amount |
|--------|------------|--------|
| 1      | 2024-01-01 | 100    |
| 2      | 2024-01-02 | -30    |
| 3      | 2024-01-02 | 50     |
| 4      | 2024-01-03 | -20    |
| 5      | 2024-01-05 | 10     |

-- EXPECTED
| txn_id | txn_date   | amount | running_balance |
|--------|------------|--------|-----------------|
| 1      | 2024-01-01 | 100    | 100             |
| 2      | 2024-01-02 | -30    | 70              |
| 3      | 2024-01-02 | 50     | 120             |
| 4      | 2024-01-03 | -20    | 100             |
| 5      | 2024-01-05 | 10     | 110             |

-- QUERY
-- write your query here
