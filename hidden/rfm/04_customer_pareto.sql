-- HIDDEN TESTS for problem rfm/04. No QUERY section: the problem's QUERY is used.

-- CASE no delivered orders still returns one row
-- INPUT
orders
| order_id:int | customer_id:int | amount_vnd:int | status:text |
|--------------|-----------------|----------------|-------------|
| 1            | 1               | 500000         | cancelled   |

-- EXPECTED
| total_customers | top_customers | top_customers_pct | top_revenue_pct |
|-----------------|---------------|-------------------|-----------------|
| 0               | 0             | NULL              | NULL            |

-- CASE a single customer
-- INPUT
orders
| order_id | customer_id | amount_vnd | status    |
|----------|-------------|------------|-----------|
| 1        | 5           | 700000     | delivered |
| 2        | 5           | 300000     | delivered |

-- EXPECTED
| total_customers | top_customers | top_customers_pct | top_revenue_pct |
|-----------------|---------------|-------------------|-----------------|
| 1               | 1             | 100.0             | 100.0           |

-- CASE everybody has the same revenue: all of them are in the top group
-- INPUT
orders
| order_id | customer_id | amount_vnd | status    |
|----------|-------------|------------|-----------|
| 1        | 1           | 2500000    | delivered |
| 2        | 2           | 2500000    | delivered |
| 3        | 3           | 2500000    | delivered |
| 4        | 4           | 2500000    | delivered |

-- EXPECTED
| total_customers | top_customers | top_customers_pct | top_revenue_pct |
|-----------------|---------------|-------------------|-----------------|
| 4               | 4             | 100.0             | 100.0           |

-- CASE richer customers reach exactly 80%: the next customer is NOT in the top group
-- INPUT
orders
| order_id | customer_id | amount_vnd | status    |
|----------|-------------|------------|-----------|
| 1        | 1           | 5000000    | delivered |
| 2        | 2           | 3000000    | delivered |
| 3        | 3           | 2000000    | delivered |

-- EXPECTED
| total_customers | top_customers | top_customers_pct | top_revenue_pct |
|-----------------|---------------|-------------------|-----------------|
| 3               | 2             | 66.7              | 80.0            |

-- CASE a tie that straddles 80%: a running sum ordered by customer_id would drop the second one
-- INPUT
orders
| order_id | customer_id | amount_vnd | status    |
|----------|-------------|------------|-----------|
| 1        | 9           | 4000000    | delivered |
| 2        | 8           | 3500000    | delivered |
| 3        | 1           | 1000000    | delivered |
| 4        | 2           | 1000000    | delivered |
| 5        | 3           | 500000     | delivered |

-- EXPECTED
| total_customers | top_customers | top_customers_pct | top_revenue_pct |
|-----------------|---------------|-------------------|-----------------|
| 5               | 4             | 80.0              | 95.0            |
