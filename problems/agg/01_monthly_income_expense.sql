-- Problem agg/01: Monthly income and expense report  [Medium]
-- Pattern: GROUP BY + conditional SUM, then a running total over the groups
-- Variant: conditional aggregation
--
-- Task: Per month ('YYYY-MM') return total_income, total_expense (both 0 if none), balance =
--   income - expense, and cumulative_balance = running sum of balance up to that month. Rows of
--   type 'Income' and 'Expense'. Sort by month.

-- INPUT
transactions
| txn_date   | type    | amount |
|------------|---------|--------|
| 2024-01-05 | Income  | 1000   |
| 2024-01-10 | Expense | 400    |
| 2024-01-20 | Expense | 100    |
| 2024-02-03 | Income  | 500    |
| 2024-02-15 | Expense | 700    |
| 2024-03-01 | Expense | 50     |

-- EXPECTED
| month   | total_income | total_expense | balance | cumulative_balance |
|---------|--------------|---------------|---------|--------------------|
| 2024-01 | 1000         | 500           | 500     | 500                |
| 2024-02 | 500          | 700           | -200    | 300                |
| 2024-03 | 0            | 50            | -50     | 250                |

-- QUERY
-- write your query here
WITH monthly AS (
  SELECT
    TO_CHAR(txn_date, 'YYYY-MM') AS month,
    COALESCE(SUM(amount) FILTER (WHERE type = 'Income'), 0) AS total_income,
    COALESCE(SUM(amount) FILTER (WHERE type = 'Expense'), 0) AS total_expense
  FROM transactions
  GROUP BY TO_CHAR(txn_date, 'YYYY-MM')
)
SELECT
  month,
  total_income,
  total_expense,
  total_income - total_expense AS balance,
  SUM(total_income - total_expense) OVER (ORDER BY month) AS cumulative_balance
FROM monthly
ORDER BY month