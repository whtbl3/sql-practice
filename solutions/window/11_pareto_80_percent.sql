-- Problem window/11: Products that make up 80% of revenue  [Hard]
-- Pattern: Running SUM / total SUM OVER () (Pareto analysis)
-- Variant: cumulative share
--
-- Task: Order products by revenue DESC (ties by product). cumulative_pct = running revenue up to and
--   including the product, as % of total revenue (1 decimal). Return the products needed to reach
--   80%: every product whose cumulative share BEFORE adding it is below 80. Sort by revenue DESC,
--   product.
-- Learn: grinding/sql-window.md, B3

-- INPUT
product_sales
| product | revenue |
|---------|---------|
| A       | 500     |
| B       | 300     |
| C       | 100     |
| D       | 60      |
| E       | 40      |

-- EXPECTED
| product | revenue | cumulative_pct |
|---------|---------|----------------|
| A       | 500     | 50.0           |
| B       | 300     | 80.0           |

-- QUERY
WITH running AS (
    SELECT product, revenue,
           SUM(revenue) OVER w AS running_sum,
           SUM(revenue) OVER () AS total
    FROM product_sales
    WINDOW w AS (ORDER BY revenue DESC, product ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
SELECT product, revenue,
       ROUND(100.0 * running_sum / total, 1) AS cumulative_pct
FROM running
WHERE 100.0 * (running_sum - revenue) / total < 80
ORDER BY revenue DESC, product;

-- ===== Giải thích =====
-- Hai cửa sổ trong cùng một câu:
--   SUM(revenue) OVER (ORDER BY ...) là tổng DỒN tới dòng hiện tại.
--   SUM(revenue) OVER ()             là tổng của TOÀN bảng (OVER rỗng nghĩa là mọi dòng).
-- "Phần trăm trước khi thêm sản phẩm này" = (running_sum - revenue) / total.
--   Điều kiện < 80 giữ cả sản phẩm VƯỢT qua mốc 80% (ở đây B chạm đúng 80.0 nên dừng ở B).
-- Bẫy hòa: nếu chỉ ORDER BY revenue DESC và dùng frame mặc định (RANGE), hai sản phẩm cùng 50
--   sẽ có cùng running_sum = 100. Thêm product để phá hòa và dùng ROWS.
-- Bẫy kiểu số: revenue là integer, 100 * 300 / 1000 chia nguyên vẫn đúng ở đây, nhưng
--   300 / 1000 thì ra 0. Luôn nhân 100.0 (numeric) TRƯỚC khi chia.
