-- HIDDEN TESTS for problem misc/03. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
monthly_revenue
| month:date | revenue:int |
|------------|-------------|

-- EXPECTED
| month | revenue | prev_revenue | pct_change |
|-------|---------|--------------|------------|

-- CASE single month
-- INPUT
monthly_revenue
| month:date | revenue:int |
|------------|-------------|
| 2024-05-01 | 70          |

-- EXPECTED
| month      | revenue | prev_revenue | pct_change |
|------------|---------|--------------|------------|
| 2024-05-01 | 70      | NULL         | NULL       |

-- CASE previous revenue of zero gives NULL
-- INPUT
monthly_revenue
| month:date | revenue:int |
|------------|-------------|
| 2024-01-01 | 0           |
| 2024-02-01 | 50          |
| 2024-03-01 | 25          |

-- EXPECTED
| month      | revenue | prev_revenue | pct_change |
|------------|---------|--------------|------------|
| 2024-01-01 | 0       | NULL         | NULL       |
| 2024-02-01 | 50      | 0            | NULL       |
| 2024-03-01 | 25      | 50           | -50.0      |
