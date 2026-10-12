-- Problem agg/03: Book count and price stats per genre  [Medium]
-- Pattern: LEFT JOIN + aggregates + COALESCE (groups with no rows)
-- Variant: LEFT JOIN aggregate
--
-- Task: For every genre (including genres without books) return book_count, avg_price rounded to 1
--   decimal (0.0 if no priced books) and price_range = max price - min price (0 if none). Books with
--   a NULL price still count in book_count. Sort by genre.

-- INPUT
genres
| genre_id | name    |
|----------|---------|
| 1        | Fantasy |
| 2        | History |
| 3        | Poetry  |

books
| book_id | genre_id | price |
|---------|----------|-------|
| 1       | 1        | 10    |
| 2       | 1        | 20    |
| 3       | 1        | 15    |
| 4       | 2        | 30    |
| 5       | 2        | 30    |

-- EXPECTED
| genre   | book_count | avg_price | price_range |
|---------|------------|-----------|-------------|
| Fantasy | 3          | 15.0      | 10          |
| History | 2          | 30.0      | 0           |
| Poetry  | 0          | 0.0       | 0           |

-- QUERY
SELECT g.name AS genre,
       COUNT(b.book_id) AS book_count,
       COALESCE(ROUND(AVG(b.price), 1), 0.0) AS avg_price,
       COALESCE(MAX(b.price) - MIN(b.price), 0) AS price_range
FROM genres g
LEFT JOIN books b ON b.genre_id = g.genre_id
GROUP BY g.genre_id, g.name
ORDER BY g.name;
