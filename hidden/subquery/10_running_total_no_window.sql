-- HIDDEN TESTS for problem subquery/10. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
transactions
| txn_id:int | amount:int |
|------------|------------|

-- EXPECTED
| txn_id | amount | running_total |
|--------|--------|---------------|

-- CASE inserted out of order
-- INPUT
transactions
| txn_id:int | amount:int |
|------------|------------|
| 3          | 1          |
| 1          | 10         |
| 2          | 100        |

-- EXPECTED
| txn_id | amount | running_total |
|--------|--------|---------------|
| 1      | 10     | 10            |
| 2      | 100    | 110           |
| 3      | 1      | 111           |

-- CASE all negative
-- INPUT
transactions
| txn_id:int | amount:int |
|------------|------------|
| 1          | -1         |
| 2          | -2         |

-- EXPECTED
| txn_id | amount | running_total |
|--------|--------|---------------|
| 1      | -1     | -1            |
| 2      | -2     | -3            |
