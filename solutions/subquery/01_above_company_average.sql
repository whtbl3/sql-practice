-- Problem subquery/01: Employees above the company average  [Easy]
-- Pattern: Scalar subquery in WHERE
-- Variant: non-correlated subquery
--
-- Task: Return employees whose salary is above the average salary of all employees (NULL salaries
--   are not part of the average). Sort by salary DESC, name.
-- Learn: grinding/sql-subquery.md, B1

-- INPUT
employees
| name | salary |
|------|--------|
| Ann  | 5000   |
| Bob  | 7000   |
| Cy   | 6000   |
| Dee  | 4000   |
| Eli  | 8000   |

-- EXPECTED
| name | salary |
|------|--------|
| Eli  | 8000   |
| Bob  | 7000   |

-- QUERY
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC, name;

-- ===== Giải thích =====
-- Ý tưởng: (SELECT AVG(salary) FROM employees) trả về đúng MỘT giá trị (scalar subquery),
--   nên dùng được như một hằng số trong WHERE. Subquery này KHÔNG phụ thuộc dòng bên ngoài
--   (non-correlated): DB tính nó một lần rồi dùng lại.
-- Lỗi hay gặp: viết WHERE salary > AVG(salary). Không được, vì hàm gộp không dùng được trong WHERE
--   (WHERE chạy TRƯỚC khi gộp).
-- Ghi nhớ: AVG bỏ qua NULL. Người lương NULL cũng không bao giờ lọt qua salary > ...
--   vì NULL > x là UNKNOWN.
