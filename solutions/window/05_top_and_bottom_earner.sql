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
SELECT name, department, salary,
       FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name) AS top_earner,
       FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary ASC,  name) AS lowest_earner
FROM employees
ORDER BY department, name;

-- ===== Giải thích =====
-- Ý tưởng: FIRST_VALUE(name) lấy name của dòng ĐẦU TIÊN trong cửa sổ đã sắp xếp.
--   Sắp DESC thì dòng đầu là người lương cao nhất, sắp ASC thì là người thấp nhất.
-- Cái bẫy của LAST_VALUE: nếu viết
--   LAST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name)
--   thì frame mặc định chỉ chạy TỚI DÒNG HIỆN TẠI, nên "dòng cuối" chính là dòng đang xét
--   (mỗi người tự thấy mình là thấp nhất). Muốn đúng phải mở frame ra cả nhóm:
--   ... ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
-- Mẹo: đảo chiều sắp xếp rồi dùng FIRST_VALUE thì không phải nhớ frame.
-- Phá hòa: thêm name vào ORDER BY để chọn được tên đứng đầu bảng chữ cái.
