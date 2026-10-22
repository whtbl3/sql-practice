-- HIDDEN TESTS for problem window/13. No QUERY section: the problem's QUERY is used.

-- CASE one trading day in a month: open = close = that day
-- INPUT
daily_prices
| ticker | trade_date | close_price |
|--------|------------|-------------|
| SEN    | 2024-03-29 | 9.5         |

-- EXPECTED
| ticker | trade_date | close_price | month_open | month_close | pct_vs_open |
|--------|------------|-------------|------------|-------------|-------------|
| SEN    | 2024-03-29 | 9.5         | 9.5        | 9.5         | 0.0         |

-- CASE same month number in two years, rows out of order
-- INPUT
daily_prices
| ticker | trade_date | close_price |
|--------|------------|-------------|
| SEN    | 2025-01-10 | 30.0        |
| SEN    | 2024-01-31 | 20.0        |
| SEN    | 2024-01-05 | 25.0        |
| SEN    | 2025-01-02 | 24.0        |

-- EXPECTED
| ticker | trade_date | close_price | month_open | month_close | pct_vs_open |
|--------|------------|-------------|------------|-------------|-------------|
| SEN    | 2024-01-05 | 25.0        | 25.0       | 20.0        | 0.0         |
| SEN    | 2024-01-31 | 20.0        | 25.0       | 20.0        | -20.0       |
| SEN    | 2025-01-02 | 24.0        | 24.0       | 30.0        | 0.0         |
| SEN    | 2025-01-10 | 30.0        | 24.0       | 30.0        | 25.0        |
