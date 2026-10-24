-- Problem ltv/01: LTV = AOV x purchase frequency x lifespan, per channel  [Medium]
-- Pattern: LTV: ratio of sums (not average of ratios) + LEFT JOIN from the channel list + NULLIF
-- Variant: the classic formula, with a churn rate table giving the lifespan
--
-- Task: A cosmetics brand estimates customer lifetime value per acquisition channel from its
--   2024 data. Only 'delivered' orders placed in 2024 count. For EVERY channel in channel_churn:
--     customers        = customers of the channel with at least one counted order
--     orders, revenue  = counted orders and their total amount_vnd (0 if none)
--     aov              = revenue / orders                         (average order value)
--     annual_frequency = orders / customers                       (orders per customer per year)
--     lifespan_years   = 1 / annual_churn_rate                    (NULL when the rate is 0)
--     ltv              = aov * annual_frequency * lifespan_years
--   Compute ltv from the unrounded values, then round aov and ltv to whole VND and
--   annual_frequency, lifespan_years to 2 decimals. A value whose denominator is 0 is NULL.
--   Return channel, customers, orders, revenue, aov, annual_frequency, lifespan_years, ltv.
--   Sort by channel.
-- Learn: grinding/sql-ltv.md, V2

-- INPUT
customers
| customer_id | channel  |
|-------------|----------|
| 1           | Facebook |
| 2           | Facebook |
| 3           | Shopee   |
| 4           | Shopee   |
| 5           | Shopee   |
| 6           | Zalo     |
| 7           | Referral |

orders
| order_id | customer_id | order_date | amount_vnd | status    |
|----------|-------------|------------|------------|-----------|
| 1        | 1           | 2024-02-01 | 200000     | delivered |
| 2        | 1           | 2024-05-01 | 300000     | delivered |
| 3        | 2           | 2024-03-03 | 500000     | delivered |
| 4        | 3           | 2024-01-10 | 100000     | delivered |
| 5        | 3           | 2024-04-10 | 100000     | delivered |
| 6        | 3           | 2024-07-10 | 100000     | delivered |
| 7        | 3           | 2024-10-10 | 100000     | delivered |
| 8        | 4           | 2024-06-06 | 200000     | delivered |
| 9        | 5           | 2024-08-08 | 999000     | cancelled |
| 10       | 5           | 2023-12-30 | 300000     | delivered |
| 11       | 6           | 2024-09-09 | 450000     | delivered |

channel_churn
| channel  | annual_churn_rate |
|----------|-------------------|
| Facebook | 0.50              |
| Shopee   | 0.25              |
| Zalo     | 0.00              |
| Referral | 0.20              |

-- EXPECTED
| channel  | customers | orders | revenue | aov    | annual_frequency | lifespan_years | ltv     |
|----------|-----------|--------|---------|--------|------------------|----------------|---------|
| Facebook | 2         | 3      | 1000000 | 333333 | 1.50             | 2.00           | 1000000 |
| Referral | 0         | 0      | 0       | NULL   | NULL             | 5.00           | NULL    |
| Shopee   | 2         | 5      | 600000  | 120000 | 2.50             | 4.00           | 1200000 |
| Zalo     | 1         | 1      | 450000  | 450000 | 1.00             | NULL           | NULL    |

-- QUERY
-- write your query here
