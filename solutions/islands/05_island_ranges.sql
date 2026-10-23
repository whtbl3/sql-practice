-- Problem islands/05: Blocks of consecutive working days  [Medium]
-- Pattern: Gaps & Islands (value - ROW_NUMBER)
-- Variant: output EVERY island with its start, end and length, not only the longest
--
-- Task: For each employee list every block of consecutive working days as start_date, end_date
--   and days (inclusive; several rows on one day count once). Return employee, start_date,
--   end_date, days; sort by employee, then start_date.
-- Learn: grinding/sql-gaps-islands.md, B4

-- INPUT
shifts
| employee:text | work_date:date |
|---------------|----------------|
| Ann           | 2024-03-01     |
| Ann           | 2024-03-02     |
| Ann           | 2024-03-03     |
| Ann           | 2024-03-06     |
| Bob           | 2024-03-04     |
| Bob           | 2024-03-05     |
| Bob           | 2024-03-05     |

-- EXPECTED
| employee | start_date | end_date   | days |
|----------|------------|------------|------|
| Ann      | 2024-03-01 | 2024-03-03 | 3    |
| Ann      | 2024-03-06 | 2024-03-06 | 1    |
| Bob      | 2024-03-04 | 2024-03-05 | 2    |

-- QUERY
WITH d AS (
  SELECT DISTINCT employee, work_date FROM shifts
),
g AS (
  SELECT employee, work_date,
         work_date - (ROW_NUMBER() OVER (PARTITION BY employee ORDER BY work_date))::int AS grp
  FROM d
)
SELECT employee, MIN(work_date) AS start_date, MAX(work_date) AS end_date, COUNT(*) AS days
FROM g
GROUP BY employee, grp
ORDER BY employee, start_date;
