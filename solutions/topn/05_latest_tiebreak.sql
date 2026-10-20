-- Problem topn/05: Latest balance snapshot with a tie-break  [Medium]
-- Pattern: Latest row per group with a deterministic tie-break (ROW_NUMBER)
-- Variant: two rows can share the same date: the larger id wins
--
-- Task: For each account return its most recent balance snapshot. If two snapshots share the same
--   snapshot_date, take the one with the larger snapshot_id. Return account_id, snapshot_id,
--   balance; sort by account_id.
-- Learn: grinding/sql-analytics-patterns.md, mục 5.5

-- INPUT
balance_snapshots
| snapshot_id:int | account_id:int | snapshot_date:date | balance:int |
|-----------------|----------------|--------------------|-------------|
| 1               | 10             | 2024-01-01         | 100         |
| 2               | 10             | 2024-02-01         | 150         |
| 3               | 10             | 2024-02-01         | 175         |
| 4               | 20             | 2024-01-15         | 300         |
| 5               | 30             | 2024-03-01         | 50          |
| 6               | 30             | 2024-02-01         | 60          |

-- EXPECTED
| account_id | snapshot_id | balance |
|------------|-------------|---------|
| 10         | 3           | 175     |
| 20         | 4           | 300     |
| 30         | 5           | 50      |

-- QUERY
SELECT account_id, snapshot_id, balance
FROM (
  SELECT account_id, snapshot_id, balance,
         ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY snapshot_date DESC, snapshot_id DESC) AS rn
  FROM balance_snapshots
) t
WHERE rn = 1
ORDER BY account_id;
