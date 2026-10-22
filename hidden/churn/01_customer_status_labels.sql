-- HIDDEN TESTS for problem churn/01. No QUERY section: the problem's QUERY is used.

-- CASE customers but no orders
-- INPUT
customers
| customer_id:int | full_name:text |
|-----------------|----------------|
| 1               | Anna           |

orders
| order_id:int | customer_id:int | order_date:date | status:text |
|--------------|-----------------|-----------------|-------------|

-- EXPECTED
| customer_id | full_name | last_order_date | days_inactive | status       |
|-------------|-----------|-----------------|---------------|--------------|
| 1           | Anna      | NULL            | NULL          | Never bought |

-- CASE boundaries 30/31 and 90/91 days, an order on the as-of date
-- INPUT
customers
| customer_id | full_name |
|-------------|-----------|
| 1           | A         |
| 2           | B         |
| 3           | C         |
| 4           | D         |
| 5           | E         |

orders
| order_id | customer_id | order_date | status    |
|----------|-------------|------------|-----------|
| 1        | 1           | 2024-12-01 | delivered |
| 2        | 2           | 2024-11-30 | delivered |
| 3        | 3           | 2024-10-02 | delivered |
| 4        | 4           | 2024-10-01 | delivered |
| 5        | 5           | 2024-12-31 | delivered |
| 6        | 5           | 2023-01-01 | delivered |

-- EXPECTED
| customer_id | full_name | last_order_date | days_inactive | status  |
|-------------|-----------|-----------------|---------------|---------|
| 1           | A         | 2024-12-01      | 30            | Active  |
| 2           | B         | 2024-11-30      | 31            | At risk |
| 3           | C         | 2024-10-02      | 90            | At risk |
| 4           | D         | 2024-10-01      | 91            | Lapsed  |
| 5           | E         | 2024-12-31      | 0             | Active  |

-- CASE a later cancelled or future order does not refresh the status
-- INPUT
customers
| customer_id | full_name |
|-------------|-----------|
| 1           | A         |
| 2           | B         |

orders
| order_id | customer_id | order_date | status    |
|----------|-------------|------------|-----------|
| 1        | 1           | 2024-01-10 | delivered |
| 2        | 1           | 2024-12-30 | cancelled |
| 3        | 2           | 2024-06-01 | delivered |
| 4        | 2           | 2025-01-01 | delivered |

-- EXPECTED
| customer_id | full_name | last_order_date | days_inactive | status |
|-------------|-----------|-----------------|---------------|--------|
| 1           | A         | 2024-01-10      | 356           | Lapsed |
| 2           | B         | 2024-06-01      | 213           | Lapsed |
