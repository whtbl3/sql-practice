-- Problem subquery/09: Categories above the average category revenue  [Medium]
-- Pattern: HAVING with a subquery over a derived table
-- Variant: compare a group to the average of groups
--
-- Task: Return the categories whose total revenue is above the average TOTAL revenue of a category.
--   Sort by revenue DESC, category.
-- Learn: grinding/sql-subquery-window.md, mục S4

-- INPUT
sales
| category | amount |
|----------|--------|
| A        | 100    |
| A        | 200    |
| B        | 50     |
| C        | 400    |
| D        | 250    |

-- EXPECTED
| category | revenue |
|----------|---------|
| C        | 400     |
| A        | 300     |

-- QUERY
SELECT category, SUM(amount) AS revenue
FROM sales
GROUP BY category
HAVING SUM(amount) > (
    SELECT AVG(category_total)
    FROM (SELECT SUM(amount) AS category_total FROM sales GROUP BY category) totals
)
ORDER BY revenue DESC, category;

-- ===== Giải thích =====
-- Cần so tổng của từng nhóm với TRUNG BÌNH CÁC TỔNG.
--   Tổng mỗi nhóm: 300, 50, 400, 250, trung bình 250. Chỉ C và A lớn hơn.
-- Lỗi hay gặp: HAVING SUM(amount) > (SELECT AVG(amount) FROM sales).
--   AVG(amount) là trung bình mỗi DÒNG = 1000 / 5 = 200, khác trung bình mỗi NHÓM.
--   Khi đó D (250) bị tính nhầm là "trên trung bình".
-- HAVING lọc SAU khi gộp nên dùng được SUM(amount), còn WHERE thì không.
-- Cách khác: dùng window trên kết quả gộp:
--   SELECT ... , AVG(SUM(amount)) OVER () AS avg_total ... GROUP BY category
--   rồi lọc ở truy vấn ngoài.
