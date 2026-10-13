-- Problem window/06: Spending quartiles and percent rank  [Medium]
-- Pattern: NTILE and PERCENT_RANK
-- Variant: distribution functions
--
-- Task: Return customer, total_spent, quartile = NTILE(4) by total_spent DESC (ties broken by
--   customer, 1 = top spenders) and pct_rank = PERCENT_RANK by total_spent DESC, rounded to 2
--   decimals. Sort by total_spent DESC, customer.
-- Learn: grinding/sql-subquery-window.md, mục W6

-- INPUT
customer_spend
| customer | total_spent |
|----------|-------------|
| A        | 500         |
| B        | 400         |
| C        | 400         |
| D        | 300         |
| E        | 200         |
| F        | 100         |

-- EXPECTED
| customer | total_spent | quartile | pct_rank |
|----------|-------------|----------|----------|
| A        | 500         | 1        | 0.00     |
| B        | 400         | 1        | 0.20     |
| C        | 400         | 2        | 0.20     |
| D        | 300         | 2        | 0.60     |
| E        | 200         | 3        | 0.80     |
| F        | 100         | 4        | 1.00     |

-- QUERY
-- write your query here
