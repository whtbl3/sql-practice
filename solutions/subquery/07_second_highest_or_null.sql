-- Problem subquery/07: Second highest salary, or NULL  [Medium]
-- Pattern: Scalar subquery returns NULL on an empty result
-- Variant: always one row
--
-- Task: Return exactly one row with one column second_highest: the second highest DISTINCT salary.
--   If it does not exist, the row must still be returned with NULL. NULL salaries are ignored.
-- Learn: grinding/sql-subquery.md, B1

-- INPUT
employees
| name | salary |
|------|--------|
| Ann  | 100    |
| Bob  | 300    |
| Cy   | 200    |
| Dee  | 300    |

-- EXPECTED
| second_highest |
|----------------|
| 200            |

-- QUERY
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);

-- ===== Giải thích =====
-- Ý tưởng: lương cao thứ 2 = lương lớn nhất trong những lương NHỎ HƠN lương lớn nhất.
-- Vì sao luôn ra 1 dòng: truy vấn có hàm gộp mà không có GROUP BY luôn trả đúng 1 dòng,
--   và MAX của tập rỗng là NULL.
-- Lỗi hay gặp: SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT 1 OFFSET 1.
--   Khi chỉ có 1 mức lương, truy vấn này trả về 0 DÒNG, không phải một dòng NULL.
--   Sửa bằng cách bọc nó làm scalar subquery:
--   SELECT (SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT 1 OFFSET 1) AS second_highest
--   Scalar subquery không có dòng nào thì trả về NULL.
-- Chú ý: scalar subquery trả về HƠN 1 dòng thì báo lỗi
--   (more than one row returned by a subquery used as an expression).
