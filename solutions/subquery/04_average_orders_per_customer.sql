-- Problem subquery/04: Average orders per customer  [Medium]
-- Pattern: Derived table (subquery in FROM): aggregate of an aggregate
-- Variant: two-level aggregation
--
-- Task: Return one row: customers (number of customers), avg_orders (average number of orders per
--   customer, 2 decimals, customers without orders count as 0) and max_orders. Orders whose
--   customer_id is not in customers are ignored.
-- Learn: grinding/sql-subquery.md, B4

-- INPUT
customers
| customer_id | name |
|-------------|------|
| 1           | Ann  |
| 2           | Bob  |
| 3           | Cy   |
| 4           | Dee  |
| 5           | Eli  |

orders
| order_id | customer_id |
|----------|-------------|
| 1        | 1           |
| 2        | 1           |
| 3        | 1           |
| 4        | 2           |
| 5        | 3           |
| 6        | 3           |

-- EXPECTED
| customers | avg_orders | max_orders |
|-----------|------------|------------|
| 5         | 1.20       | 3          |

-- QUERY
SELECT COUNT(*) AS customers,
       ROUND(AVG(order_count), 2) AS avg_orders,
       MAX(order_count) AS max_orders
FROM (
    SELECT c.customer_id, COUNT(o.order_id) AS order_count
    FROM customers c
    LEFT JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
) per_customer;

-- ===== Giải thích =====
-- Gộp hai tầng: trước hết đếm đơn MỖI khách, sau đó lấy trung bình CÁC con số đó.
--   SQL không cho lồng trực tiếp: AVG(COUNT(*)) báo lỗi aggregate function calls cannot be nested.
--   Cách làm là đặt tầng 1 vào subquery trong FROM (bảng dẫn xuất, phải có alias), tầng 2 ở ngoài.
-- Lỗi hay gặp 1: chỉ đếm trên bảng orders (GROUP BY customer_id). Khách 0 đơn biến mất,
--   nên trung bình ra 6/3 = 2.00 thay vì 6/5 = 1.20. Phải xuất phát từ customers và LEFT JOIN.
-- Lỗi hay gặp 2: COUNT(*) sau LEFT JOIN đếm cả dòng NULL (khách 0 đơn thành 1).
--   Dùng COUNT(o.order_id).
-- Bảng rỗng: COUNT(*) vẫn trả 0, còn AVG và MAX trả NULL. Truy vấn gộp không có GROUP BY
--   luôn trả đúng 1 dòng.
-- Cách viết khác: WITH per_customer AS (...) SELECT ... FROM per_customer. CTE chỉ là
--   subquery trong FROM có đặt tên, dễ đọc hơn khi lồng nhiều tầng.
