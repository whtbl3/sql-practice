-- Problem window/11: Products that make up 80% of revenue  [Hard]
-- Pattern: Running SUM / total SUM OVER () (Pareto analysis)
-- Variant: cumulative share
--
-- Task: Order products by revenue DESC (ties by product). cumulative_pct = running revenue up to and
--   including the product, as % of total revenue (1 decimal). Return the products needed to reach
--   80%: every product whose cumulative share BEFORE adding it is below 80. Sort by revenue DESC,
--   product.
-- Learn: grinding/sql-window.md, B3

-- INPUT
product_sales
| product | revenue |
|---------|---------|
| A       | 500     |
| B       | 300     |
| C       | 100     |
| D       | 60      |
| E       | 40      |

-- EXPECTED
| product | revenue | cumulative_pct |
|---------|---------|----------------|
| A       | 500     | 50.0           |
| B       | 300     | 80.0           |

-- QUERY
-- write your query here
