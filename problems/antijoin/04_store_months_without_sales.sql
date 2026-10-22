-- Problem antijoin/04: Store-months without a single sale  [Medium]
-- Pattern: Anti-join against a generated grid: stores CROSS JOIN months + NOT EXISTS (sale in that cell)
-- Variant: the "missing" rows are combinations that never existed in any table
--
-- Task: A tea-shop chain checks Q1 2024 (months 2024-01, 2024-02, 2024-03). For every store and
--   every one of these months in which the store has NO sale, return store_id, store_name and
--   month ('YYYY-MM'). Stores that never sold anything appear for all three months. Sales
--   outside Q1 2024 do not count. Sort by store_id, month.
-- Learn: grinding/sql-common-pitfalls.md, mục E1c

-- INPUT
stores
| store_id | store_name       |
|----------|------------------|
| 1        | Lotus District 1 |
| 2        | Lotus District 3 |
| 3        | Lotus Thu Duc    |

sales
| sale_id | store_id | sale_date  | amount_vnd |
|---------|----------|------------|------------|
| 1       | 1        | 2024-01-05 | 300000     |
| 2       | 1        | 2024-02-10 | 250000     |
| 3       | 1        | 2024-03-31 | 400000     |
| 4       | 2        | 2024-01-02 | 120000     |
| 5       | 2        | 2024-01-28 | 90000      |
| 6       | 2        | 2024-03-01 | 150000     |
| 7       | 2        | 2024-04-01 | 500000     |
| 8       | 3        | 2023-12-31 | 700000     |

-- EXPECTED
| store_id | store_name       | month   |
|----------|------------------|---------|
| 2        | Lotus District 3 | 2024-02 |
| 3        | Lotus Thu Duc    | 2024-01 |
| 3        | Lotus Thu Duc    | 2024-02 |
| 3        | Lotus Thu Duc    | 2024-03 |

-- QUERY
-- write your query here
