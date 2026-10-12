-- HIDDEN TESTS for problem agg/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
transactions
| txn_date:date | type:text | amount:int |
|---------------|-----------|------------|

-- EXPECTED
| month | total_income | total_expense | balance | cumulative_balance |
|-------|--------------|---------------|---------|--------------------|

-- CASE year boundary orders correctly
-- INPUT
transactions
| txn_date:date | type:text | amount:int |
|---------------|-----------|------------|
| 2024-01-01    | Income    | 10         |
| 2023-12-31    | Expense   | 4          |

-- EXPECTED
| month   | total_income | total_expense | balance | cumulative_balance |
|---------|--------------|---------------|---------|--------------------|
| 2023-12 | 0            | 4             | -4      | -4                 |
| 2024-01 | 10           | 0             | 10      | 6                  |

-- CASE many rows in one month
-- INPUT
transactions
| txn_date:date | type:text | amount:int |
|---------------|-----------|------------|
| 2024-05-01    | Income    | 5          |
| 2024-05-02    | Income    | 5          |
| 2024-05-03    | Expense   | 3          |
| 2024-05-04    | Expense   | 2          |

-- EXPECTED
| month   | total_income | total_expense | balance | cumulative_balance |
|---------|--------------|---------------|---------|--------------------|
| 2024-05 | 10           | 5             | 5       | 5                  |
