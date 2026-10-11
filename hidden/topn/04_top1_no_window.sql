-- HIDDEN TESTS for problem topn/04. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|

-- EXPECTED
| department | name | salary |
|------------|------|--------|

-- CASE all salaries NULL
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | NULL       |
| 2          | B         | HR              | NULL       |

-- EXPECTED
| department | name | salary |
|------------|------|--------|

-- CASE everyone tied
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 100        |
| 2          | B         | IT              | 100        |
| 3          | C         | IT              | 100        |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| IT         | A    | 100    |
| IT         | B    | 100    |
| IT         | C    | 100    |

-- CASE one employee per department
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 10         |
| 2          | B         | HR              | 20         |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| HR         | B    | 20     |
| IT         | A    | 10     |
