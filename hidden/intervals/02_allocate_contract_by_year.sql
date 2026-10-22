-- HIDDEN TESTS for problem intervals/02. No QUERY section: the problem's QUERY is used.

-- CASE no contracts
-- INPUT
contracts
| contract_id:int | customer:text | start_date:date | end_date:date | value_vnd:int |
|-----------------|---------------|-----------------|---------------|---------------|

-- EXPECTED
| contract_id:int | year:int | days:int | allocated_vnd:numeric |
|-----------------|----------|----------|-----------------------|

-- CASE a one-day contract, and a full leap year
-- INPUT
contracts
| contract_id | customer | start_date | end_date   | value_vnd |
|-------------|----------|------------|------------|-----------|
| 1           | A        | 2024-02-29 | 2024-02-29 | 500000    |
| 2           | B        | 2024-01-01 | 2024-12-31 | 732000    |
| 3           | C        | 2022-11-01 | 2024-02-29 | 4850000   |

-- EXPECTED
| contract_id | year | days | allocated_vnd |
|-------------|------|------|---------------|
| 1           | 2024 | 1    | 500000        |
| 2           | 2024 | 366  | 732000        |
| 3           | 2022 | 61   | 608745        |
| 3           | 2023 | 365  | 3642490       |
| 3           | 2024 | 60   | 598765        |
