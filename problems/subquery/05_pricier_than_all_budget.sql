-- Problem subquery/05: Pricier than every Budget product  [Medium]
-- Pattern: > ALL (subquery), and how ALL behaves with an empty set and NULLs
-- Variant: quantified comparison
--
-- Task: Return non-'Budget' products whose price is higher than the price of EVERY 'Budget' product.
--   Ignore NULL prices (on both sides). If there are no Budget products, every non-Budget product
--   with a price qualifies. Sort by price DESC, name.
-- Learn: grinding/sql-subquery-window.md, mục S5

-- INPUT
products
| name | category | price |
|------|----------|-------|
| B1   | Budget   | 10    |
| B2   | Budget   | 25    |
| P1   | Pro      | 30    |
| P2   | Pro      | 25    |
| P3   | Lux      | 50    |
| P4   | Pro      | 20    |

-- EXPECTED
| name | price |
|------|-------|
| P3   | 50    |
| P1   | 30    |

-- QUERY
-- write your query here
