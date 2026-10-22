-- HIDDEN TESTS for problem cohort/06. No QUERY section: the problem's QUERY is used.

-- CASE customers with no orders at all
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | An        |
| 2               | Binh      |

orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|

-- EXPECTED
| customer_id | recency_days:int | frequency | monetary | r_score | f_score | m_score | rfm_code |
|-------------|------------------|-----------|----------|---------|---------|---------|----------|
| 1           | NULL             | 0         | 0        | 1       | 1       | 1       | 111      |
| 2           | NULL             | 0         | 0        | 1       | 1       | 1       | 111      |

-- CASE boundaries 30/31 and 90/91 days, 1000 and 300 amounts
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | An        |
| 2               | Binh      |
| 3               | Chi       |
| 4               | Dung      |

orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-06-01      | 1000         | Completed   |
| 2            | 2               | 2024-05-31      | 999          | Completed   |
| 3            | 3               | 2024-04-02      | 300          | Completed   |
| 4            | 3               | 2024-03-01      | 0            | Completed   |
| 5            | 4               | 2024-04-01      | 299          | Completed   |

-- EXPECTED
| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score | rfm_code |
|-------------|--------------|-----------|----------|---------|---------|---------|----------|
| 1           | 30           | 1         | 1000     | 3       | 1       | 3       | 313      |
| 2           | 31           | 1         | 999      | 2       | 1       | 2       | 212      |
| 3           | 90           | 2         | 300      | 2       | 2       | 2       | 222      |
| 4           | 91           | 1         | 299      | 1       | 1       | 1       | 111      |

-- CASE an order on the as-of date itself does not count
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | An        |

orders
| order_id:int | customer_id:int | order_date:date | total_amount:int | status:text |
|--------------|-----------------|-----------------|------------------|-------------|
| 1            | 1               | 2024-07-01      | 5000         | Completed   |
| 2            | 1               | 2024-06-30      | 10           | Completed   |
| 3            | 1               | 2024-06-29      | 10           | Refunded    |

-- EXPECTED
| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score | rfm_code |
|-------------|--------------|-----------|----------|---------|---------|---------|----------|
| 1           | 1            | 1         | 10       | 3       | 1       | 1       | 311      |
