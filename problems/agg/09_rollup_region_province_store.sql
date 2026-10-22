-- Problem agg/09: Sales report with subtotals: region > province > store  [Hard]
-- Pattern: GROUP BY ROLLUP + GROUPING() to label subtotal rows and to sort them after their details
-- Variant: a real NULL store must not be mistaken for a subtotal row
--
-- Task: A bakery chain wants one report with every level of subtotal. Return region, province,
--   store, revenue_vnd and level, where the rows are:
--     one row per (region, province, store)  level 'Store'   (a NULL store shows '(unknown)')
--     one row per (region, province)         level 'Province'       store = 'Province total'
--     one row per region                     level 'Region'       province = 'Region total', store = ''
--     one grand total row                    level 'Country'  region = 'Grand total', province = '', store = ''
--   Sort: regions, then provinces inside a region, then stores inside a province (by name, the
--   unknown store last); each subtotal comes right after the rows it sums; the grand total is last.
-- Learn: grinding/sql-common-pitfalls.md, mục D3

-- INPUT
sales
| sale_id | region | province         | store | revenue_vnd |
|---------|--------|------------------|-------|-------------|
| 1       | North  | Hanoi            | HN-01 | 60          |
| 2       | North  | Hanoi            | HN-01 | 40          |
| 3       | North  | Hanoi            | HN-02 | 150         |
| 4       | North  | Hai Phong        | HP-01 | 80          |
| 5       | South  | Ho Chi Minh City | Q1    | 200         |
| 6       | South  | Ho Chi Minh City | NULL  | 30          |
| 7       | South  | Can Tho          | CT-01 | 50          |

-- EXPECTED
| region      | province         | store          | revenue_vnd | level    |
|-------------|------------------|----------------|-------------|----------|
| North       | Hai Phong        | HP-01          | 80          | Store    |
| North       | Hai Phong        | Province total | 80          | Province |
| North       | Hanoi            | HN-01          | 100         | Store    |
| North       | Hanoi            | HN-02          | 150         | Store    |
| North       | Hanoi            | Province total | 250         | Province |
| North       | Region total     |                | 330         | Region   |
| South       | Can Tho          | CT-01          | 50          | Store    |
| South       | Can Tho          | Province total | 50          | Province |
| South       | Ho Chi Minh City | Q1             | 200         | Store    |
| South       | Ho Chi Minh City | (unknown)      | 30          | Store    |
| South       | Ho Chi Minh City | Province total | 230         | Province |
| South       | Region total     |                | 280         | Region   |
| Grand total |                  |                | 610         | Country  |

-- QUERY
-- write your query here
