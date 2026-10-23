-- Problem window/08: Top 2 products per month  [Medium]
-- Pattern: Window over GROUP BY result, then filter in an outer query
-- Variant: rank aggregated groups
--
-- Task: Total qty per month ('YYYY-MM') and product, ranked within the month by total_qty DESC with
--   DENSE_RANK. Return only rank 1 and 2: month, product, total_qty, rank_in_month. Sort by month,
--   rank_in_month, product.
-- Learn: grinding/sql-window.md, B5

-- INPUT
sales
| sale_date  | product | qty |
|------------|---------|-----|
| 2024-01-03 | A       | 5   |
| 2024-01-20 | A       | 5   |
| 2024-01-05 | B       | 8   |
| 2024-01-07 | C       | 10  |
| 2024-02-01 | A       | 3   |
| 2024-02-02 | B       | 4   |
| 2024-02-10 | B       | 3   |
| 2024-02-11 | C       | 1   |

-- EXPECTED
| month   | product | total_qty | rank_in_month |
|---------|---------|-----------|---------------|
| 2024-01 | A       | 10        | 1             |
| 2024-01 | C       | 10        | 1             |
| 2024-01 | B       | 8         | 2             |
| 2024-02 | B       | 7         | 1             |
| 2024-02 | A       | 3         | 2             |

-- QUERY
WITH ranked AS (
    SELECT TO_CHAR(sale_date, 'YYYY-MM') AS month,
           product,
           SUM(qty) AS total_qty,
           DENSE_RANK() OVER (PARTITION BY TO_CHAR(sale_date, 'YYYY-MM')
                              ORDER BY SUM(qty) DESC) AS rank_in_month
    FROM sales
    GROUP BY TO_CHAR(sale_date, 'YYYY-MM'), product
)
SELECT month, product, total_qty, rank_in_month
FROM ranked
WHERE rank_in_month <= 2
ORDER BY month, rank_in_month, product;

-- ===== Giải thích =====
-- Thứ tự thực thi logic: FROM, WHERE, GROUP BY, HAVING, rồi mới đến WINDOW, SELECT, ORDER BY.
--   Do đó window function chạy SAU GROUP BY và được dùng hàm gộp bên trong:
--   ORDER BY SUM(qty) DESC nghĩa là xếp hạng theo tổng của nhóm.
-- Lỗi hay gặp 1: viết WHERE rank_in_month <= 2 ngay trong cùng câu SELECT. Không được, vì WHERE
--   chạy TRƯỚC khi window được tính. Phải bọc vào CTE hoặc subquery rồi lọc ở ngoài.
--   (Lọc trên kết quả GROUP BY thì dùng HAVING, nhưng HAVING cũng không thấy window function.)
-- Lỗi hay gặp 2: dùng ROW_NUMBER thì A và C (cùng 10) chỉ còn một sản phẩm hạng 1.
