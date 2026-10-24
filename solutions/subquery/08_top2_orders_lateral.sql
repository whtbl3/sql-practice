-- Problem subquery/08: Top 2 orders per customer with LATERAL  [Hard]
-- Pattern: LEFT JOIN LATERAL (subquery that can see the outer row) + LIMIT
-- Variant: per-row subquery returning many rows
--
-- Task: For each customer return their 2 largest orders (ties: smaller order_id first): name,
--   order_id, amount. A customer without orders appears once with NULL order_id and amount. Sort by
--   name, amount DESC, order_id.
-- Learn: grinding/sql-subquery.md, D5

-- INPUT
customers
| customer_id | name |
|-------------|------|
| 1           | Ann  |
| 2           | Bob  |
| 3           | Cy   |

orders
| order_id | customer_id | amount |
|----------|-------------|--------|
| 1        | 1           | 50     |
| 2        | 1           | 80     |
| 3        | 1           | 80     |
| 4        | 1           | 10     |
| 5        | 2           | 30     |

-- EXPECTED
| name | order_id | amount |
|------|----------|--------|
| Ann  | 2        | 80     |
| Ann  | 3        | 80     |
| Bob  | 5        | 30     |
| Cy   | NULL     | NULL   |

-- QUERY
SELECT c.name, t.order_id, t.amount
FROM customers c
LEFT JOIN LATERAL (
    SELECT o.order_id, o.amount
    FROM orders o
    WHERE o.customer_id = c.customer_id
    ORDER BY o.amount DESC, o.order_id
    LIMIT 2
) t ON true
ORDER BY c.name, t.amount DESC, t.order_id;

-- ===== Giải thích =====
-- Subquery trong FROM bình thường KHÔNG được nhìn thấy bảng đứng trước nó.
--   Thêm LATERAL thì subquery được tham chiếu c.customer_id, và chạy lại "cho từng khách".
--   Như vậy LIMIT 2 áp dụng RIÊNG cho mỗi khách, đúng nghĩa "top 2 mỗi nhóm".
-- LEFT JOIN LATERAL ... ON true: giữ khách không có đơn (giống LEFT JOIN thường).
--   CROSS JOIN LATERAL sẽ loại khách đó.
-- So với ROW_NUMBER() OVER (PARTITION BY ...) <= 2: kết quả giống nhau. LATERAL mạnh khi
--   có index (customer_id, amount) và mỗi khách có rất nhiều đơn: DB chỉ đọc 2 dòng đầu.
-- Lỗi hay gặp: subquery có ORDER BY ... LIMIT 2 nhưng KHÔNG tương quan. Khi đó chỉ ra 2 đơn
--   lớn nhất của TOÀN bảng.
