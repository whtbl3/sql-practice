-- Problem gaps/05: Time to the second purchase by acquisition channel  [Hard]
-- Pattern: Gaps: ROW_NUMBER over distinct days -> 1st/2nd day per customer -> AVG and PERCENTILE_CONT per group
-- Variant: measures HOW LONG until the return (cohort/04 only counts returns within 30 days)
--
-- Task: An online fashion shop records each customer's acquisition channel. Using distinct
--   purchase days, a customer's second purchase is their second purchase day (a second order on
--   the first day does not count). days_to_return = second purchase day - first purchase day.
--   For every channel that appears in customers return channel, buyers (customers with at least
--   one order), returned (buyers with a second purchase day), return_rate_pct = returned /
--   buyers * 100, avg_days and median_days of days_to_return (median = average of the two
--   middle values when the count is even). Round the three to 1 decimal; they are NULL when
--   the denominator is empty. Sort by channel.
-- Learn: grinding/sql-purchase-gaps.md, B2, B4

-- INPUT
customers
| customer_id | channel     |
|-------------|-------------|
| 1           | Facebook    |
| 2           | Facebook    |
| 3           | Facebook    |
| 4           | TikTok Shop |
| 5           | TikTok Shop |
| 6           | TikTok Shop |
| 7           | TikTok Shop |
| 8           | Shopee      |
| 9           | Referral    |

orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-11 |
| 3        | 1           | 2024-03-01 |
| 4        | 2           | 2024-01-05 |
| 5        | 2           | 2024-03-05 |
| 6        | 3           | 2024-01-07 |
| 7        | 4           | 2024-02-01 |
| 8        | 4           | 2024-02-03 |
| 9        | 5           | 2024-02-01 |
| 10       | 5           | 2024-02-04 |
| 11       | 6           | 2024-02-01 |
| 12       | 6           | 2024-02-05 |
| 13       | 7           | 2024-02-01 |
| 14       | 7           | 2024-08-19 |
| 15       | 8           | 2024-03-01 |
| 16       | 8           | 2024-03-01 |

-- EXPECTED
| channel     | buyers | returned | return_rate_pct | avg_days | median_days |
|-------------|--------|----------|-----------------|----------|-------------|
| Facebook    | 3      | 2        | 66.7            | 35.0     | 35.0        |
| Referral    | 0      | 0        | NULL            | NULL     | NULL        |
| Shopee      | 1      | 0        | 0.0             | NULL     | NULL        |
| TikTok Shop | 4      | 4        | 100.0           | 52.3     | 3.5         |

-- QUERY
WITH days AS (
  SELECT DISTINCT customer_id, order_date FROM orders
),
ranked AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
  FROM days
),
per_customer AS (                                   -- one row per buyer: first and second purchase day
  SELECT customer_id,
         MAX(order_date) FILTER (WHERE rn = 2) - MAX(order_date) FILTER (WHERE rn = 1) AS days_to_return
  FROM ranked
  WHERE rn <= 2
  GROUP BY customer_id
)
SELECT c.channel,
       COUNT(p.customer_id)    AS buyers,           -- customers without orders: no p row
       COUNT(p.days_to_return) AS returned,         -- NULL days = never came back
       ROUND(100.0 * COUNT(p.days_to_return) / NULLIF(COUNT(p.customer_id), 0), 1) AS return_rate_pct,
       ROUND(AVG(p.days_to_return), 1) AS avg_days,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.days_to_return))::numeric, 1) AS median_days
FROM customers c
LEFT JOIN per_customer p ON p.customer_id = c.customer_id
GROUP BY c.channel
ORDER BY c.channel;
