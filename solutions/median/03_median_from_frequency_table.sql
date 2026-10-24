-- Problem median/03: Median basket size from a frequency table  [Hard]
-- Pattern: Median: running SUM(freq) OVER -> each value covers positions (cum - freq + 1 .. cum) -> pick the middle
-- Variant: data already aggregated as (value, count); expanding it to one row per order is forbidden
-- @forbid: \bgenerate_series\b|\bunnest\b|\bRECURSIVE\b
--
-- Task: A milk-tea chain stores, for each store, how many orders contained 1, 2, 3, ... items
--   (basket_sizes: items, orders; orders may be 0; rows are not sorted). For every store with at
--   least one order return store, total_orders and median_items = the median number of items
--   per order (if all orders were listed one by one: the middle one, or the average of the two
--   middle ones when total_orders is even), rounded to 1 decimal. Do not expand the table into
--   one row per order (generate_series, unnest and recursive CTEs are not allowed).
--   Sort by store.
-- Learn: grinding/sql-median.md, V2

-- INPUT
basket_sizes
| store      | items | orders |
|------------|-------|--------|
| District 1 | 3     | 1      |
| District 1 | 1     | 5      |
| District 1 | 4     | 1      |
| District 1 | 2     | 3      |
| Thu Duc    | 1     | 2      |
| Thu Duc    | 2     | 2      |
| Thu Duc    | 3     | 3      |
| Thu Duc    | 5     | 0      |
| Thu Duc    | 6     | 2      |
| Binh Thanh | 2     | 4      |
| Go Vap     | 1     | 0      |

-- EXPECTED
| store      | total_orders | median_items |
|------------|--------------|--------------|
| Binh Thanh | 4            | 2.0          |
| District 1 | 10           | 1.5          |
| Thu Duc    | 9            | 3.0          |

-- QUERY
WITH cum AS (
  SELECT store, items, orders,
         -- SUM(bigint) returns numeric: cast back, or (total + 1) / 2 below is 5.5 instead of 5
         SUM(orders) OVER (PARTITION BY store ORDER BY items)::bigint AS cum_to,   -- last position this value covers
         SUM(orders) OVER (PARTITION BY store)::bigint                AS total
  FROM basket_sizes
),
middle AS (                                         -- rows whose position range holds a middle position
  SELECT store, items, total
  FROM cum
  WHERE (total + 1) / 2 BETWEEN cum_to - orders + 1 AND cum_to      -- lower middle position
     OR (total + 2) / 2 BETWEEN cum_to - orders + 1 AND cum_to      -- upper middle position
)
SELECT store,
       MAX(total)           AS total_orders,
       ROUND(AVG(items), 1) AS median_items          -- 1 row: that value; 2 rows: their average
FROM middle
GROUP BY store
ORDER BY store;
