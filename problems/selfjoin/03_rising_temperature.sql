-- Problem selfjoin/03: Warmer than the previous day  [Medium]
-- Pattern: Self join on date arithmetic
-- Variant: adjacent rows
--
-- Task: Return the record_date of every day whose temperature is higher than the temperature on
--   the previous calendar day. A missing previous day means no comparison. Sort by record_date.

-- INPUT
weather
| record_date | temp |
|-------------|------|
| 2024-01-01  | 10   |
| 2024-01-02  | 15   |
| 2024-01-03  | 12   |
| 2024-01-05  | 20   |
| 2024-01-06  | 25   |

-- EXPECTED
| record_date |
|-------------|
| 2024-01-02  |
| 2024-01-06  |

-- QUERY
-- write your query here
