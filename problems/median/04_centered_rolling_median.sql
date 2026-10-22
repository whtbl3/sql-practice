-- Problem median/04: Centered 5-row rolling median vs rolling average  [Hard]
-- Pattern: Median: PERCENTILE_CONT is not a window function -> ROW_NUMBER + LATERAL over the 5 neighbours
-- Variant: a rolling median (robust to spikes) next to the rolling AVG ... OVER (ROWS 2 PRECEDING AND 2 FOLLOWING)
--
-- Task: daily_sales holds one store's revenue in millions of VND (revenue_m), one row per day
--   with sales (some days are missing; neighbours are counted in ROWS, not in calendar days).
--   For every row the window is the row itself plus up to 2 rows before and 2 rows after it in
--   sale_date order (only 3 or 4 rows near the ends). Return sale_date, revenue_m, rolling_avg
--   (average of the window) and rolling_median (median of the window; average of the two middle
--   values when the window has 4 rows), both rounded to 1 decimal. Sort by sale_date.
-- Learn: grinding/sql-analytics-patterns.md, mục 10.5

-- INPUT
daily_sales
| sale_date  | revenue_m |
|------------|-----------|
| 2024-02-01 | 100       |
| 2024-02-02 | 120       |
| 2024-02-03 | 110       |
| 2024-02-04 | 900       |
| 2024-02-05 | 130       |
| 2024-02-06 | 125       |
| 2024-02-08 | 140       |
| 2024-02-09 | 135       |

-- EXPECTED
| sale_date  | revenue_m | rolling_avg | rolling_median |
|------------|-----------|-------------|----------------|
| 2024-02-01 | 100       | 110.0       | 110.0          |
| 2024-02-02 | 120       | 307.5       | 115.0          |
| 2024-02-03 | 110       | 272.0       | 120.0          |
| 2024-02-04 | 900       | 277.0       | 125.0          |
| 2024-02-05 | 130       | 281.0       | 130.0          |
| 2024-02-06 | 125       | 286.0       | 135.0          |
| 2024-02-08 | 140       | 132.5       | 132.5          |
| 2024-02-09 | 135       | 133.3       | 135.0          |

-- QUERY
-- write your query here
