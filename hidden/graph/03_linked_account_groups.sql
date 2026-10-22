-- HIDDEN TESTS for problem graph/03. No QUERY section: the problem's QUERY is used.

-- CASE no links: every account alone
-- INPUT
accounts
| account_id | owner |
|------------|-------|
| 2          | A     |
| 1          | B     |

account_links
| account_a:int | account_b:int | reason:text |
|---------------|---------------|-------------|

-- EXPECTED
| component_id | size | members |
|--------------|------|---------|
| 1            | 1    | 1       |
| 2            | 1    | 2       |

-- CASE a long chain given in random order is one group
-- INPUT
accounts
| account_id | owner |
|------------|-------|
| 1          | A     |
| 2          | B     |
| 3          | C     |
| 4          | D     |
| 5          | E     |

account_links
| account_a | account_b | reason |
|-----------|-----------|--------|
| 4         | 5         | x      |
| 2         | 1         | x      |
| 3         | 4         | x      |
| 3         | 2         | x      |

-- EXPECTED
| component_id | size | members       |
|--------------|------|---------------|
| 1            | 5    | 1, 2, 3, 4, 5 |
