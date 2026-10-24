-- Problem rfm/06: RFM code to segment through a rules table  [Hard]
-- Pattern: RFM: regex match against a rules table + pick the best rule (LATERAL ... LIMIT 1 / DISTINCT ON)
-- Variant: cohort/05 hard-codes the rules in CASE; here they are rows with a priority
--
-- Task: rfm_code = r_score, f_score, m_score concatenated (e.g. '545'). segment_rules holds the
--   segmentation rules: a code matches a rule when it matches the POSIX regular expression in
--   pattern (patterns are already anchored with ^...$). Rules overlap: each customer gets the
--   segment of the matching rule with the LOWEST priority number. A customer that matches no
--   rule gets 'Unclassified'. Return customer_id, rfm_code, segment. Sort by customer_id.
-- Learn: grinding/sql-rfm.md, V4

-- INPUT
customer_rfm
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 5       | 5       | 5       |
| 2           | 5       | 4       | 5       |
| 3           | 3       | 5       | 4       |
| 4           | 4       | 1       | 2       |
| 5           | 2       | 3       | 1       |
| 6           | 1       | 1       | 1       |
| 7           | 3       | 2       | 1       |
| 8           | 5       | 1       | 1       |
| 9           | 4       | 4       | 5       |

segment_rules
| priority | segment | pattern      |
|----------|---------|--------------|
| 20       | Loyal   | ^[345][45].$ |
| 50       | Dormant | ^[12][12].$  |
| 10       | VIP     | ^5[45][45]$  |
| 40       | At risk | ^[12][345].$ |
| 30       | New     | ^[45]1.$     |

-- EXPECTED
| customer_id | rfm_code | segment      |
|-------------|----------|--------------|
| 1           | 555      | VIP          |
| 2           | 545      | VIP          |
| 3           | 354      | Loyal        |
| 4           | 412      | New          |
| 5           | 231      | At risk      |
| 6           | 111      | Dormant      |
| 7           | 321      | Unclassified |
| 8           | 511      | New          |
| 9           | 445      | Loyal        |

-- QUERY
WITH coded AS (
  SELECT customer_id, CONCAT(r_score, f_score, m_score) AS rfm_code
  FROM customer_rfm
)
SELECT c.customer_id, c.rfm_code,
       COALESCE(best.segment, 'Unclassified') AS segment
FROM coded c
LEFT JOIN LATERAL (                                 -- for each customer: the matching rule with the lowest priority
  SELECT r.segment
  FROM segment_rules r
  WHERE c.rfm_code ~ r.pattern
  ORDER BY r.priority
  LIMIT 1
) best ON TRUE                                      -- LEFT ... ON TRUE keeps customers that match nothing
ORDER BY c.customer_id;
