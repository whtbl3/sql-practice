-- Problem topn/03: Top 2 salary ranks per department (RANK)  [Medium]
-- Pattern: Top-N per group + ties (RANK)
-- Variant: RANK skips ranks after ties, unlike DENSE_RANK in topn/01
--
-- Task: For each department return the employees whose salary ranks in the top 2 using standard
--   RANK (people with equal salaries share a rank and the next rank is skipped). Ignore employees
--   whose salary is NULL. Return department, name, salary; sort by department, then salary
--   descending, then name.
-- Learn: grinding/sql-top-n.md, B1–B3

-- INPUT
employees
| emp_id:int | name:text | department:text | salary:int |
|------------|-----------|-----------------|------------|
| 1          | A         | IT              | 500        |
| 2          | B         | IT              | 500        |
| 3          | C         | IT              | 400        |
| 4          | D         | IT              | 300        |
| 5          | E         | HR              | 300        |
| 6          | F         | HR              | 200        |
| 7          | G         | HR              | 200        |
| 8          | H         | HR              | 100        |
| 9          | I         | Sales           | 900        |

-- EXPECTED
| department | name | salary |
|------------|------|--------|
| HR         | E    | 300    |
| HR         | F    | 200    |
| HR         | G    | 200    |
| IT         | A    | 500    |
| IT         | B    | 500    |
| Sales      | I    | 900    |

-- QUERY
-- write your query here
