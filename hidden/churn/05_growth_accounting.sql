-- HIDDEN TESTS for problem churn/05. No QUERY section: the problem's QUERY is used.

-- CASE no activity: six empty months
-- INPUT
activity
| user_id:int | activity_date:date |
|-------------|--------------------|

-- EXPECTED
| month   | mau | new_users | retained | resurrected | churned | quick_ratio |
|---------|-----|-----------|----------|-------------|---------|-------------|
| 2024-01 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-02 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-03 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-04 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-05 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-06 | 0   | 0         | 0        | 0           | 0       | NULL        |

-- CASE only history in 2023: the December user churns in January, nothing else
-- INPUT
activity
| user_id | activity_date |
|---------|---------------|
| 1       | 2023-12-31    |
| 2       | 2023-06-01    |

-- EXPECTED
| month   | mau | new_users | retained | resurrected | churned | quick_ratio |
|---------|-----|-----------|----------|-------------|---------|-------------|
| 2024-01 | 0   | 0         | 0        | 0           | 1       | 0.00        |
| 2024-02 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-03 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-04 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-05 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-06 | 0   | 0         | 0        | 0           | 0       | NULL        |

-- CASE only activity after the report window
-- INPUT
activity
| user_id | activity_date |
|---------|---------------|
| 1       | 2024-07-01    |
| 1       | 2024-08-01    |

-- EXPECTED
| month   | mau | new_users | retained | resurrected | churned | quick_ratio |
|---------|-----|-----------|----------|-------------|---------|-------------|
| 2024-01 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-02 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-03 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-04 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-05 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-06 | 0   | 0         | 0        | 0           | 0       | NULL        |

-- CASE quick ratio with a fraction: 2 gained, 3 lost
-- INPUT
activity
| user_id | activity_date |
|---------|---------------|
| 1       | 2024-01-10    |
| 2       | 2024-01-10    |
| 3       | 2024-01-10    |
| 4       | 2023-09-10    |
| 4       | 2024-02-10    |
| 5       | 2024-02-10    |

-- EXPECTED
| month   | mau | new_users | retained | resurrected | churned | quick_ratio |
|---------|-----|-----------|----------|-------------|---------|-------------|
| 2024-01 | 3   | 3         | 0        | 0           | 0       | NULL        |
| 2024-02 | 2   | 1         | 0        | 1           | 3       | 0.67        |
| 2024-03 | 0   | 0         | 0        | 0           | 2       | 0.00        |
| 2024-04 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-05 | 0   | 0         | 0        | 0           | 0       | NULL        |
| 2024-06 | 0   | 0         | 0        | 0           | 0       | NULL        |
