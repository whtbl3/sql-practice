-- HIDDEN TESTS for problem dp/01. No QUERY section: the problem's QUERY is used.

-- CASE a valley between two walls of different heights
-- INPUT
terrain
| pos | height |
|-----|--------|
| 1   | 4      |
| 2   | 2      |
| 3   | 0      |
| 4   | 3      |
| 5   | 2      |
| 6   | 5      |

-- EXPECTED
| pos | height | left_max | right_max | water |
|-----|--------|----------|-----------|-------|
| 1   | 4      | 4        | 5         | 0     |
| 2   | 2      | 4        | 5         | 2     |
| 3   | 0      | 4        | 5         | 4     |
| 4   | 3      | 4        | 5         | 1     |
| 5   | 2      | 4        | 5         | 2     |
| 6   | 5      | 5        | 5         | 0     |

-- CASE rising slope holds nothing
-- INPUT
terrain
| pos | height |
|-----|--------|
| 1   | 1      |
| 2   | 2      |
| 3   | 3      |

-- EXPECTED
| pos | height | left_max | right_max | water |
|-----|--------|----------|-----------|-------|
| 1   | 1      | 1        | 3         | 0     |
| 2   | 2      | 2        | 3         | 0     |
| 3   | 3      | 3        | 3         | 0     |
