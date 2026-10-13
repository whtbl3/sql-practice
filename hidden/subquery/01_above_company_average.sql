-- HIDDEN TESTS for problem subquery/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| name:text | salary:int |
|-----------|------------|

-- EXPECTED
| name | salary |
|------|--------|

-- CASE everyone earns the same
-- INPUT
employees
| name:text | salary:int |
|-----------|------------|
| A         | 5          |
| B         | 5          |

-- EXPECTED
| name | salary |
|------|--------|

-- CASE NULL salaries are ignored
-- INPUT
employees
| name:text | salary:int |
|-----------|------------|
| A         | NULL       |
| B         | 10         |
| C         | 20         |

-- EXPECTED
| name | salary |
|------|--------|
| C    | 20     |
