-- Problem graph/04: Accounts on a circular money flow (cycle detection)  [Hard]
-- Pattern: Graph: recursive walk from every node on directed edges, path array, stop when back at the start
-- Variant: shortest cycle through each node; self-transfers are cycles of length 1
--
-- Task: An anti-money-laundering check looks for money that flows back to where it started.
--   transfers holds directed transfers from_acc -> to_acc (several transfers between the same
--   pair are possible). An account is on a cycle when following transfers from it can lead back
--   to it. For every such account return account and cycle_len = the number of transfers in the
--   shortest cycle through it. Sort by account.
-- Learn: grinding/sql-recursive-cte.md, V4

-- INPUT
transfers
| transfer_id | from_acc | to_acc | amount_vnd |
|-------------|----------|--------|------------|
| 1           | TK-A     | TK-B   | 50000000   |
| 2           | TK-B     | TK-C   | 49000000   |
| 3           | TK-C     | TK-A   | 48000000   |
| 4           | TK-C     | TK-D   | 10000000   |
| 5           | TK-D     | TK-E   | 9000000    |
| 6           | TK-E     | TK-C   | 8000000    |
| 7           | TK-F     | TK-G   | 3000000    |
| 8           | TK-G     | TK-F   | 3000000    |
| 9           | TK-F     | TK-G   | 1000000    |
| 10          | TK-H     | TK-H   | 500000     |
| 11          | TK-I     | TK-J   | 700000     |
| 12          | TK-A     | TK-I   | 100000     |

-- EXPECTED
| account | cycle_len |
|---------|-----------|
| TK-A    | 3         |
| TK-B    | 3         |
| TK-C    | 3         |
| TK-D    | 3         |
| TK-E    | 3         |
| TK-F    | 2         |
| TK-G    | 2         |
| TK-H    | 1         |

-- QUERY
WITH RECURSIVE edges AS (
  SELECT DISTINCT from_acc AS u, to_acc AS v FROM transfers      -- repeated transfers = one edge
),
walk(start_acc, node, len, path) AS (
  SELECT u, v, 1, ARRAY[u, v] FROM edges
  UNION ALL
  SELECT w.start_acc, e.v, w.len + 1, w.path || e.v
  FROM walk w
  JOIN edges e ON e.u = w.node
  WHERE w.node <> w.start_acc                       -- a walk that is back home stops here
    AND (e.v = w.start_acc OR e.v <> ALL (w.path))  -- only the start may be visited twice
)
SELECT start_acc AS account, MIN(len) AS cycle_len
FROM walk
WHERE node = start_acc
GROUP BY start_acc
ORDER BY account;
