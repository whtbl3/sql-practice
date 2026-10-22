-- Problem rfm/04: What share of customers brings 80% of revenue  [Hard]
-- Pattern: Pareto: SUM() OVER (ORDER BY ... EXCLUDE GROUP) + conditional aggregation to one row
-- Variant: customers instead of products (window/11), one summary row, tied customers stay together
--
-- Task: An online cosmetics shop wants to check the 80/20 rule. revenue per customer = sum of
--   amount_vnd of their 'delivered' orders; only customers with at least one delivered order
--   exist for this problem. A customer is in the top group when the total revenue of all
--   customers with a STRICTLY HIGHER revenue is below 80% of total revenue (so customers with
--   equal revenue are either all in or all out). Return ONE row: total_customers,
--   top_customers, top_customers_pct = top_customers / total_customers * 100 and
--   top_revenue_pct = revenue of the top group / total revenue * 100, both rounded to 1
--   decimal. With no delivered orders return 0, 0, NULL, NULL.
-- Learn: grinding/sql-analytics-patterns.md, mục 2.11

-- INPUT
orders
| order_id | customer_id | amount_vnd | status    |
|----------|-------------|------------|-----------|
| 1        | 11          | 25000000   | delivered |
| 2        | 11          | 15000000   | delivered |
| 3        | 12          | 35000000   | delivered |
| 4        | 13          | 10000000   | delivered |
| 5        | 14          | 6000000    | delivered |
| 6        | 14          | 4000000    | delivered |
| 7        | 15          | 2000000    | delivered |
| 8        | 16          | 1000000    | delivered |
| 9        | 17          | 1000000    | delivered |
| 10       | 18          | 1000000    | delivered |
| 11       | 18          | 30000000   | cancelled |
| 12       | 19          | 500000     | returned  |

-- EXPECTED
| total_customers | top_customers | top_customers_pct | top_revenue_pct |
|-----------------|---------------|-------------------|-----------------|
| 8               | 4             | 50.0              | 95.0            |

-- QUERY
WITH revenue AS (
  SELECT customer_id, SUM(amount_vnd) AS revenue
  FROM orders
  WHERE status = 'delivered'
  GROUP BY customer_id
),
ranked AS (
  SELECT revenue,
         -- revenue of strictly richer customers: the default RANGE frame minus the current peer group
         COALESCE(SUM(revenue) OVER (ORDER BY revenue DESC
                                     RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                     EXCLUDE GROUP), 0) AS higher_revenue,
         SUM(revenue) OVER () AS total_revenue
  FROM revenue
)
SELECT COUNT(*) AS total_customers,
       COUNT(*) FILTER (WHERE higher_revenue < 0.8 * total_revenue) AS top_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE higher_revenue < 0.8 * total_revenue)
             / NULLIF(COUNT(*), 0), 1) AS top_customers_pct,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE higher_revenue < 0.8 * total_revenue)
             / NULLIF(SUM(revenue), 0), 1) AS top_revenue_pct
FROM ranked;                                        -- aggregate without GROUP BY: always one row
