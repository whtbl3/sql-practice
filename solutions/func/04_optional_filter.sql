-- Problem func/04: Orders of a customer with an optional filter (DEFAULT parameter)  [Medium]
-- Pattern: Table function with a DEFAULT parameter, named notation (=>)
-- Variant: "NULL means no filter": (p IS NULL OR col = p)
--
-- Task: Create customer_orders(p_customer_id INT, p_status TEXT DEFAULT NULL)
--   RETURNS TABLE (order_id INT, status TEXT, amount INT) returning the orders of that customer,
--   sorted by order_id. When p_status is NULL (or omitted) return every status, otherwise only that
--   status.
-- Learn: grinding/sql-function.md, V3

-- INPUT
orders
| order_id:int | customer_id:int | status:text | amount:int |
|--------------|-----------------|-------------|------------|
| 1            | 1               | paid        | 100        |
| 2            | 1               | refunded    | 50         |
| 3            | 2               | paid        | 70         |
| 4            | 1               | paid        | 30         |
| 5            | 1               | pending     | 20         |

-- EXPECTED
| variant | order_id | status   | amount |
|---------|----------|----------|--------|
| all     | 1        | paid     | 100    |
| all     | 2        | refunded | 50     |
| all     | 4        | paid     | 30     |
| all     | 5        | pending  | 20     |
| paid    | 1        | paid     | 100    |
| paid    | 4        | paid     | 30     |

-- CALL
SELECT 'all' AS variant, * FROM customer_orders(1)
UNION ALL
SELECT 'paid', * FROM customer_orders(1, p_status => 'paid')
ORDER BY variant, order_id;

-- QUERY
CREATE FUNCTION customer_orders(p_customer_id INT, p_status TEXT DEFAULT NULL)
RETURNS TABLE (order_id INT, status TEXT, amount INT)
LANGUAGE sql
STABLE
AS $$
  SELECT o.order_id, o.status, o.amount
  FROM orders o
  WHERE o.customer_id = p_customer_id
    AND (p_status IS NULL OR o.status = p_status)
  ORDER BY o.order_id
$$;
