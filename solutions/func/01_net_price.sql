-- Problem func/01: Net price function (LANGUAGE sql)  [Easy]
-- Pattern: Scalar SQL function
-- Variant: NULL handling inside a function (COALESCE vs STRICT)
--
-- Task: Create a function net_price(p_price NUMERIC, p_discount_pct INT) RETURNS NUMERIC that returns
--   the price after the percentage discount, rounded to 2 decimals. A NULL discount means no
--   discount; a NULL price gives NULL. The -- CALL section below uses your function.
-- Learn: grinding/sql-function.md, B1–B3

-- INPUT
products
| product_id:int | price:numeric | discount_pct:int |
|----------------|---------------|------------------|
| 1              | 100.00        | 10               |
| 2              | 59.99         | NULL             |
| 3              | 20.00         | 25               |
| 4              | 9.99          | 33               |

-- EXPECTED
| product_id | net   |
|------------|-------|
| 1          | 90.00 |
| 2          | 59.99 |
| 3          | 15.00 |
| 4          | 6.69  |

-- CALL
SELECT product_id, net_price(price, discount_pct) AS net FROM products ORDER BY product_id;

-- QUERY
CREATE FUNCTION net_price(p_price NUMERIC, p_discount_pct INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ROUND(p_price * (100 - COALESCE(p_discount_pct, 0)) / 100, 2)
$$;
