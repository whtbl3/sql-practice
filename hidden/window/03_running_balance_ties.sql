-- HIDDEN TESTS for problem window/03. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
transactions
| txn_id:int | txn_date:date | amount:int |
|------------|---------------|------------|

-- EXPECTED
| txn_id | txn_date | amount | running_balance |
|--------|----------|--------|-----------------|

-- CASE everything on the same day
-- INPUT
transactions
| txn_id:int | txn_date:date | amount:int |
|------------|---------------|------------|
| 1          | 2024-01-01    | 1          |
| 2          | 2024-01-01    | 2          |
| 3          | 2024-01-01    | 3          |

-- EXPECTED
| txn_id | txn_date   | amount | running_balance |
|--------|------------|--------|-----------------|
| 1      | 2024-01-01 | 1      | 1               |
| 2      | 2024-01-01 | 2      | 3               |
| 3      | 2024-01-01 | 3      | 6               |

-- CASE ids inserted out of order
-- INPUT
transactions
| txn_id:int | txn_date:date | amount:int |
|------------|---------------|------------|
| 2          | 2024-01-01    | 5          |
| 1          | 2024-01-01    | 7          |

-- EXPECTED
| txn_id | txn_date   | amount | running_balance |
|--------|------------|--------|-----------------|
| 1      | 2024-01-01 | 7      | 7               |
| 2      | 2024-01-01 | 5      | 12              |
