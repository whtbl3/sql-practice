-- HIDDEN TESTS for problem window/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|

-- EXPECTED
| name | department | salary | dept_avg | diff_from_avg | dept_headcount |
|------|------------|--------|----------|---------------|----------------|

-- CASE average that is not a whole number
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| a         | X               | 1          |
| b         | X               | 2          |

-- EXPECTED
| name | department | salary | dept_avg | diff_from_avg | dept_headcount |
|------|------------|--------|----------|---------------|----------------|
| a    | X          | 1      | 1.5      | -0.5          | 2              |
| b    | X          | 2      | 1.5      | 0.5           | 2              |

-- CASE NULL salary: counted in headcount, not in the average
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| a         | X               | NULL       |
| b         | X               | 10         |
| c         | X               | 20         |

-- EXPECTED
| name | department | salary | dept_avg | diff_from_avg | dept_headcount |
|------|------------|--------|----------|---------------|----------------|
| a    | X          | NULL   | 15.0     | NULL          | 3              |
| b    | X          | 10     | 15.0     | -5.0          | 3              |
| c    | X          | 20     | 15.0     | 5.0           | 3              |
