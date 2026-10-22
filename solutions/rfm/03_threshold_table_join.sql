-- Problem rfm/03: Scoring from a thresholds table  [Medium]
-- Pattern: RFM: non-equi LEFT JOIN on a range table (min <= value <= max, NULL max = open)
-- Variant: cut-offs live in a table the marketing team edits, not hard-coded in CASE
--
-- Task: customer_metrics already holds each customer's recency_days, frequency and monetary_vnd.
--   rfm_thresholds gives, for each metric ('R', 'F', 'M'), the score of every value range:
--   a value v gets that score when min_value <= v <= max_value; max_value NULL means no upper
--   bound. If a value falls in no range (or is NULL) its score is 0. Return customer_id,
--   r_score, f_score, m_score and rfm_code (the three scores concatenated, e.g. '524').
--   Sort by customer_id.
-- Learn: grinding/sql-analytics-patterns.md, mục 2.10

-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 3            | 12        | 15000000     |
| 2           | 30           | 4         | 2000000      |
| 3           | 61           | 1         | 499999       |
| 4           | 200          | 2         | 7500000      |
| 5           | 45           | 0         | 0            |
| 6           | 8            | 5         | 500000       |
| 7           | NULL         | 0         | 0            |

rfm_thresholds
| metric | score | min_value | max_value |
|--------|-------|-----------|-----------|
| R      | 5     | 0         | 7         |
| R      | 4     | 8         | 30        |
| R      | 3     | 31        | 60        |
| R      | 2     | 61        | 120       |
| R      | 1     | 121       | NULL      |
| F      | 1     | 1         | 1         |
| F      | 2     | 2         | 2         |
| F      | 3     | 3         | 4         |
| F      | 4     | 5         | 9         |
| F      | 5     | 10        | NULL      |
| M      | 1     | 0         | 499999    |
| M      | 2     | 500000    | 1999999   |
| M      | 3     | 2000000   | 4999999   |
| M      | 4     | 5000000   | 9999999   |
| M      | 5     | 10000000  | NULL      |

-- EXPECTED
| customer_id | r_score | f_score | m_score | rfm_code |
|-------------|---------|---------|---------|----------|
| 1           | 5       | 5       | 5       | 555      |
| 2           | 4       | 3       | 3       | 433      |
| 3           | 2       | 1       | 1       | 211      |
| 4           | 1       | 2       | 4       | 124      |
| 5           | 3       | 0       | 1       | 301      |
| 6           | 4       | 4       | 2       | 442      |
| 7           | 0       | 0       | 1       | 001      |

-- QUERY
WITH scored AS (
  SELECT c.customer_id,
         COALESCE(r.score, 0) AS r_score,
         COALESCE(f.score, 0) AS f_score,
         COALESCE(m.score, 0) AS m_score
  FROM customer_metrics c
  LEFT JOIN rfm_thresholds r                         -- one join per metric, each with its own alias
         ON r.metric = 'R'
        AND c.recency_days >= r.min_value
        AND (r.max_value IS NULL OR c.recency_days <= r.max_value)
  LEFT JOIN rfm_thresholds f
         ON f.metric = 'F'
        AND c.frequency >= f.min_value
        AND (f.max_value IS NULL OR c.frequency <= f.max_value)
  LEFT JOIN rfm_thresholds m
         ON m.metric = 'M'
        AND c.monetary_vnd >= m.min_value
        AND (m.max_value IS NULL OR c.monetary_vnd <= m.max_value)
)
SELECT customer_id, r_score, f_score, m_score,
       CONCAT(r_score, f_score, m_score) AS rfm_code
FROM scored
ORDER BY customer_id;
