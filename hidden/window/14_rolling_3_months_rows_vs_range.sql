-- HIDDEN TESTS for problem window/14. No QUERY section: the problem's QUERY is used.

-- CASE no months
-- INPUT
monthly_revenue
| month:date | revenue:int |
|------------|-------------|

-- EXPECTED
| month:text | revenue:int | sum_last_3_rows:numeric | sum_last_3_months:numeric |
|------------|-------------|-------------------------|---------------------------|

-- CASE across the new year, and a month far from the others
-- INPUT
monthly_revenue
| month      | revenue |
|------------|---------|
| 2023-11-01 | 10      |
| 2024-01-01 | 20      |
| 2024-02-01 | 40      |
| 2024-07-01 | 80      |

-- EXPECTED
| month   | revenue | sum_last_3_rows | sum_last_3_months |
|---------|---------|-----------------|-------------------|
| 2023-11 | 10      | 10              | 10                |
| 2024-01 | 20      | 30              | 30                |
| 2024-02 | 40      | 70              | 60                |
| 2024-07 | 80      | 140             | 80                |
