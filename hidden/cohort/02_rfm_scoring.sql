-- HIDDEN TESTS for problem cohort/02. No QUERY section: the problem's QUERY is used.

-- CASE all orders cancelled
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-01-01      | 100              | Cancelled   |

-- EXPECTED
| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score |
|-------------|--------------|-----------|----------|---------|---------|---------|

-- CASE single customer
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-05-10      | 100              | Completed   |

-- EXPECTED
| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score |
|-------------|--------------|-----------|----------|---------|---------|---------|
| 1           | 1            | 1         | 100      | 1       | 1       | 1       |

-- CASE equal values, uneven bucket sizes
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-05-10      | 100              | Completed   |
| 2            | 2               | 2024-05-10      | 100              | Completed   |
| 3            | 3               | 2024-05-10      | 100              | Completed   |
| 4            | 4               | 2024-05-10      | 100              | Completed   |

-- EXPECTED
| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score |
|-------------|--------------|-----------|----------|---------|---------|---------|
| 1           | 1            | 1         | 100      | 1       | 1       | 1       |
| 2           | 1            | 1         | 100      | 1       | 1       | 1       |
| 3           | 1            | 1         | 100      | 2       | 2       | 2       |
| 4           | 1            | 1         | 100      | 3       | 3       | 3       |

-- CASE newer cancelled order does not change the as-of date
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-01-10      | 100              | Completed   |
| 2            | 1               | 2024-03-01      | 999              | Cancelled   |
| 3            | 2               | 2024-01-05      | 50               | Completed   |

-- EXPECTED
| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score |
|-------------|--------------|-----------|----------|---------|---------|---------|
| 1           | 1            | 1         | 100      | 2       | 1       | 2       |
| 2           | 6            | 1         | 50       | 1       | 2       | 1       |
