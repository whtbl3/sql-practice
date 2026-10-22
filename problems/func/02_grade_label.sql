-- Problem func/02: Grade label with validation (PL/pgSQL IF)  [Easy]
-- Pattern: PL/pgSQL scalar function: IF / ELSIF / RAISE EXCEPTION
-- Variant: reject invalid input instead of returning a wrong value
--
-- Task: Create grade_of(p_score INT) RETURNS TEXT: 90 or more -> 'A', 80 or more -> 'B', 65 or more
--   -> 'C', otherwise 'F'. A NULL score -> 'N/A'. A score below 0 or above 100 must raise an error
--   whose message is 'invalid score: <score>' (e.g. invalid score: 101).
-- Learn: grinding/sql-functions-procedures.md, mục 3

-- INPUT
students
| student_id:int | name:text | score:int |
|----------------|-----------|-----------|
| 1              | An        | 95        |
| 2              | Binh      | 80        |
| 3              | Chi       | 64        |
| 4              | Dung      | NULL      |
| 5              | Em        | 65        |

-- EXPECTED
| student_id | grade |
|------------|-------|
| 1          | A     |
| 2          | B     |
| 3          | F     |
| 4          | N/A   |
| 5          | C     |

-- CALL
SELECT student_id, grade_of(score) AS grade FROM students ORDER BY student_id;

-- QUERY
-- write your query here
