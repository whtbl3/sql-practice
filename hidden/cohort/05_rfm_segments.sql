-- HIDDEN TESTS for problem cohort/05. No QUERY section: the problem's QUERY is used.

-- CASE no completed orders
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-01-01      | 100              | Cancelled   |

-- EXPECTED
| customer_id:int | r_score:int | f_score:int | m_score:int | segment:text |
|-----------------|-------------|-------------|-------------|--------------|

-- CASE three customers, one per bucket
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-05-01      | 100              | Completed   |
| 2            | 1               | 2024-05-02      | 100              | Completed   |
| 3            | 1               | 2024-05-30      | 100              | Completed   |
| 4            | 2               | 2024-05-20      | 500              | Completed   |
| 5            | 2               | 2024-05-21      | 500              | Completed   |
| 6            | 3               | 2024-01-10      | 20               | Completed   |

-- EXPECTED
| customer_id | r_score | f_score | m_score | segment   |
|-------------|---------|---------|---------|-----------|
| 1           | 3       | 3       | 2       | Champions |
| 2           | 2       | 2       | 3       | Loyal     |
| 3           | 1       | 1       | 1       | Lost      |

-- CASE high frequency but long gone is At Risk, not Loyal
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-01-01      | 300              | Completed   |
| 2            | 1               | 2024-01-02      | 300              | Completed   |
| 3            | 1               | 2024-01-03      | 300              | Completed   |
| 4            | 2               | 2024-06-01      | 10               | Completed   |
| 5            | 3               | 2024-03-01      | 50               | Completed   |
| 6            | 3               | 2024-03-02      | 50               | Completed   |

-- EXPECTED
| customer_id | r_score | f_score | m_score | segment |
|-------------|---------|---------|---------|---------|
| 1           | 1       | 3       | 3       | At Risk |
| 2           | 3       | 1       | 1       | New     |
| 3           | 2       | 2       | 2       | Loyal   |
