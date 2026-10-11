-- Problem pivot/01: Quarterly revenue pivot  [Medium]
-- Pattern: Pivot with conditional aggregation (FILTER / CASE)
-- Variant: core: rows to columns
--
-- Task: For each product, compute the total revenue per quarter of 2024 as four columns q1..q4 (0
--   for a quarter with no revenue). Sort by product.

-- INPUT
sales
| product | sale_date  | amount |
|---------|------------|--------|
| A       | 2024-01-10 | 100    |
| A       | 2024-02-15 | 50     |
| A       | 2024-04-20 | 200    |
| B       | 2024-03-05 | 80     |
| B       | 2024-07-01 | 300    |
| B       | 2024-10-12 | 40     |

-- EXPECTED
| product | q1  | q2  | q3  | q4 |
|---------|-----|-----|-----|----|
| A       | 150 | 200 | 0   | 0  |
| B       | 80  | 0   | 300 | 40 |

-- QUERY
SELECT product,
       COALESCE(SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM sale_date) = 1), 0) AS q1,
       COALESCE(SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM sale_date) = 2), 0) AS q2,
       COALESCE(SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM sale_date) = 3), 0) AS q3,
       COALESCE(SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM sale_date) = 4), 0) AS q4
FROM sales
WHERE EXTRACT(YEAR FROM sale_date) = 2024
GROUP BY product
ORDER BY product;
