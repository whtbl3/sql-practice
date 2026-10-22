-- Problem window/13: Monthly open and close next to every trading day  [Medium]
-- Pattern: FIRST_VALUE / LAST_VALUE with a full frame (ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
-- Variant: partition by ticker AND month; window/05 shows the trap, here it is part of a real report
--
-- Task: daily_prices holds the closing price of two (fictional) stocks per trading day. For every
--   row return ticker, trade_date, close_price, month_open (close_price of the FIRST trading day
--   of that ticker in that calendar month), month_close (close_price of the LAST trading day of
--   that ticker in that month) and pct_vs_open = (close_price / month_open - 1) * 100 rounded to
--   1 decimal. Sort by ticker, trade_date.
-- Learn: grinding/sql-common-pitfalls.md, mục F3

-- INPUT
daily_prices
| ticker | trade_date | close_price |
|--------|------------|-------------|
| SEN    | 2024-01-02 | 10.0        |
| SEN    | 2024-01-15 | 11.0        |
| SEN    | 2024-01-31 | 12.0        |
| SEN    | 2024-02-01 | 12.5        |
| SEN    | 2024-02-28 | 11.5        |
| LUA    | 2024-01-03 | 20.0        |
| LUA    | 2024-01-20 | 18.0        |

-- EXPECTED
| ticker | trade_date | close_price | month_open | month_close | pct_vs_open |
|--------|------------|-------------|------------|-------------|-------------|
| LUA    | 2024-01-03 | 20.0        | 20.0       | 18.0        | 0.0         |
| LUA    | 2024-01-20 | 18.0        | 20.0       | 18.0        | -10.0       |
| SEN    | 2024-01-02 | 10.0        | 10.0       | 12.0        | 0.0         |
| SEN    | 2024-01-15 | 11.0        | 10.0       | 12.0        | 10.0        |
| SEN    | 2024-01-31 | 12.0        | 10.0       | 12.0        | 20.0        |
| SEN    | 2024-02-01 | 12.5        | 12.5       | 11.5        | 0.0         |
| SEN    | 2024-02-28 | 11.5        | 12.5       | 11.5        | -8.0        |

-- QUERY
SELECT ticker, trade_date, close_price,
       FIRST_VALUE(close_price) OVER w AS month_open,
       LAST_VALUE(close_price)  OVER w AS month_close,   -- needs the full frame, or it returns the current row
       ROUND((close_price / FIRST_VALUE(close_price) OVER w - 1) * 100, 1) AS pct_vs_open
FROM daily_prices
WINDOW w AS (PARTITION BY ticker, DATE_TRUNC('month', trade_date)
             ORDER BY trade_date
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
ORDER BY ticker, trade_date;
