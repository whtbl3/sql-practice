-- HIDDEN TESTS for problem misc/04. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|

-- EXPECTED
| department | median_salary |
|------------|---------------|

-- CASE NULL salaries are ignored
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| A         | HR              | 3000       |
| B         | HR              | NULL       |
| C         | HR              | 5000       |
| D         | HR              | 9000       |

-- EXPECTED
| department | median_salary |
|------------|---------------|
| HR         | 5000.0        |

-- CASE odd count, unsorted input
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| A         | IT              | 9          |
| B         | IT              | 1          |
| C         | IT              | 5          |

-- EXPECTED
| department | median_salary |
|------------|---------------|
| IT         | 5.0           |
