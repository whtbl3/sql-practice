-- HIDDEN TESTS for problem window/05. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|

-- EXPECTED
| name | department | salary | top_earner | lowest_earner |
|------|------------|--------|------------|---------------|

-- CASE one-person department
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| Solo      | X               | 10         |

-- EXPECTED
| name | department | salary | top_earner | lowest_earner |
|------|------------|--------|------------|---------------|
| Solo | X          | 10     | Solo       | Solo          |

-- CASE tie at the bottom picks the first name
-- INPUT
employees
| name:text | department:text | salary:int |
|-----------|-----------------|------------|
| b         | X               | 1          |
| a         | X               | 1          |
| c         | X               | 5          |

-- EXPECTED
| name | department | salary | top_earner | lowest_earner |
|------|------------|--------|------------|---------------|
| a    | X          | 1      | c          | a             |
| b    | X          | 1      | c          | a             |
| c    | X          | 5      | c          | a             |
