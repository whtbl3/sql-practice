-- HIDDEN TESTS for problem graph/05. No QUERY section: the problem's QUERY is used.

-- CASE no prerequisites: everything is level 0
-- INPUT
courses
| course_id | name |
|-----------|------|
| 2         | B    |
| 1         | A    |

prerequisites
| course_id:int | prereq_id:int |
|---------------|---------------|

-- EXPECTED
| course_id | name | level |
|-----------|------|-------|
| 1         | A    | 0     |
| 2         | B    | 0     |

-- CASE a short and a long path to the same course: the long one decides
-- INPUT
courses
| course_id | name |
|-----------|------|
| 1         | A    |
| 2         | B    |
| 3         | C    |
| 4         | D    |

prerequisites
| course_id | prereq_id |
|-----------|-----------|
| 4         | 1         |
| 2         | 1         |
| 3         | 2         |
| 4         | 3         |

-- EXPECTED
| course_id | name | level |
|-----------|------|-------|
| 1         | A    | 0     |
| 2         | B    | 1     |
| 3         | C    | 2     |
| 4         | D    | 3     |
