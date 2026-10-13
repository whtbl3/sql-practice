-- HIDDEN TESTS for problem subquery/06. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|

-- EXPECTED
| department | third_highest |
|------------|---------------|

-- CASE NULL salaries are ignored
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| a         | X               | NULL       |
| b         | X               | 3          |
| c         | X               | 2          |
| d         | X               | 1          |

-- EXPECTED
| department | third_highest |
|------------|---------------|
| X          | 1             |

-- CASE ties at the top
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| a         | X               | 9          |
| b         | X               | 9          |
| c         | X               | 9          |
| d         | X               | 8          |
| e         | X               | 7          |
| f         | X               | 7          |

-- EXPECTED
| department | third_highest |
|------------|---------------|
| X          | 7             |
