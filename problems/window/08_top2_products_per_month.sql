-- Problem window/08: Top 2 products per month  [Medium]
-- Pattern: Window over GROUP BY result, then filter in an outer query
-- Variant: rank aggregated groups
--
-- Task: Total qty per month ('YYYY-MM') and product, ranked within the month by total_qty DESC with
--   DENSE_RANK. Return only rank 1 and 2: month, product, total_qty, rank_in_month. Sort by month,
--   rank_in_month, product.
-- Learn: grinding/sql-subquery-window.md, mục W7

-- INPUT
sales
| sale_date  | product | qty |
|------------|---------|-----|
| 2024-01-03 | A       | 5   |
| 2024-01-20 | A       | 5   |
| 2024-01-05 | B       | 8   |
| 2024-01-07 | C       | 10  |
| 2024-02-01 | A       | 3   |
| 2024-02-02 | B       | 4   |
| 2024-02-10 | B       | 3   |
| 2024-02-11 | C       | 1   |

-- EXPECTED
| month   | product | total_qty | rank_in_month |
|---------|---------|-----------|---------------|
| 2024-01 | A       | 10        | 1             |
| 2024-01 | C       | 10        | 1             |
| 2024-01 | B       | 8         | 2             |
| 2024-02 | B       | 7         | 1             |
| 2024-02 | A       | 3         | 2             |

-- QUERY
-- write your query here
