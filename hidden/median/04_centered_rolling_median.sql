-- HIDDEN TESTS for problem median/04. No QUERY section: the problem's QUERY is used.

-- CASE no sales
-- INPUT
daily_sales
| sale_date:date | revenue_m:int |
|----------------|---------------|

-- EXPECTED
| sale_date:date | revenue_m:int | rolling_avg:numeric | rolling_median:numeric |
|----------------|---------------|---------------------|------------------------|

-- CASE one and two rows: the window is the whole table
-- INPUT
daily_sales
| sale_date  | revenue_m |
|------------|-----------|
| 2024-03-02 | 7         |
| 2024-03-01 | 4         |

-- EXPECTED
| sale_date  | revenue_m | rolling_avg | rolling_median |
|------------|-----------|-------------|----------------|
| 2024-03-01 | 4         | 5.5         | 5.5            |
| 2024-03-02 | 7         | 5.5         | 5.5            |

-- CASE a 30-day hole counts as neighbouring rows, not as empty days
-- INPUT
daily_sales
| sale_date  | revenue_m |
|------------|-----------|
| 2024-01-01 | 10        |
| 2024-01-02 | 20        |
| 2024-02-01 | 30        |
| 2024-02-02 | 40        |
| 2024-02-03 | 1000      |
| 2024-02-04 | 50        |

-- EXPECTED
| sale_date  | revenue_m | rolling_avg | rolling_median |
|------------|-----------|-------------|----------------|
| 2024-01-01 | 10        | 20.0        | 20.0           |
| 2024-01-02 | 20        | 25.0        | 25.0           |
| 2024-02-01 | 30        | 220.0       | 30.0           |
| 2024-02-02 | 40        | 228.0       | 40.0           |
| 2024-02-03 | 1000      | 280.0       | 45.0           |
| 2024-02-04 | 50        | 363.3       | 50.0           |
