-- HIDDEN TESTS for problem window/15. No QUERY section: the problem's QUERY is used.

-- CASE nav only goes up: drawdown 0 on the first day
-- INPUT
fund_nav
| trade_date | nav   |
|------------|-------|
| 2024-01-02 | 10.00 |
| 2024-01-03 | 10.10 |
| 2024-01-04 | 10.20 |

-- EXPECTED
| peak_date  | peak_nav | trough_date | trough_nav | max_drawdown_pct |
|------------|----------|-------------|------------|------------------|
| 2024-01-02 | 10.00    | 2024-01-02  | 10.00      | 0.0              |

-- CASE the same peak value twice: the peak date is the later one
-- INPUT
fund_nav
| trade_date | nav   |
|------------|-------|
| 2024-01-02 | 12.00 |
| 2024-01-03 | 11.00 |
| 2024-01-04 | 12.00 |
| 2024-01-05 | 9.00  |
| 2024-01-08 | 9.00  |

-- EXPECTED
| peak_date  | peak_nav | trough_date | trough_nav | max_drawdown_pct |
|------------|----------|-------------|------------|------------------|
| 2024-01-04 | 12.00    | 2024-01-05  | 9.00       | -25.0            |
