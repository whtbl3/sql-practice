-- HIDDEN TESTS for problem func/02. No QUERY section: the problem's QUERY is used.

-- CASE boundaries
-- INPUT
students
| student_id:int | name:text | score:int |
|----------------|-----------|-----------|
| 1              | A         | 100       |
| 2              | B         | 90        |
| 3              | C         | 89        |
| 4              | D         | 79        |
| 5              | E         | 0         |

-- EXPECTED
| student_id | grade |
|------------|-------|
| 1          | A     |
| 2          | A     |
| 3          | B     |
| 4          | C     |
| 5          | F     |

-- CASE score above 100 is rejected
-- INPUT
students
| student_id:int | name:text | score:int |
|----------------|-----------|-----------|
| 1              | A         | 95        |
| 2              | B         | 101       |

-- EXPECTED
ERROR: invalid score: 101

-- CASE negative score is rejected
-- INPUT
students
| student_id:int | name:text | score:int |
|----------------|-----------|-----------|
| 1              | A         | -1        |

-- EXPECTED
ERROR: invalid score: -1
