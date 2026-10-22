-- Problem func/03: Top N customers (RETURNS TABLE)  [Medium]
-- Pattern: Table function: RETURNS TABLE + RETURN QUERY with a parameter
-- Variant: name clash between output columns and table columns; result type must match exactly
--
-- Task: Create top_customers(p_n INT) RETURNS TABLE (customer_id INT, total_spent NUMERIC) returning
--   the p_n customers with the highest total amount of 'paid' orders, highest first, ties broken by
--   customer_id ascending. Customers without paid orders are not returned.
-- Learn: grinding/sql-functions-procedures.md, mục 4

-- INPUT
orders
| order_id:int | customer_id:int | amount:int | status:text |
|--------------|-----------------|------------|-------------|
| 1            | 1               | 100        | paid        |
| 2            | 1               | 50         | paid        |
| 3            | 2               | 200        | paid        |
| 4            | 3               | 120        | paid        |
| 5            | 3               | 30         | refunded    |
| 6            | 4               | 150        | paid        |
| 7            | 2               | 10         | refunded    |

-- EXPECTED
| customer_id | total_spent |
|-------------|-------------|
| 2           | 200         |
| 1           | 150         |
| 4           | 150         |

-- CALL
SELECT * FROM top_customers(3);

-- QUERY
-- write your query here
