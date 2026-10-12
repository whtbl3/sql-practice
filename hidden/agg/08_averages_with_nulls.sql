-- HIDDEN TESTS for problem agg/08. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
ratings
| product:text | rating:int |
|--------------|------------|

-- EXPECTED
| product | total_rows | rated_rows | avg_rating | avg_with_zeros |
|---------|------------|------------|------------|----------------|

-- CASE all ratings NULL
-- INPUT
ratings
| product:text | rating:int |
|--------------|------------|
| A            | NULL       |

-- EXPECTED
| product | total_rows | rated_rows | avg_rating | avg_with_zeros |
|---------|------------|------------|------------|----------------|
| A       | 1          | 0          | NULL       | 0.0            |

-- CASE no NULLs: both averages agree
-- INPUT
ratings
| product:text | rating:int |
|--------------|------------|
| A            | 1          |
| A            | 2          |

-- EXPECTED
| product | total_rows | rated_rows | avg_rating | avg_with_zeros |
|---------|------------|------------|------------|----------------|
| A       | 2          | 2          | 1.5        | 1.5            |
