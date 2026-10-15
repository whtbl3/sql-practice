-- Problem subquery/12: Orders more than double the customer's past average  [Hard]
-- Pattern: Correlated subquery over the customer's earlier rows (row comparison)
-- Variant: compare to own history
--
-- Task: An order is unusual if its amount is MORE than 2 x the average amount of the same customer's
--   earlier orders. Earlier = smaller order_date, or same order_date and smaller order_id. A first
--   order is never unusual. Return order_id, customer, amount, prev_avg (1 decimal). Sort by order_id.
-- Learn: grinding/sql-subquery-window.md, mục S2

-- INPUT
orders
| order_id | customer | order_date | amount |
|----------|----------|------------|--------|
| 1        | Ann      | 2024-01-01 | 100    |
| 2        | Ann      | 2024-01-05 | 120    |
| 3        | Ann      | 2024-01-10 | 500    |
| 4        | Ann      | 2024-01-20 | 200    |
| 5        | Bob      | 2024-01-02 | 50     |
| 6        | Bob      | 2024-01-03 | 100    |
| 7        | Bob      | 2024-01-04 | 160    |

-- EXPECTED
| order_id | customer | amount | prev_avg |
|----------|----------|--------|----------|
| 3        | Ann      | 500    | 110.0    |
| 7        | Bob      | 160    | 75.0     |

-- QUERY
-- write your query here
SELECT
  o1.order_id,
  o1.customer,
  o1.amount,
  s.prev_avg
FROM orders o1
  LEFT JOIN LATERAL (
    SELECT
      ROUND(AVG(amount), 1) AS prev_avg
    FROM orders o2
    WHERE o1.customer = o2.customer
      AND (
        o1.order_date > o2.order_date
        OR o1.order_id > o2.order_id
      )
  ) s ON TRUE
WHERE o1.amount > 2 * s.prev_avg