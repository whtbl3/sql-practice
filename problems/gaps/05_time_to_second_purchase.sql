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
-- Learn: grinding/sql-analytics-patterns.md, mục 9.6

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
-- write your query here
