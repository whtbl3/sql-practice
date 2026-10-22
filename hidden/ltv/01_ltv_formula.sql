-- HIDDEN TESTS for problem ltv/01. No QUERY section: the problem's QUERY is used.

-- CASE channels but no orders
-- INPUT
customers
| customer_id | channel |
|-------------|---------|
| 1           | Shopee  |

orders
| order_id:int | customer_id:int | order_date:date | amount_vnd:int | status:text |
|--------------|-----------------|-----------------|----------------|-------------|

channel_churn
| channel | annual_churn_rate |
|---------|-------------------|
| Shopee  | 0.40              |
| TikTok  | 0.10              |

-- EXPECTED
| channel | customers | orders | revenue | aov  | annual_frequency | lifespan_years | ltv  |
|---------|-----------|--------|---------|------|------------------|----------------|------|
| Shopee  | 0         | 0      | 0       | NULL | NULL             | 2.50           | NULL |
| TikTok  | 0         | 0      | 0       | NULL | NULL             | 10.00          | NULL |

-- CASE rounding happens at the end: aov 333333.33 x 1.5 x 3 = 1500000
-- INPUT
customers
| customer_id | channel |
|-------------|---------|
| 1           | A       |
| 2           | A       |

orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-01-01 | 100000     | delivered |
| 2        | 1           | 2024-12-31 | 400000     | delivered |
| 3        | 2           | 2024-06-01 | 500000     | delivered |
| 4        | 2           | 2025-01-01 | 800000     | delivered |

channel_churn
| channel | annual_churn_rate |
|---------|-------------------|
| A       | 0.3333333333      |

-- EXPECTED
| channel | customers | orders | revenue | aov    | annual_frequency | lifespan_years | ltv     |
|---------|-----------|--------|---------|--------|------------------|----------------|---------|
| A       | 2         | 3      | 1000000 | 333333 | 1.50             | 3.00           | 1500000 |
