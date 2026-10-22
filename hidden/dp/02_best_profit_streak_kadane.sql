-- HIDDEN TESTS for problem dp/02. No QUERY section: the problem's QUERY is used.

-- CASE every day loses money: the best run is the single least bad day
-- INPUT
daily_profit
| day        | profit_m |
|------------|----------|
| 2024-03-01 | -3       |
| 2024-03-02 | -1       |
| 2024-03-03 | -2       |

-- EXPECTED
| start_day  | end_day    | total_profit |
|------------|------------|--------------|
| 2024-03-02 | 2024-03-02 | -1           |

-- CASE two runs with the same total: the earlier one wins
-- INPUT
daily_profit
| day        | profit_m |
|------------|----------|
| 2024-03-01 | 5        |
| 2024-03-02 | -10      |
| 2024-03-03 | 2        |
| 2024-03-04 | 3        |

-- EXPECTED
| start_day  | end_day    | total_profit |
|------------|------------|--------------|
| 2024-03-01 | 2024-03-01 | 5            |

-- CASE no days
-- INPUT
daily_profit
| day:date | profit_m:int |
|----------|--------------|

-- EXPECTED
| start_day:date | end_day:date | total_profit:numeric |
|----------------|--------------|----------------------|
