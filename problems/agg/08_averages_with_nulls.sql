-- Problem agg/08: COUNT and AVG with NULL ratings  [Medium]
-- Pattern: COUNT(*) vs COUNT(col), AVG ignoring NULL vs COALESCE
-- Variant: NULL-aware aggregates
--
-- Task: Per product return total_rows (COUNT of all rows), rated_rows (rows with a rating),
--   avg_rating (average over rated rows only, 1 decimal, NULL if none) and avg_with_zeros (NULL
--   ratings treated as 0, 1 decimal). Sort by product.

-- INPUT
ratings
| product | rating |
|---------|--------|
| A       | 5      |
| A       | 4      |
| A       | NULL   |
| B       | NULL   |
| B       | NULL   |
| C       | 3      |
| C       | 3      |
| C       | 3      |

-- EXPECTED
| product | total_rows | rated_rows | avg_rating | avg_with_zeros |
|---------|------------|------------|------------|----------------|
| A       | 3          | 2          | 4.5        | 3.0            |
| B       | 2          | 0          | NULL       | 0.0            |
| C       | 3          | 3          | 3.0        | 3.0            |

-- QUERY
-- write your query here
SELECT
  product,
  COUNT(*) AS total_rows,
  COUNT(rating) AS rated_rows,
  ROUND(AVG(rating), 1) AS avg_rating,
  ROUND(AVG(COALESCE(rating, 0)), 1) AS avg_with_zeros
FROM ratings
GROUP BY product
ORDER BY product