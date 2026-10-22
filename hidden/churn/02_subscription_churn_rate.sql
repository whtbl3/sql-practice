-- HIDDEN TESTS for problem churn/02. No QUERY section: the problem's QUERY is used.

-- CASE no subscriptions: six months, all zero
-- INPUT
subscriptions
| sub_id:int | customer_id:int | plan:text | start_date:date | end_date:date |
|------------|-----------------|-----------|-----------------|---------------|

-- EXPECTED
| month   | active_start | churned | churn_rate_pct |
|---------|--------------|---------|----------------|
| 2024-01 | 0            | 0       | NULL           |
| 2024-02 | 0            | 0       | NULL           |
| 2024-03 | 0            | 0       | NULL           |
| 2024-04 | 0            | 0       | NULL           |
| 2024-05 | 0            | 0       | NULL           |
| 2024-06 | 0            | 0       | NULL           |

-- CASE ends on the 1st of a month: churn is counted in the month before
-- INPUT
subscriptions
| sub_id | customer_id | plan  | start_date | end_date   |
|--------|-------------|-------|------------|------------|
| 1      | 1           | Basic | 2024-01-01 | 2024-02-01 |
| 2      | 2           | Basic | 2024-03-01 | 2024-03-02 |
| 3      | 3           | Basic | 2024-02-01 | 2024-07-01 |

-- EXPECTED
| month   | active_start | churned | churn_rate_pct |
|---------|--------------|---------|----------------|
| 2024-01 | 1            | 1       | 100.0          |
| 2024-02 | 1            | 0       | 0.0            |
| 2024-03 | 2            | 1       | 50.0           |
| 2024-04 | 1            | 0       | 0.0            |
| 2024-05 | 1            | 0       | 0.0            |
| 2024-06 | 1            | 1       | 100.0          |

-- CASE subscriptions outside the window and one ending right after it
-- INPUT
subscriptions
| sub_id | customer_id | plan   | start_date | end_date   |
|--------|-------------|--------|------------|------------|
| 1      | 1           | Basic  | 2023-01-01 | 2023-12-31 |
| 2      | 2           | Basic  | 2024-07-01 | NULL       |
| 3      | 3           | Family | 2023-12-31 | 2024-01-01 |
| 4      | 4           | Family | 2024-05-31 | 2024-07-15 |

-- EXPECTED
| month   | active_start | churned | churn_rate_pct |
|---------|--------------|---------|----------------|
| 2024-01 | 0            | 0       | NULL           |
| 2024-02 | 0            | 0       | NULL           |
| 2024-03 | 0            | 0       | NULL           |
| 2024-04 | 0            | 0       | NULL           |
| 2024-05 | 0            | 0       | NULL           |
| 2024-06 | 1            | 0       | 0.0            |
