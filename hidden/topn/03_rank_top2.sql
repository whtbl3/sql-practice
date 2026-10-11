-- HIDDEN TESTS for problem topn/03. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|

-- EXPECTED
| department | name | salary |
|------------|------|--------|

-- CASE NULL salaries ignored
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 300        |
| 2          | B         | IT              | NULL       |
| 3          | C         | IT              | 200        |
| 4          | D         | IT              | NULL       |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| IT         | A    | 300    |
| IT         | C    | 200    |

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

-- CASE three-way tie at the top, rank 2 does not exist
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 500        |
| 2          | B         | IT              | 500        |
| 3          | C         | IT              | 500        |
| 4          | D         | IT              | 400        |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| IT         | A    | 500    |
| IT         | B    | 500    |
| IT         | C    | 500    |
