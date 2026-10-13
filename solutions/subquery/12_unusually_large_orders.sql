-- Problem subquery/12: Orders more than double the customer's past average  [Hard]
-- Pattern: Correlated subquery over the customer's earlier rows (row comparison)
-- Variant: compare to own history
--
-- Task: An order is unusual if its amount is MORE than 2 x the average amount of the same customer's
--   earlier orders. Earlier = smaller order_date, or same order_date and smaller order_id. A first
--   order is never unusual. Return order_id, customer, amount, prev_avg (1 decimal). Sort by order_id.
-- Learn: grinding/sql-subquery-window.md, mục S2

-- INPUT
orders
| order_id | customer | order_date | amount |
|----------|----------|------------|--------|
| 1        | Ann      | 2024-01-01 | 100    |
| 2        | Ann      | 2024-01-05 | 120    |
| 3        | Ann      | 2024-01-10 | 500    |
| 4        | Ann      | 2024-01-20 | 200    |
| 5        | Bob      | 2024-01-02 | 50     |
| 6        | Bob      | 2024-01-03 | 100    |
| 7        | Bob      | 2024-01-04 | 160    |

-- EXPECTED
| order_id | customer | amount | prev_avg |
|----------|----------|--------|----------|
| 3        | Ann      | 500    | 110.0    |
| 7        | Bob      | 160    | 75.0     |

-- QUERY
SELECT order_id, customer, amount, ROUND(prev_avg, 1) AS prev_avg
FROM (
    SELECT o.order_id, o.customer, o.amount,
           (SELECT AVG(x.amount)
            FROM orders x
            WHERE x.customer = o.customer
              AND (x.order_date, x.order_id) < (o.order_date, o.order_id)) AS prev_avg
    FROM orders o
) t
WHERE amount > 2 * prev_avg
ORDER BY order_id;

-- ===== Giải thích =====
-- Subquery tương quan với HAI điều kiện: cùng khách (=) và đứng TRƯỚC đơn hiện tại (<).
-- So sánh bộ (row comparison): (a, b) < (c, d) nghĩa là a < c, HOẶC a = c và b < d.
--   Viết gọn thay cho: x.order_date < o.order_date OR (x.order_date = o.order_date AND x.order_id < o.order_id)
-- Đơn đầu tiên: subquery không có dòng nào nên AVG ra NULL, và amount > 2 * NULL là UNKNOWN,
--   nên tự bị loại mà không cần điều kiện riêng.
-- Ranh giới: Bob đơn 6 có 100 = 2 x 50, không "lớn hơn" nên không tính.
-- Phải bọc subquery vào bảng dẫn xuất để dùng prev_avg trong WHERE (alias của SELECT không
--   dùng được trong WHERE cùng cấp).
-- Cách khác bằng window:
--   AVG(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id
--                     ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
