-- HIDDEN TESTS for problem func/05. No QUERY section: the problem's QUERY is used.

-- CASE holiday on a weekend is not subtracted twice
-- INPUT
holidays
| holiday_date:date | name:text |
|-------------------|-----------|
| 2024-01-06        | Sat event |

requests
| request_id:int | opened:date | closed:date |
|----------------|-------------|-------------|
| 1              | 2024-01-01  | 2024-01-07  |

-- EXPECTED
| request_id | days |
|------------|------|
| 1          | 5    |

-- CASE no holidays, same day
-- INPUT
holidays
| holiday_date:date | name:text |
|-------------------|-----------|

requests
| request_id:int | opened:date | closed:date |
|----------------|-------------|-------------|
| 1              | 2024-01-03  | 2024-01-03  |
| 2              | 2024-01-07  | 2024-01-07  |
| 3              | 2024-02-26  | 2024-03-04  |

-- EXPECTED
| request_id | days |
|------------|------|
| 1          | 1    |
| 2          | 0    |
| 3          | 6    |

-- CASE holiday on the first and last day
-- INPUT
holidays
| holiday_date:date | name:text |
|-------------------|-----------|
| 2024-04-29        | A         |
| 2024-05-01        | B         |

requests
| request_id:int | opened:date | closed:date |
|----------------|-------------|-------------|
| 1              | 2024-04-29  | 2024-05-01  |

-- EXPECTED
| request_id | days |
|------------|------|
| 1          | 1    |
