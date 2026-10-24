-- Problem intervals/02: Spread contract value across calendar years  [Medium]
-- Pattern: Intervals: LATERAL generate_series of years + clip with GREATEST / LEAST + share of days
-- Variant: one input row becomes one output row per year it touches
--
-- Task: An IT services company recognises revenue evenly per day. A contract runs from
--   start_date to end_date, both included. For every contract and every calendar year it
--   touches, return contract_id, year, days (contract days inside that year) and
--   allocated_vnd = value_vnd * days / total contract days, rounded to whole VND.
--   Sort by contract_id, year.
-- Learn: grinding/sql-intervals.md, V2

-- INPUT
contracts
| contract_id | customer      | start_date | end_date   | value_vnd |
|-------------|---------------|------------|------------|-----------|
| 1           | Starlight Co. | 2023-07-01 | 2024-06-30 | 36600000  |
| 2           | Harbor Co.    | 2024-03-01 | 2024-03-31 | 9000000   |
| 3           | Mekong Co.    | 2023-12-31 | 2025-01-01 | 3680000   |
| 4           | East Asia Co. | 2024-12-30 | 2025-01-01 | 1000000   |

-- EXPECTED
| contract_id | year | days | allocated_vnd |
|-------------|------|------|---------------|
| 1           | 2023 | 184  | 18400000      |
| 1           | 2024 | 182  | 18200000      |
| 2           | 2024 | 31   | 9000000       |
| 3           | 2023 | 1    | 10000         |
| 3           | 2024 | 366  | 3660000       |
| 3           | 2025 | 1    | 10000         |
| 4           | 2024 | 2    | 666667        |
| 4           | 2025 | 1    | 333333        |

-- QUERY
-- write your query here
