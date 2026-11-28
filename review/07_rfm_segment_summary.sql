-- Review #1 (2026-11-28): q review 1 [c|h|hv|s]
-- Problem cohort/07: Revenue share by RFM segment  [Hard]
-- Pattern: RFM: CASE labels + fixed segment list LEFT JOIN + SUM(SUM()) OVER
-- Variant: one row per segment instead of one row per customer, empty segments still listed
--
-- Task: customer_rfm already holds the scores. Label each customer with the FIRST matching rule:
--     'Champions' r_score = 3 AND f_score = 3
--     'Loyal'     r_score >= 2 AND f_score >= 2
--     'New'       r_score = 3 AND f_score = 1
--     'At Risk'   r_score = 1 AND f_score >= 2
--     'Lost'      everything else
--   For ALL five segments (even with no customers) return segment, customers, revenue (sum of
--   monetary, 0 if none) and revenue_pct = revenue / total revenue * 100 rounded to 1 decimal.
--   Sort in the fixed order Champions, Loyal, New, At Risk, Lost.
-- Learn: grinding/sql-rfm.md, B5

-- INPUT
customer_rfm
| customer_id | r_score | f_score | m_score | monetary |
|-------------|---------|---------|---------|----------|
| 1           | 3       | 3       | 3       | 1500     |
| 2           | 3       | 3       | 2       | 900      |
| 3           | 2       | 2       | 2       | 400      |
| 4           | 3       | 1       | 1       | 100      |
| 5           | 1       | 1       | 1       | 50       |
| 6           | 2       | 3       | 3       | 1000     |

-- EXPECTED
| segment   | customers | revenue | revenue_pct |
|-----------|-----------|---------|-------------|
| Champions | 2         | 2400    | 60.8        |
| Loyal     | 2         | 1400    | 35.4        |
| New       | 1         | 100     | 2.5         |
| At Risk   | 0         | 0       | 0.0         |
| Lost      | 1         | 50      | 1.3         |

-- QUERY
-- write your query here
WITH segments AS (
    SELECT 'Champions' AS segment, 1 AS sort_order
    UNION ALL SELECT 'Loyal', 2
    UNION ALL SELECT 'New', 3
    UNION ALL SELECT 'At Risk', 4
    UNION ALL SELECT 'Lost', 5
),
labeled_customers AS (
    SELECT
        customer_id,
        monetary,
        CASE
            WHEN r_score = 3 AND f_score = 3 THEN 'Champions'
            WHEN r_score >= 2 AND f_score >= 2 THEN 'Loyal'
            WHEN r_score = 3 AND f_score = 1 THEN 'New'
            WHEN r_score = 1 AND f_score >= 2 THEN 'At Risk'
            ELSE 'Lost'
        END AS segment
    FROM customer_rfm
)
SELECT
    s.segment,
    COUNT(l.customer_id) AS customers,
    COALESCE(SUM(l.monetary), 0) AS revenue,
    ROUND(
        COALESCE(SUM(l.monetary), 0) * 100.0
        / NULLIF(SUM(SUM(l.monetary)) OVER (), 0),
        1
    ) AS revenue_pct
FROM segments s
LEFT JOIN labeled_customers l
    ON s.segment = l.segment
GROUP BY s.segment, s.sort_order
ORDER BY s.sort_order;