-- Problem misc/07: Price in effect on the order date (as-of join)  [Medium]
-- Pattern: As-of join: LEFT JOIN LATERAL (... valid_from <= order_date ORDER BY valid_from DESC LIMIT 1)
-- Variant: price history with only a start date; the price holds until the next change
--
-- Task: A coffee roaster changes prices from time to time. price_history has one row per change:
--   from valid_from (included) the product costs price_vnd, until the next change for the same
--   product. For every order line return order_id, product_id, order_date, unit_price (the price
--   in effect on order_date; NULL if the product had no price yet) and line_total = unit_price *
--   qty. Sort by order_id, product_id.
-- Learn: grinding/sql-intervals.md, B1–B2

-- INPUT
price_history
| product_id | valid_from | price_vnd |
|------------|------------|-----------|
| 1          | 2024-03-01 | 55000     |
| 1          | 2024-01-01 | 50000     |
| 1          | 2024-06-15 | 60000     |
| 2          | 2024-02-01 | 30000     |

order_lines
| order_id | order_date | product_id | qty |
|----------|------------|------------|-----|
| 1        | 2024-01-15 | 1          | 2   |
| 2        | 2024-03-01 | 1          | 1   |
| 2        | 2024-03-01 | 2          | 3   |
| 3        | 2024-06-14 | 1          | 1   |
| 4        | 2024-06-15 | 1          | 2   |
| 5        | 2024-01-20 | 2          | 1   |

-- EXPECTED
| order_id | product_id | order_date | unit_price | line_total |
|----------|------------|------------|------------|------------|
| 1        | 1          | 2024-01-15 | 50000      | 100000     |
| 2        | 1          | 2024-03-01 | 55000      | 55000      |
| 2        | 2          | 2024-03-01 | 30000      | 90000      |
| 3        | 1          | 2024-06-14 | 55000      | 55000      |
| 4        | 1          | 2024-06-15 | 60000      | 120000     |
| 5        | 2          | 2024-01-20 | NULL       | NULL       |

-- QUERY
SELECT o.order_id, o.product_id, o.order_date,
       p.price_vnd           AS unit_price,
       p.price_vnd * o.qty   AS line_total
FROM order_lines o
LEFT JOIN LATERAL (                                 -- the latest change on or before the order date
  SELECT ph.price_vnd
  FROM price_history ph
  WHERE ph.product_id = o.product_id
    AND ph.valid_from <= o.order_date
  ORDER BY ph.valid_from DESC
  LIMIT 1
) p ON TRUE                                         -- LEFT: keep lines with no price yet
ORDER BY o.order_id, o.product_id;
