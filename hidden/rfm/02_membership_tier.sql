-- HIDDEN TESTS for problem rfm/02. No QUERY section: the problem's QUERY is used.

-- CASE members but no orders or refunds at all
-- INPUT
customers
| customer_id:int | full_name:text |
|-----------------|----------------|
| 1               | Laura          |
| 2               | Nathan         |

orders
| order_id:int | customer_id:int | order_date:date | amount_vnd:int | status:text |
|--------------|-----------------|-----------------|----------------|-------------|

refunds
| refund_id:int | order_id:int | refund_vnd:int |
|---------------|--------------|----------------|

-- EXPECTED
| customer_id | full_name | orders_2024 | net_spend | tier     |
|-------------|-----------|-------------|-----------|----------|
| 1           | Laura     | 0           | 0         | Standard |
| 2           | Nathan    | 0           | 0         | Standard |

-- CASE exact thresholds: 10000000 with 5 orders, 3000000, and big spend with only 4 orders
-- INPUT
customers
| customer_id | full_name |
|-------------|-----------|
| 1           | Laura     |
| 2           | Nathan    |
| 3           | Quinn     |
| 4           | Tessa     |

orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-01-01 | 2000000    | delivered |
| 2        | 1           | 2024-02-01 | 2000000    | delivered |
| 3        | 1           | 2024-03-01 | 2000000    | delivered |
| 4        | 1           | 2024-04-01 | 2000000    | delivered |
| 5        | 1           | 2024-05-01 | 2000000    | delivered |
| 6        | 2           | 2024-06-01 | 3000000    | delivered |
| 7        | 3           | 2024-07-01 | 5000000    | delivered |
| 8        | 3           | 2024-07-02 | 5000000    | delivered |
| 9        | 3           | 2024-07-03 | 5000000    | delivered |
| 10       | 3           | 2024-07-04 | 5000000    | delivered |
| 11       | 4           | 2024-08-01 | 2999999    | delivered |

refunds
| refund_id:int | order_id:int | refund_vnd:int |
|---------------|--------------|----------------|

-- EXPECTED
| customer_id | full_name | orders_2024 | net_spend | tier     |
|-------------|-----------|-------------|-----------|----------|
| 3           | Quinn     | 4           | 20000000  | Gold     |
| 1           | Laura     | 5           | 10000000  | Diamond  |
| 2           | Nathan    | 1           | 3000000   | Gold     |
| 4           | Tessa     | 1           | 2999999   | Standard |

-- CASE three refunds on one order must not multiply the order amount or the order count
-- INPUT
customers
| customer_id | full_name |
|-------------|-----------|
| 1           | Laura     |

orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-03-01 | 6000000    | delivered |
| 2        | 1           | 2024-04-01 | 1000000    | delivered |
| 3        | 1           | 2024-05-01 | 1000000    | delivered |
| 4        | 1           | 2024-06-01 | 1000000    | delivered |
| 5        | 1           | 2024-07-01 | 1500000    | delivered |

refunds
| refund_id | order_id | refund_vnd |
|-----------|----------|------------|
| 1         | 1        | 100000     |
| 2         | 1        | 100000     |
| 3         | 1        | 100000     |

-- EXPECTED
| customer_id | full_name | orders_2024 | net_spend | tier    |
|-------------|-----------|-------------|-----------|---------|
| 1           | Laura     | 5           | 10200000  | Diamond |

-- CASE refunds on cancelled or out-of-window orders are ignored
-- INPUT
customers
| customer_id | full_name |
|-------------|-----------|
| 1           | Laura     |
| 2           | Nathan    |

orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-05-05 | 3500000    | delivered |
| 2        | 1           | 2024-05-06 | 900000     | cancelled |
| 3        | 2           | 2023-12-31 | 8000000    | delivered |
| 4        | 2           | 2024-01-01 | 3000000    | delivered |

refunds
| refund_id | order_id | refund_vnd |
|-----------|----------|------------|
| 1         | 2        | 900000     |
| 2         | 3        | 8000000    |
| 3         | 4        | 1          |

-- EXPECTED
| customer_id | full_name | orders_2024 | net_spend | tier     |
|-------------|-----------|-------------|-----------|----------|
| 1           | Laura     | 1           | 3500000   | Gold     |
| 2           | Nathan    | 1           | 2999999   | Standard |
