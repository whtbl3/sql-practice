-- Problem median/01: Mean vs median price by category  [Easy]
-- Pattern: Median: AVG + PERCENTILE_CONT + PERCENTILE_DISC in one GROUP BY, CASE on their ratio
-- Variant: use the median to describe the SHAPE of the data, not only to report one number
--
-- Task: An electronics shop compares average and typical prices. Products with a NULL price are
--   ignored everywhere. For every category with at least one priced product return category,
--   products (number of priced products), avg_price, median_price (PERCENTILE_CONT: average of
--   the two middle prices when the count is even), median_disc (PERCENTILE_DISC: the lower of
--   the two middle prices) - avg_price and median_price rounded to whole VND - and shape:
--     'right-skewed'  avg > 1.2 * median     (a few very expensive products pull the mean up)
--     'left-skewed'  avg < 0.8 * median
--     'balanced'    otherwise
--   using the unrounded values. Sort by category.
-- Learn: grinding/sql-median.md, phần mở đầu

-- INPUT
products
| product_id | category    | price_vnd |
|------------|-------------|-----------|
| 1          | Phones      | 3000000   |
| 2          | Phones      | 30000000  |
| 3          | Phones      | 5000000   |
| 4          | Phones      | 4000000   |
| 5          | Headphones  | 200000    |
| 6          | Headphones  | 300000    |
| 7          | Headphones  | 400000    |
| 8          | Power banks | 20000     |
| 9          | Power banks | 400000    |
| 10         | Power banks | 600000    |
| 11         | Power banks | 620000    |
| 12         | Power banks | 640000    |
| 13         | Phone cases | 50000     |
| 14         | Phone cases | NULL      |
| 15         | Phone cases | 70000     |
| 16         | Cables      | NULL      |

-- EXPECTED
| category    | products | avg_price | median_price | median_disc | shape        |
|-------------|----------|-----------|--------------|-------------|--------------|
| Headphones  | 3        | 300000    | 300000       | 300000      | balanced     |
| Phone cases | 2        | 60000     | 60000        | 50000       | balanced     |
| Phones      | 4        | 10500000  | 4500000      | 4000000     | right-skewed |
| Power banks | 5        | 456000    | 600000       | 600000      | left-skewed  |

-- QUERY
WITH stats AS (
  SELECT category,
         COUNT(price_vnd)                                            AS products,     -- skips NULL
         AVG(price_vnd)                                              AS avg_price,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_vnd)::numeric AS median_price,
         PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price_vnd)      AS median_disc   -- a real value
  FROM products
  WHERE price_vnd IS NOT NULL                       -- also drops a category with only NULL prices
  GROUP BY category
)
SELECT category, products,
       ROUND(avg_price)    AS avg_price,
       ROUND(median_price) AS median_price,
       median_disc,
       CASE
         WHEN avg_price > 1.2 * median_price THEN 'right-skewed'
         WHEN avg_price < 0.8 * median_price THEN 'left-skewed'
         ELSE 'balanced'
       END AS shape
FROM stats
ORDER BY category;
