-- Problem window/04: Previous and next order per customer  [Medium]
-- Pattern: LAG / LEAD with PARTITION BY
-- Variant: offset functions
--
-- Task: For every order return customer, order_date, prev_order_date and next_order_date (the same
--   customer's previous / next order) and days_since_prev (NULL for a first order). Sort by
--   customer, order_date.
-- Learn: grinding/sql-window.md, B4

-- INPUT
orders
| order_id | customer | order_date |
|----------|----------|------------|
| 1        | Ann      | 2024-01-01 |
| 2        | Ann      | 2024-01-15 |
| 3        | Ann      | 2024-02-01 |
| 4        | Bob      | 2024-01-10 |
| 5        | Cy       | 2024-03-01 |
| 6        | Cy       | 2024-03-31 |

-- EXPECTED
| customer | order_date | prev_order_date | days_since_prev | next_order_date |
|----------|------------|-----------------|-----------------|-----------------|
| Ann      | 2024-01-01 | NULL            | NULL            | 2024-01-15      |
| Ann      | 2024-01-15 | 2024-01-01      | 14              | 2024-02-01      |
| Ann      | 2024-02-01 | 2024-01-15      | 17              | NULL            |
| Bob      | 2024-01-10 | NULL            | NULL            | NULL            |
| Cy       | 2024-03-01 | NULL            | NULL            | 2024-03-31      |
| Cy       | 2024-03-31 | 2024-03-01      | 30              | NULL            |

-- QUERY
SELECT customer, order_date,
       LAG(order_date)  OVER w              AS prev_order_date,
       order_date - LAG(order_date) OVER w  AS days_since_prev,
       LEAD(order_date) OVER w              AS next_order_date
FROM orders
WINDOW w AS (PARTITION BY customer ORDER BY order_date)
ORDER BY customer, order_date;

-- ===== Giải thích =====
-- Ý tưởng: LAG(x) lấy giá trị x của dòng TRƯỚC, LEAD(x) của dòng SAU, theo ORDER BY trong OVER.
--   PARTITION BY customer giúp dòng đầu của mỗi khách KHÔNG nhìn sang khách khác (ra NULL).
-- WINDOW w AS (...) đặt tên cho cửa sổ để khỏi lặp lại cùng một OVER(...) ba lần.
-- Trong PostgreSQL, date - date ra số NGÀY (integer). Cộng/trừ với NULL thì ra NULL,
--   nên đơn đầu tiên tự có days_since_prev = NULL.
-- Mở rộng: LAG(x, 2) lấy dòng cách 2, LAG(x, 1, 0) cho giá trị mặc định 0 thay vì NULL.
-- Lỗi hay gặp: quên PARTITION BY nên đơn đầu của Bob bị so với đơn cuối của Ann.
