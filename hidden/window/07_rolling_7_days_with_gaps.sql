-- HIDDEN TESTS for problem window/07. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
daily_sales
| sale_date:date | revenue:int |
|----------------|-------------|

-- EXPECTED
| sale_date | revenue | rolling_7d |
|-----------|---------|------------|

-- CASE exactly 6 and 7 days apart
-- INPUT
daily_sales
| sale_date:date | revenue:int |
|----------------|-------------|
| 2024-01-01     | 1           |
| 2024-01-07     | 2           |
| 2024-01-08     | 4           |

-- EXPECTED
| sale_date  | revenue | rolling_7d |
|------------|---------|------------|
| 2024-01-01 | 1       | 1          |
| 2024-01-07 | 2       | 3          |
| 2024-01-08 | 4       | 6          |

-- CASE no gaps at all
-- INPUT
daily_sales
| sale_date:date | revenue:int |
|----------------|-------------|
| 2024-03-01     | 1           |
| 2024-03-02     | 1           |
| 2024-03-03     | 1           |
| 2024-03-04     | 1           |
| 2024-03-05     | 1           |
| 2024-03-06     | 1           |
| 2024-03-07     | 1           |
| 2024-03-08     | 1           |
| 2024-03-09     | 1           |

-- EXPECTED
| sale_date  | revenue | rolling_7d |
|------------|---------|------------|
| 2024-03-01 | 1       | 1          |
| 2024-03-02 | 1       | 2          |
| 2024-03-03 | 1       | 3          |
| 2024-03-04 | 1       | 4          |
| 2024-03-05 | 1       | 5          |
| 2024-03-06 | 1       | 6          |
| 2024-03-07 | 1       | 7          |
| 2024-03-08 | 1       | 7          |
| 2024-03-09 | 1       | 7          |
