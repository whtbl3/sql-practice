-- Problem graph/05: Study order of courses with prerequisites (topological levels)  [Hard]
-- Pattern: Graph: recursive longest path from the roots of a DAG -> MAX(depth) per node
-- Variant: a course with several prerequisites must wait for the SLOWEST of them
--
-- Task: A data-analytics bootcamp lists prerequisites (course_id needs prereq_id first). A
--   course's level is 0 when it has no prerequisite, otherwise 1 + the highest level among its
--   prerequisites (so every course comes after all of its prerequisites). The graph has no
--   cycles. Return course_id, name, level for every course. Sort by level, course_id.
-- Learn: grinding/sql-recursive.md, mục 2.5

-- INPUT
courses
| course_id | name             |
|-----------|------------------|
| 1         | SQL basics       |
| 2         | Python basics    |
| 3         | Advanced SQL     |
| 4         | Data analysis    |
| 5         | Machine Learning |
| 6         | Statistics       |
| 7         | Data Engineering |

prerequisites
| course_id | prereq_id |
|-----------|-----------|
| 3         | 1         |
| 4         | 2         |
| 4         | 3         |
| 5         | 4         |
| 5         | 2         |
| 5         | 6         |
| 7         | 3         |

-- EXPECTED
| course_id | name             | level |
|-----------|------------------|-------|
| 1         | SQL basics       | 0     |
| 2         | Python basics    | 0     |
| 6         | Statistics       | 0     |
| 3         | Advanced SQL     | 1     |
| 4         | Data analysis    | 2     |
| 7         | Data Engineering | 2     |
| 5         | Machine Learning | 3     |

-- QUERY
WITH RECURSIVE depth(course_id, d) AS (
  SELECT c.course_id, 0                             -- roots: no prerequisite at all
  FROM courses c
  WHERE NOT EXISTS (SELECT 1 FROM prerequisites p WHERE p.course_id = c.course_id)
  UNION ALL
  SELECT p.course_id, dp.d + 1                      -- one step further along every path
  FROM depth dp
  JOIN prerequisites p ON p.prereq_id = dp.course_id
)
SELECT c.course_id, c.name, MAX(dp.d) AS level      -- level = LONGEST path from a root, not the shortest
FROM courses c
JOIN depth dp ON dp.course_id = c.course_id
GROUP BY c.course_id, c.name
ORDER BY level, c.course_id;
