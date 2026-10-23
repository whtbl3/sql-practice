-- Problem window/10: Cumulative unique customers  [Hard]
-- Pattern: Running distinct count = first-appearance flag + running SUM
-- Variant: COUNT DISTINCT is not a window function
--
-- Task: For every date that has orders, return new_customers (customers whose FIRST order is on
--   that date) and cumulative_customers (distinct customers seen up to and including that date).
--   Sort by order_date.
-- Learn: grinding/sql-window.md, B4

-- INPUT
orders
| order_date | customer |
|------------|----------|
| 2024-01-01 | Ann      |
| 2024-01-01 | Bob      |
| 2024-01-01 | Ann      |
| 2024-01-02 | Ann      |
| 2024-01-03 | Cy       |
| 2024-01-03 | Bob      |
| 2024-01-04 | Dee      |
| 2024-01-04 | Cy       |

-- EXPECTED
| order_date | new_customers | cumulative_customers |
|------------|---------------|----------------------|
| 2024-01-01 | 2             | 2                    |
| 2024-01-02 | 0             | 2                    |
| 2024-01-03 | 1             | 3                    |
| 2024-01-04 | 1             | 4                    |

-- QUERY
WITH first_order AS (
    SELECT customer, MIN(order_date) AS first_date
    FROM orders
    GROUP BY customer
),
days AS (
    SELECT DISTINCT order_date FROM orders
)
SELECT d.order_date,
       COUNT(f.customer) AS new_customers,
       SUM(COUNT(f.customer)) OVER (ORDER BY d.order_date) AS cumulative_customers
FROM days d
LEFT JOIN first_order f ON f.first_date = d.order_date
GROUP BY d.order_date
ORDER BY d.order_date;

-- ===== Giải thích =====
-- Ý định tự nhiên: COUNT(DISTINCT customer) OVER (ORDER BY order_date).
--   PostgreSQL báo lỗi: DISTINCT is not implemented for window functions.
-- Mẹo chuẩn: "số khách khác nhau tính đến ngày D" = "số khách có ngày mua ĐẦU TIÊN <= D".
--   Bước 1: tìm ngày đầu tiên của mỗi khách (MIN ... GROUP BY).
--   Bước 2: đếm số khách mới mỗi ngày, rồi cộng dồn bằng SUM(...) OVER (ORDER BY ...).
-- Cần bảng days riêng (LEFT JOIN) để ngày không có khách mới vẫn hiện với 0.
-- SUM(COUNT(...)) OVER (...): hàm gộp bên trong chạy ở bước GROUP BY, window SUM bên ngoài
--   chạy sau, trên các dòng đã gộp.
-- Cách khác cho bước 1: ROW_NUMBER() OVER (PARTITION BY customer ORDER BY order_date) = 1.
