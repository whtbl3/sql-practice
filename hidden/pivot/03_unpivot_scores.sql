-- HIDDEN TESTS for problem pivot/03. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
grades
| student:text | math:int | physics:int | chem:int |
|--------------|----------|-------------|----------|

-- EXPECTED
| student | subject | score |
|---------|---------|-------|

-- CASE student with all NULL scores disappears
-- INPUT
grades
| student:text | math:int | physics:int | chem:int |
|--------------|----------|-------------|----------|
| Ann          | NULL     | NULL        | NULL     |
| Bob          | 1        | 2           | 3        |

-- EXPECTED
| student | subject | score |
|---------|---------|-------|
| Bob     | chem    | 3     |
| Bob     | math    | 1     |
| Bob     | physics | 2     |

-- CASE zero is a real score, not NULL
-- INPUT
grades
| student:text | math:int | physics:int | chem:int |
|--------------|----------|-------------|----------|
| Ann          | 0        | NULL        | 0        |

-- EXPECTED
| student | subject | score |
|---------|---------|-------|
| Ann     | chem    | 0     |
| Ann     | math    | 0     |
