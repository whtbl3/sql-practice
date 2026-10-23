-- Problem graph/03: Groups of linked accounts (connected components)  [Hard]
-- Pattern: Graph: recursive reachability with UNION (dedupe stops cycles) -> component id = MIN(reachable id)
-- Variant: fraud ring detection: accounts linked directly or through a chain of links
--
-- Task: An e-wallet links two accounts when they share a device or a phone number (account_links,
--   undirected; a link may connect an account to itself). Two accounts are in the same group when a
--   chain of links connects them. Every account in accounts belongs to exactly one group (an
--   account without links is a group of 1). For every group return component_id (the smallest
--   account_id in the group), size and members (the account_ids in increasing order, joined with
--   ', '). Sort by component_id.
-- Learn: grinding/sql-recursive-cte.md, B4

-- INPUT
accounts
| account_id | owner  |
|------------|--------|
| 101        | Harry  |
| 102        | Hazel  |
| 103        | Tim    |
| 104        | Felix  |
| 105        | Ruby   |
| 106        | Leo    |
| 107        | Nicole |
| 108        | Theo   |
| 109        | Linda  |
| 110        | Sam    |

account_links
| account_a | account_b | reason      |
|-----------|-----------|-------------|
| 101       | 102       | same device |
| 103       | 102       | same phone  |
| 104       | 105       | same device |
| 105       | 106       | same phone  |
| 106       | 104       | same device |
| 107       | 107       | same device |
| 108       | 109       | same phone  |

-- EXPECTED
| component_id | size | members       |
|--------------|------|---------------|
| 101          | 3    | 101, 102, 103 |
| 104          | 3    | 104, 105, 106 |
| 107          | 1    | 107           |
| 108          | 2    | 108, 109      |
| 110          | 1    | 110           |

-- QUERY
-- write your query here
