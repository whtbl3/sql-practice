-- HIDDEN TESTS for problem gaps/05. No QUERY section: the problem's QUERY is used.

-- CASE customers but no orders
-- INPUT
customers
| customer_id | channel  |
|-------------|----------|
| 1           | Facebook |
| 2           | Shopee   |

orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|

-- EXPECTED
| channel  | buyers | returned | return_rate_pct | avg_days | median_days |
|----------|--------|----------|-----------------|----------|-------------|
| Facebook | 0      | 0        | NULL            | NULL     | NULL        |
| Shopee   | 0      | 0        | NULL            | NULL     | NULL        |

-- CASE only the 2nd day counts, not the 3rd; odd count median
-- INPUT
customers
| customer_id | channel |
|-------------|---------|
| 1           | Zalo    |
| 2           | Zalo    |
| 3           | Zalo    |

orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-01 |
| 3        | 1           | 2024-01-02 |
| 4        | 1           | 2024-06-01 |
| 5        | 2           | 2024-01-01 |
| 6        | 2           | 2024-01-08 |
| 7        | 3           | 2024-01-01 |
| 8        | 3           | 2024-01-31 |

-- EXPECTED
| channel | buyers | returned | return_rate_pct | avg_days | median_days |
|---------|--------|----------|-----------------|----------|-------------|
| Zalo    | 3      | 3        | 100.0           | 12.7     | 7.0         |

-- CASE buyers that never returned keep the rate down but not the averages
-- INPUT
customers
| customer_id | channel |
|-------------|---------|
| 1           | Zalo    |
| 2           | Zalo    |
| 3           | Zalo    |
| 4           | Zalo    |

orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-05 |
| 3        | 2           | 2024-01-01 |
| 4        | 3           | 2024-01-01 |
| 5        | 4           | 2024-01-01 |

-- EXPECTED
| channel | buyers | returned | return_rate_pct | avg_days | median_days |
|---------|--------|----------|-----------------|----------|-------------|
| Zalo    | 4      | 1        | 25.0            | 4.0      | 4.0         |
