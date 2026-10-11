-- HIDDEN TESTS for problem selfjoin/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| emp_id:int | name:text | salary:int | manager_id:int |
|------------|-----------|------------|----------------|

-- EXPECTED
| employee | emp_salary | manager | mgr_salary |
|----------|------------|---------|------------|

-- CASE nobody earns more than their manager
-- INPUT
employees
| emp_id:int | name:text | salary:int | manager_id:int |
|------------|-----------|------------|----------------|
| 1          | Alice     | 9000       | NULL           |
| 2          | Bob       | 6000       | 1              |
| 3          | Carol     | 5000       | 1              |

-- EXPECTED
| employee | emp_salary | manager | mgr_salary |
|----------|------------|---------|------------|

-- CASE salary equal to the manager's does not count
-- INPUT
employees
| emp_id:int | name:text | salary:int | manager_id:int |
|------------|-----------|------------|----------------|
| 1          | Alice     | 6000       | NULL           |
| 2          | Bob       | 6000       | 1              |
| 3          | Carol     | 6001       | 1              |

-- EXPECTED
| employee | emp_salary | manager | mgr_salary |
|----------|------------|---------|------------|
| Carol    | 6001       | Alice   | 6000       |

-- CASE NULL manager ignored, multiple levels
-- INPUT
employees
| emp_id:int | name:text | salary:int | manager_id:int |
|------------|-----------|------------|----------------|
| 1          | Alice     | 5000       | NULL           |
| 2          | Bob       | 4000       | 1              |
| 3          | Carol     | 4500       | 2              |
| 4          | Dan       | 8000       | NULL           |

-- EXPECTED
| employee | emp_salary | manager | mgr_salary |
|----------|------------|---------|------------|
| Carol    | 4500       | Bob     | 4000       |
