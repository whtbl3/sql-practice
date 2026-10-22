-- HIDDEN TESTS for problem window/16. No QUERY section: the problem's QUERY is used.

-- CASE one tick holds for the whole session
-- INPUT
ticks
| ts                  | price |
|---------------------|-------|
| 2024-06-03 09:00:00 | 55.50 |

-- EXPECTED
| twap  | simple_avg |
|-------|------------|
| 55.50 | 55.50      |

-- CASE many quick ticks barely move the TWAP; rows out of order
-- INPUT
ticks
| ts                  | price |
|---------------------|-------|
| 2024-06-03 11:29:59 | 90.00 |
| 2024-06-03 09:00:00 | 50.00 |
| 2024-06-03 11:29:58 | 90.00 |
| 2024-06-03 11:29:57 | 90.00 |

-- EXPECTED
| twap  | simple_avg |
|-------|------------|
| 50.01 | 80.00      |
