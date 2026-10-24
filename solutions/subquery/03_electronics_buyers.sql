-- Problem subquery/03: Customers who bought electronics  [Medium]
-- Pattern: Semi-join with IN / EXISTS (no duplicates from the join)
-- Variant: semi-join
--
-- Task: Return the name of every customer who ordered at least one product in category
--   'Electronics'. Each customer appears once, but two different customers with the same name are
--   two rows. Sort by name, then customer_id.
-- Learn: grinding/sql-subquery.md, D3

-- INPUT
customers
| customer_id | name |
|-------------|------|
| 1           | Ann  |
| 2           | Bob  |
| 3           | Cy   |
| 4           | Ann  |

orders
| order_id | customer_id | product_id |
|----------|-------------|------------|
| 1        | 1           | 10         |
| 2        | 1           | 11         |
| 3        | 1           | 10         |
| 4        | 2           | 12         |
| 5        | 3           | 11         |
| 6        | 4           | 10         |

products
| product_id | category    |
|------------|-------------|
| 10         | Electronics |
| 11         | Electronics |
| 12         | Books       |

-- EXPECTED
| name |
|------|
| Ann  |
| Ann  |
| Cy   |

-- QUERY
SELECT c.name
FROM customers c
WHERE c.customer_id IN (
    SELECT o.customer_id
    FROM orders o
    JOIN products p ON p.product_id = o.product_id
    WHERE p.category = 'Electronics'
)
ORDER BY c.name, c.customer_id;

-- ===== Giải thích =====
-- Bài toán "có ít nhất một ..." là SEMI-JOIN: mỗi dòng bảng trái xuất hiện tối đa 1 lần,
--   dù bên phải khớp bao nhiêu dòng.
-- Lỗi hay gặp 1: customers JOIN orders JOIN products. Ann (id 1) có 3 đơn điện tử nên hiện 3 lần.
-- Lỗi hay gặp 2: "chữa" bằng SELECT DISTINCT name. Hai khách khác nhau tên Ann bị gộp thành 1, sai.
--   DISTINCT trên cột hiển thị không thay thế được việc giữ đúng số dòng của bảng gốc.
-- IN (subquery) và EXISTS đều là semi-join, đều không tạo dòng trùng.
--   Viết bằng EXISTS:
--   WHERE EXISTS (SELECT 1 FROM orders o JOIN products p ON ... 
--                 WHERE o.customer_id = c.customer_id AND p.category = 'Electronics')
-- Lưu ý: IN an toàn với NULL, nhưng NOT IN thì KHÔNG (xem antijoin/01).
