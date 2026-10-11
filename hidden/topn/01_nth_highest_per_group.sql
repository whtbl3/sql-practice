-- HIDDEN TESTS for problem topn/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|

-- EXPECTED
| department | name | salary |
|------------|------|--------|

-- CASE everyone has the same salary
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 100        |
| 2          | B         | IT              | 100        |
| 3          | C         | IT              | 100        |
| 4          | D         | HR              | 200        |
| 5          | E         | HR              | 100        |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| HR         | E    | 100    |

-- CASE NULL salary
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
| IT         | C    | 200    |

-- CASE tie at second rank
-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 500        |
| 2          | B         | IT              | 400        |
| 3          | C         | IT              | 400        |
| 4          | D         | IT              | 300        |
| 5          | E         | Sales           | 900        |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| IT         | B    | 400    |
| IT         | C    | 400    |
