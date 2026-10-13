-- HIDDEN TESTS for problem window/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
scores
| player:text | score:int |
|-------------|-----------|

-- EXPECTED
| player | score | row_num | rnk | dense_rnk |
|--------|-------|---------|-----|-----------|

-- CASE everyone tied
-- INPUT
scores
| player:text | score:int |
|-------------|-----------|
| C           | 5         |
| A           | 5         |
| B           | 5         |

-- EXPECTED
| player | score | row_num | rnk | dense_rnk |
|--------|-------|---------|-----|-----------|
| A      | 5     | 1       | 1   | 1         |
| B      | 5     | 2       | 1   | 1         |
| C      | 5     | 3       | 1   | 1         |

-- CASE NULL score ranks last
-- INPUT
scores
| player:text | score:int |
|-------------|-----------|
| A           | 10        |
| B           | NULL      |
| C           | 5         |

-- EXPECTED
| player | score | row_num | rnk | dense_rnk |
|--------|-------|---------|-----|-----------|
| A      | 10    | 1       | 1   | 1         |
| C      | 5     | 2       | 2   | 2         |
| B      | NULL  | 3       | 3   | 3         |
