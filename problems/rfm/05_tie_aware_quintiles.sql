-- Problem rfm/05: Quintile scores where equal values get equal scores  [Hard]
-- Pattern: RFM: CUME_DIST (or COUNT over the default RANGE frame) instead of NTILE
-- Variant: cohort/02 splits ties by customer_id; here customers with the same value MUST share a score
--
-- Task: n = number of customers in customer_metrics. Score every metric from 1 to 5:
--     f_score = ceiling(5 * k / n), k = number of customers whose frequency is <= this customer's
--     m_score = ceiling(5 * k / n), k = number of customers whose monetary_vnd is <= this customer's
--     r_score = ceiling(5 * k / n), k = number of customers whose recency_days is >= this customer's
--   (k counts the customer themself). Lower recency is better, so the most recent buyers get 5.
--   Return customer_id, r_score, f_score, m_score as integers. Sort by customer_id.
-- Learn: grinding/sql-rfm.md, V2

-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 5            | 8         | 9000000      |
| 2           | 5            | 3         | 1200000      |
| 3           | 12           | 3         | 1200000      |
| 4           | 30           | 1         | 300000       |
| 5           | 30           | 1         | 300000       |
| 6           | 30           | 2         | 800000       |
| 7           | 60           | 5         | 4000000      |
| 8           | 90           | 1         | 300000       |
| 9           | 150          | 2         | 800000       |
| 10          | 200          | 1         | 150000       |

-- EXPECTED
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 5       | 5       | 5       |
| 2           | 5       | 4       | 4       |
| 3           | 4       | 4       | 4       |
| 4           | 4       | 2       | 2       |
| 5           | 4       | 2       | 2       |
| 6           | 4       | 3       | 3       |
| 7           | 2       | 5       | 5       |
| 8           | 2       | 2       | 2       |
| 9           | 1       | 3       | 3       |
| 10          | 1       | 2       | 1       |

-- QUERY
-- write your query here
