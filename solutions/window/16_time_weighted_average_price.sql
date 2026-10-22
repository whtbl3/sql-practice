-- Problem window/16: Time-weighted average price (TWAP) of a session  [Hard]
-- Pattern: LEAD(ts, 1, session end) -> duration of each price -> SUM(price * seconds) / SUM(seconds)
-- Variant: each price holds until the next tick; compare with the plain AVG of the ticks
--
-- Task: ticks holds the price updates of one (fictional) stock during the morning session
--   2024-06-03 09:00:00 to 11:30:00. The first tick is at 09:00:00. Each price is valid from its
--   tick until the next tick, and the last one until 11:30:00. Return ONE row: twap = sum of
--   (price * seconds it was valid) / total seconds, and simple_avg = AVG of the tick prices, both
--   rounded to 2 decimals.
-- Learn: grinding/sql-common-pitfalls.md, mục F5

-- INPUT
ticks
| ts                  | price  |
|---------------------|--------|
| 2024-06-03 09:00:00 | 100.00 |
| 2024-06-03 09:30:00 | 102.00 |
| 2024-06-03 09:31:00 | 110.00 |
| 2024-06-03 09:32:00 | 102.00 |
| 2024-06-03 10:30:00 | 101.00 |
| 2024-06-03 11:00:00 | 103.00 |

-- EXPECTED
| twap   | simple_avg |
|--------|------------|
| 101.65 | 103.00     |

-- QUERY
WITH spans AS (
  SELECT price,
         EXTRACT(EPOCH FROM LEAD(ts, 1, TIMESTAMP '2024-06-03 11:30:00') OVER (ORDER BY ts) - ts) AS secs
  FROM ticks
)
SELECT ROUND(SUM(price * secs) / NULLIF(SUM(secs), 0), 2) AS twap,     -- weight = how long the price held
       ROUND(AVG(price), 2)                              AS simple_avg   -- every tick weighs the same
FROM spans;
