-- Problem subquery/09: Categories above the average category revenue  [Medium]
-- Pattern: HAVING with a subquery over a derived table
-- Variant: compare a group to the average of groups
--
-- Task: Return the categories whose total revenue is above the average TOTAL revenue of a category.
--   Sort by revenue DESC, category.
-- Learn: grinding/sql-subquery.md, V6

-- INPUT
sales
| category | amount |
|----------|--------|
| A        | 100    |
| A        | 200    |
| B        | 50     |
| C        | 400    |
| D        | 250    |

-- EXPECTED
| category | revenue |
|----------|---------|
| C        | 400     |
| A        | 300     |

-- QUERY
-- write your query here
SELECT
  category,
  SUM(amount) AS revenue
FROM sales
GROUP BY category
HAVING SUM(amount) > (
  SELECT
    AVG(total_amount)
  FROM (
    SELECT SUM(amount) AS total_amount
    FROM sales
    GROUP BY category
  )
)
ORDER BY revenue DESC, category ASC