-- HIDDEN TESTS for problem func/04. No QUERY section: the problem's QUERY is used.

-- CASE customer without orders
-- INPUT
orders
| order_id:int | customer_id:int | status:text | amount:int |
|--------------|-----------------|-------------|------------|
| 1            | 2               | paid        | 10         |

-- EXPECTED
| variant:text | order_id:int | status:text | amount:int |
|--------------|--------------|-------------|------------|

-- CASE explicit NULL status means all, unknown status means none
-- INPUT
orders
| order_id:int | customer_id:int | status:text | amount:int |
|--------------|-----------------|-------------|------------|
| 1            | 7               | paid        | 10         |
| 2            | 7               | pending     | 20         |

-- EXPECTED
| variant | order_id | status  | amount |
|---------|----------|---------|--------|
| null    | 1        | paid    | 10     |
| null    | 2        | pending | 20     |

-- CALL
SELECT 'null' AS variant, * FROM customer_orders(7, NULL)
UNION ALL
SELECT 'cancelled', * FROM customer_orders(7, 'cancelled')
ORDER BY variant, order_id;
