-- HIDDEN TESTS for problem subquery/07. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| name:text | salary:int |
|-----------|------------|

-- EXPECTED
| second_highest |
|----------------|
| NULL           |

-- CASE single employee
-- INPUT
employees
| name:text | salary:int |
|-----------|------------|
| A         | 5          |

-- EXPECTED
| second_highest |
|----------------|
| NULL           |

-- CASE everyone tied
-- INPUT
employees
| name:text | salary:int |
|-----------|------------|
| A         | 5          |
| B         | 5          |

-- EXPECTED
| second_highest |
|----------------|
| NULL           |

-- CASE NULL salaries are ignored
-- INPUT
employees
| name:text | salary:int |
|-----------|------------|
| A         | NULL       |
| B         | 5          |
| C         | 3          |

-- EXPECTED
| second_highest |
|----------------|
| 3              |
