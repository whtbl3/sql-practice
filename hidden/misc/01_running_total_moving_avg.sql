-- HIDDEN TESTS for problem misc/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
daily_sales
| sale_date:date | amount:int |
|----------------|------------|

-- EXPECTED
| sale_date | amount | running_total | moving_avg_3 |
|-----------|--------|---------------|--------------|

-- CASE single day
-- INPUT
daily_sales
| sale_date:date | amount:int |
|----------------|------------|
| 2024-01-01     | 100        |

-- EXPECTED
| sale_date  | amount | running_total | moving_avg_3 |
|------------|--------|---------------|--------------|
| 2024-01-01 | 100    | 100           | 100.00       |

-- CASE shuffled insert order, zero and negative amounts
-- INPUT
daily_sales
| sale_date:date | amount:int |
|----------------|------------|
| 2024-01-03     | 300        |
| 2024-01-01     | 100        |
| 2024-01-02     | 0          |
| 2024-01-04     | -50        |

-- EXPECTED
| sale_date  | amount | running_total | moving_avg_3 |
|------------|--------|---------------|--------------|
| 2024-01-01 | 100    | 100           | 100.00       |
| 2024-01-02 | 0      | 100           | 50.00        |
| 2024-01-03 | 300    | 400           | 133.33       |
| 2024-01-04 | -50    | 350           | 83.33        |

-- CASE rounding of the average
-- INPUT
daily_sales
| sale_date:date | amount:int |
|----------------|------------|
| 2024-02-01     | 1          |
| 2024-02-02     | 1          |
| 2024-02-03     | 2          |
| 2024-02-04     | 2          |

-- EXPECTED
| sale_date  | amount | running_total | moving_avg_3 |
|------------|--------|---------------|--------------|
| 2024-02-01 | 1      | 1             | 1.00         |
| 2024-02-02 | 1      | 2             | 1.00         |
| 2024-02-03 | 2      | 4             | 1.33         |
| 2024-02-04 | 2      | 6             | 1.67         |
