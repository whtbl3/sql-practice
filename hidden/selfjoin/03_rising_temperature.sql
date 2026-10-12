-- HIDDEN TESTS for problem selfjoin/03. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
weather
| record_date:date | temp:int |
|------------------|----------|

-- EXPECTED
| record_date |
|-------------|

-- CASE equal temperature is not warmer
-- INPUT
weather
| record_date:date | temp:int |
|------------------|----------|
| 2024-01-01       | 10       |
| 2024-01-02       | 10       |

-- EXPECTED
| record_date |
|-------------|

-- CASE across a leap day and a month boundary
-- INPUT
weather
| record_date:date | temp:int |
|------------------|----------|
| 2024-02-28       | 1        |
| 2024-02-29       | 2        |
| 2024-03-01       | 3        |
| 2024-03-03       | 9        |

-- EXPECTED
| record_date |
|-------------|
| 2024-02-29  |
| 2024-03-01  |
