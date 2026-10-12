-- HIDDEN TESTS for problem recursive/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| emp_id:int | name:text | manager_id:int |
|------------|-----------|----------------|

-- EXPECTED
| name | depth | path |
|------|-------|------|

-- CASE only top managers
-- INPUT
employees
| emp_id:int | name:text | manager_id:int |
|------------|-----------|----------------|
| 1          | A         | NULL           |
| 2          | B         | NULL           |

-- EXPECTED
| name | depth | path |
|------|-------|------|
| A    | 0     | A    |
| B    | 0     | B    |

-- CASE child listed before its manager
-- INPUT
employees
| emp_id:int | name:text | manager_id:int |
|------------|-----------|----------------|
| 1          | Kid       | 2              |
| 2          | Mid       | 3              |
| 3          | Top       | NULL           |

-- EXPECTED
| name | depth | path            |
|------|-------|-----------------|
| Kid  | 2     | Top > Mid > Kid |
| Mid  | 1     | Top > Mid       |
| Top  | 0     | Top             |
