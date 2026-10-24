-- Problem window/05: Top and lowest earner on every row  [Medium]
-- Pattern: FIRST_VALUE / LAST_VALUE and the frame trap
-- Variant: value functions
--
-- Task: For every employee return name, department, salary, top_earner (name of the highest-paid
--   employee in the department) and lowest_earner (name of the lowest-paid). For ties, pick the
--   alphabetically first name. Sort by department, name.
-- Learn: grinding/sql-window.md, V1

-- INPUT
employees
| name | department | salary |
|------|------------|--------|
| Ann  | IT         | 5000   |
| Bob  | IT         | 7000   |
| Cy   | IT         | 7000   |
| Dan  | IT         | 4000   |
| Eve  | HR         | 3000   |
| Fay  | HR         | 3500   |

-- EXPECTED
| name | department | salary | top_earner | lowest_earner |
|------|------------|--------|------------|---------------|
| Eve  | HR         | 3000   | Fay        | Eve           |
| Fay  | HR         | 3500   | Fay        | Eve           |
| Ann  | IT         | 5000   | Bob        | Dan           |
| Bob  | IT         | 7000   | Bob        | Dan           |
| Cy   | IT         | 7000   | Bob        | Dan           |
| Dan  | IT         | 4000   | Bob        | Dan           |

-- QUERY
-- write your query here
