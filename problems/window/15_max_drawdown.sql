-- Problem window/15: Maximum drawdown of a fund  [Hard]
-- Pattern: Running MAX() OVER (ORDER BY date) as the peak so far + MAX(date) FILTER (...) OVER for the peak date
-- Variant: running MAX (not SUM); report the worst fall from a previous peak, with both dates
--
-- Task: fund_nav holds the daily net asset value per unit of a (fictional) Vietnamese equity fund.
--   On each day, peak = the highest nav on or before that day and drawdown = (nav / peak - 1) *
--   100. Return ONE row for the day with the lowest drawdown (earliest such day on a tie):
--   peak_date (the latest day on or before it whose nav equals its peak), peak_nav,
--   trough_date (that day), trough_nav and max_drawdown_pct rounded to 1 decimal. If nav never
--   falls, that is the first day with 0.0. No rows when fund_nav is empty.
-- Learn: grinding/sql-common-pitfalls.md, mục F4

-- INPUT
fund_nav
| trade_date | nav   |
|------------|-------|
| 2024-01-02 | 10.00 |
| 2024-01-03 | 10.50 |
| 2024-01-04 | 10.20 |
| 2024-01-05 | 9.45  |
| 2024-01-08 | 10.80 |
| 2024-01-09 | 10.26 |
| 2024-01-10 | 9.18  |
| 2024-01-11 | 11.00 |

-- EXPECTED
| peak_date  | peak_nav | trough_date | trough_nav | max_drawdown_pct |
|------------|----------|-------------|------------|------------------|
| 2024-01-08 | 10.80    | 2024-01-10  | 9.18       | -15.0            |

-- QUERY
-- write your query here
