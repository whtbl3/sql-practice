-- HIDDEN TESTS for problem subquery/09. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
sales
| category:text | amount:int |
|---------------|------------|

-- EXPECTED
| category | revenue |
|----------|---------|

-- CASE all categories equal
-- INPUT
sales
| category:text | amount:int |
|---------------|------------|
| A             | 10         |
| B             | 10         |

-- EXPECTED
| category | revenue |
|----------|---------|

-- CASE a single category is never above itself
-- INPUT
sales
| category:text | amount:int |
|---------------|------------|
| A             | 1          |
| A             | 2          |

-- EXPECTED
| category | revenue |
|----------|---------|
