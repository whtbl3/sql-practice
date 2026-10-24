-- Problem subquery/02: Units sold per product and share of total  [Medium]
-- Pattern: Correlated scalar subquery in SELECT
-- Variant: subquery per row
--
-- Task: For every product (including never-ordered ones) return name, units_sold (total qty, 0 if
--   none) and pct_of_units = units_sold as % of all units sold, 1 decimal (NULL if nothing was
--   sold at all). Sort by units_sold DESC, name.
-- Learn: grinding/sql-subquery.md, D2

-- INPUT
products
| product_id | name |
|------------|------|
| 1          | Pen  |
| 2          | Mug  |
| 3          | Lamp |
| 4          | Desk |

order_items
| order_id | product_id | qty |
|----------|------------|-----|
| 1        | 1          | 3   |
| 1        | 2          | 1   |
| 2        | 1          | 2   |
| 3        | 3          | 4   |

-- EXPECTED
| name | units_sold | pct_of_units |
|------|------------|--------------|
| Pen  | 5          | 50.0         |
| Lamp | 4          | 40.0         |
| Mug  | 1          | 10.0         |
| Desk | 0          | 0.0          |

-- QUERY
-- write your query here
SELECT
  name,
  (
    SELECT
      COALESCE(SUM(qty), 0)
  FROM order_items
  WHERE products.product_id = order_items.product_id
  ) AS units_sold,
  ROUND(
    COALESCE(
      (SELECT SUM(qty) FROM order_items WHERE order_items.product_id = products.product_id), 0) * 100.0
    /
    NULLIF((SELECT SUM(qty) FROM order_items), 0)
  , 1) AS pct_of_units
FROM products
ORDER BY units_sold DESC, name ASC