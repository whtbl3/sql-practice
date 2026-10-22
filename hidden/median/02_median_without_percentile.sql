-- HIDDEN TESTS for problem median/02. No QUERY section: the problem's QUERY is used.

-- CASE no known salary at all
-- INPUT
employees
| emp_id:int | department:text | salary_vnd:int |
|------------|-----------------|----------------|
| 1          | IT              | NULL           |

-- EXPECTED
| department:text | median_salary:numeric |
|-----------------|-----------------------|

-- CASE one employee, all equal, and an even count giving .5
-- INPUT
employees
| emp_id | department | salary_vnd |
|--------|------------|------------|
| 1      | A          | 7000000    |
| 2      | B          | 9000000    |
| 3      | B          | 9000000    |
| 4      | B          | 9000000    |
| 5      | C          | 1          |
| 6      | C          | 2          |

-- EXPECTED
| department | median_salary |
|------------|---------------|
| A          | 7000000.0     |
| B          | 9000000.0     |
| C          | 1.5           |

-- CASE NULLs placed so they would shift the middle if they were counted
-- INPUT
employees
| emp_id | department | salary_vnd |
|--------|------------|------------|
| 1      | X          | NULL       |
| 2      | X          | NULL       |
| 3      | X          | 100        |
| 4      | X          | 200        |
| 5      | X          | 900        |

-- EXPECTED
| department | median_salary |
|------------|---------------|
| X          | 200.0         |

-- CASE duplicates at the bottom: RANK or DENSE_RANK would pick the wrong middle rows
-- INPUT
employees
| emp_id | department | salary_vnd |
|--------|------------|------------|
| 1      | D          | 10         |
| 2      | D          | 10         |
| 3      | D          | 30         |
| 4      | D          | 40         |

-- EXPECTED
| department | median_salary |
|------------|---------------|
| D          | 20.0          |
