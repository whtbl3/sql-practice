-- Problem subquery/06: Third highest salary per department, no window  [Hard]
-- Pattern: Correlated COUNT(DISTINCT) subquery (classic Nth-highest)
-- Variant: the keywords OVER, LIMIT and OFFSET are forbidden
--
-- Task: For each department return the third highest DISTINCT salary as third_highest. Departments
--   with fewer than 3 distinct salaries are left out. NULL salaries are ignored. Window functions,
--   LIMIT and OFFSET are rejected. Sort by department.
-- @forbid: \bOVER\s*\(|\bLIMIT\b|\bOFFSET\b
-- Learn: grinding/sql-subquery.md, V2

-- INPUT
employees
| name | department | salary |
|------|------------|--------|
| a    | IT         | 100    |
| b    | IT         | 200    |
| c    | IT         | 200    |
| d    | IT         | 300    |
| e    | IT         | 400    |
| f    | HR         | 50     |
| g    | HR         | 60     |
| h    | Ops        | 10     |
| i    | Ops        | 20     |
| j    | Ops        | 30     |

-- EXPECTED
| department | third_highest |
|------------|---------------|
| IT         | 200           |
| Ops        | 10            |

-- QUERY
SELECT DISTINCT e.department, e.salary AS third_highest
FROM employees e
WHERE e.salary IS NOT NULL
  AND (SELECT COUNT(DISTINCT x.salary)
       FROM employees x
       WHERE x.department = e.department
         AND x.salary > e.salary) = 2
ORDER BY e.department;

-- ===== Giải thích =====
-- Ý tưởng: lương L là cao thứ 3 (distinct) khi có ĐÚNG 2 mức lương khác nhau lớn hơn L
--   trong cùng phòng. Subquery tương quan đếm số mức lớn hơn cho từng dòng.
--   Tổng quát: cao thứ N thì đếm được N - 1.
-- Vì sao COUNT(DISTINCT): IT có hai người 200. Nếu đếm COUNT(*) thì với lương 100 ra 4 chứ không phải 3,
--   thứ hạng bị lệch.
-- Vì sao SELECT DISTINCT ở ngoài: hai nhân viên cùng lương 200 đều thỏa điều kiện, nên phải gộp
--   thành một dòng.
-- Độ phức tạp: subquery chạy cho từng dòng, khoảng O(n^2) trong mỗi phòng. Nên biết vì phỏng vấn
--   hay hỏi, nhưng thực tế dùng DENSE_RANK() (xem topn/01) gọn và nhanh hơn.
