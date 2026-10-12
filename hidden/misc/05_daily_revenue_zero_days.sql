-- HIDDEN TESTS for problem misc/05. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
sales
| sale_date:date | amount:int |
|----------------|------------|

-- EXPECTED
| sale_date | revenue |
|-----------|---------|

-- CASE single day
-- INPUT
sales
| sale_date:date | amount:int |
|----------------|------------|
| 2024-05-05     | 9          |

-- EXPECTED
| sale_date  | revenue |
|------------|---------|
| 2024-05-05 | 9       |

-- CASE across a leap day
-- INPUT
sales
| sale_date:date | amount:int |
|----------------|------------|
| 2024-02-28     | 1          |
| 2024-03-01     | 2          |

-- EXPECTED
| sale_date  | revenue |
|------------|---------|
| 2024-02-28 | 1       |
| 2024-02-29 | 0       |
| 2024-03-01 | 2       |
