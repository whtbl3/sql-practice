-- HIDDEN TESTS for problem func/03. No QUERY section: the problem's QUERY is used.

-- CASE n = 0 returns nothing
-- INPUT
orders
| order_id:int | customer_id:int | amount:int | status:text |
|--------------|-----------------|------------|-------------|
| 1            | 1               | 100        | paid        |

-- EXPECTED
| customer_id:int | total_spent:numeric |
|-----------------|---------------------|

-- CALL
SELECT * FROM top_customers(0);

-- CASE n larger than the number of customers
-- INPUT
orders
| order_id:int | customer_id:int | amount:int | status:text |
|--------------|-----------------|------------|-------------|
| 1            | 5               | 10         | paid        |
| 2            | 3               | 10         | paid        |
| 3            | 9               | 99         | refunded    |

-- EXPECTED
| customer_id | total_spent |
|-------------|-------------|
| 3           | 10          |
| 5           | 10          |

-- CALL
SELECT * FROM top_customers(10);

-- CASE only refunded orders
-- INPUT
orders
| order_id:int | customer_id:int | amount:int | status:text |
|--------------|-----------------|------------|-------------|
| 1            | 1               | 100        | refunded    |

-- EXPECTED
| customer_id:int | total_spent:numeric |
|-----------------|---------------------|

-- CALL
SELECT * FROM top_customers(3);
