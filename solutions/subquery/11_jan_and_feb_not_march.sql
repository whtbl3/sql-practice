-- Problem subquery/11: Ordered in January and February but not March  [Medium]
-- Pattern: Several EXISTS / NOT EXISTS conditions on the same table
-- Variant: conditions across different rows
--
-- Task: Return customers who ordered in January 2024 AND in February 2024 but NOT in March 2024.
--   Each customer once, sorted by customer.
-- Learn: grinding/sql-subquery.md, B3

-- INPUT
orders
| order_id | customer | order_date |
|----------|----------|------------|
| 1        | Ann      | 2024-01-05 |
| 2        | Ann      | 2024-02-10 |
| 3        | Bob      | 2024-01-07 |
| 4        | Bob      | 2024-02-01 |
| 5        | Bob      | 2024-03-03 |
| 6        | Cy       | 2024-02-20 |
| 7        | Dee      | 2024-01-01 |
| 8        | Dee      | 2024-01-31 |
| 9        | Dee      | 2024-02-29 |
| 10       | Eli      | 2024-01-15 |
| 11       | Eli      | 2023-02-10 |

-- EXPECTED
| customer |
|----------|
| Ann      |
| Dee      |

-- QUERY
SELECT DISTINCT o.customer
FROM orders o
WHERE EXISTS (SELECT 1 FROM orders x WHERE x.customer = o.customer
                AND x.order_date >= DATE '2024-01-01' AND x.order_date < DATE '2024-02-01')
  AND EXISTS (SELECT 1 FROM orders x WHERE x.customer = o.customer
                AND x.order_date >= DATE '2024-02-01' AND x.order_date < DATE '2024-03-01')
  AND NOT EXISTS (SELECT 1 FROM orders x WHERE x.customer = o.customer
                AND x.order_date >= DATE '2024-03-01' AND x.order_date < DATE '2024-04-01')
ORDER BY o.customer;

-- ===== Giải thích =====
-- Lỗi tư duy hay gặp: WHERE month = 1 AND month = 2. Một DÒNG không thể vừa tháng 1
--   vừa tháng 2, nên kết quả luôn rỗng. Điều kiện nằm trên NHIỀU dòng khác nhau của cùng khách,
--   nên mỗi điều kiện là một EXISTS riêng.
-- Dùng khoảng [đầu tháng, đầu tháng sau) thay vì EXTRACT(MONTH ...):
--   - tự đúng với năm (đơn 2023-02 của Eli không bị tính),
--   - không phải nhớ tháng 2 có 28 hay 29 ngày,
--   - dùng được index trên order_date.
-- Cách khác 1 (gộp nhóm):
--   GROUP BY customer HAVING BOOL_OR(tháng 1) AND BOOL_OR(tháng 2) AND NOT BOOL_OR(tháng 3)
-- Cách khác 2 (phép tập hợp): (khách tháng 1) INTERSECT (khách tháng 2) EXCEPT (khách tháng 3)
