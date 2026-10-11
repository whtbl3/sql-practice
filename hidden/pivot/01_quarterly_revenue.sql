-- HIDDEN TESTS for problem pivot/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
sales
| product:text | sale_date:date | amount:int |
|--------------|----------------|------------|

-- EXPECTED
| product | q1 | q2 | q3 | q4 |
|---------|----|----|----|----|

-- CASE years other than 2024 excluded
-- INPUT
sales
| product:text | sale_date:date | amount:int |
|--------------|----------------|------------|
| A            | 2023-02-01     | 100        |
| A            | 2024-05-01     | 50         |

-- EXPECTED
| product | q1 | q2 | q3 | q4 |
|---------|----|----|----|----|
| A       | 0  | 50 | 0  | 0  |

-- CASE dates right at quarter boundaries
-- INPUT
sales
| product:text | sale_date:date | amount:int |
|--------------|----------------|------------|
| A            | 2024-03-31     | 10         |
| A            | 2024-04-01     | 20         |
| A            | 2024-06-30     | 30         |
| A            | 2024-07-01     | 40         |
| A            | 2024-09-30     | 50         |
| A            | 2024-10-01     | 60         |
| A            | 2024-12-31     | 70         |

-- EXPECTED
| product | q1 | q2 | q3 | q4  |
|---------|----|----|----|-----|
| A       | 10 | 50 | 90 | 130 |
