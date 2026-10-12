-- Problem pivot/03: Unpivot scores into rows  [Medium]
-- Pattern: Unpivot columns to rows (LATERAL VALUES / UNION ALL)
-- Variant: reverse pivot
--
-- Task: Turn each student's three score columns into rows: student, subject ('math', 'physics',
--   'chem'), score. Skip subjects whose score is NULL. Sort by student, subject.

-- INPUT
grades
| student | math | physics | chem |
|---------|------|---------|------|
| Ann     | 90   | 80      | NULL |
| Bob     | 70   | NULL    | 60   |

-- EXPECTED
| student | subject | score |
|---------|---------|-------|
| Ann     | math    | 90    |
| Ann     | physics | 80    |
| Bob     | chem    | 60    |
| Bob     | math    | 70    |

-- QUERY
-- write your query here
