-- HIDDEN TESTS for problem churn/04. No QUERY section: the problem's QUERY is used.

-- CASE no activity
-- INPUT
activity
| user_id:int | activity_date:date |
|-------------|--------------------|

-- EXPECTED
| month:text | user_id:int | status:text |
|------------|-------------|-------------|

-- CASE a month where nobody is active still produces churned rows, then a comeback across the year
-- INPUT
activity
| user_id | activity_date |
|---------|---------------|
| 1       | 2023-11-05    |
| 2       | 2023-11-06    |
| 2       | 2024-01-15    |

-- EXPECTED
| month   | user_id | status      |
|---------|---------|-------------|
| 2023-11 | 1       | new         |
| 2023-11 | 2       | new         |
| 2023-12 | 1       | churned     |
| 2023-12 | 2       | churned     |
| 2024-01 | 2       | resurrected |

-- CASE churned only once, no rows while silent, nothing after the last report month
-- INPUT
activity
| user_id | activity_date |
|---------|---------------|
| 9       | 2024-01-01    |
| 8       | 2024-04-30    |

-- EXPECTED
| month   | user_id | status  |
|---------|---------|---------|
| 2024-01 | 9       | new     |
| 2024-02 | 9       | churned |
| 2024-04 | 8       | new     |
