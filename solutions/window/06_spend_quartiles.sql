-- Problem window/06: Spending quartiles and percent rank  [Medium]
-- Pattern: NTILE and PERCENT_RANK
-- Variant: distribution functions
--
-- Task: Return customer, total_spent, quartile = NTILE(4) by total_spent DESC (ties broken by
--   customer, 1 = top spenders) and pct_rank = PERCENT_RANK by total_spent DESC, rounded to 2
--   decimals. Sort by total_spent DESC, customer.
-- Learn: grinding/sql-window.md, B4

-- INPUT
customer_spend
| customer | total_spent |
|----------|-------------|
| A        | 500         |
| B        | 400         |
| C        | 400         |
| D        | 300         |
| E        | 200         |
| F        | 100         |

-- EXPECTED
| customer | total_spent | quartile | pct_rank |
|----------|-------------|----------|----------|
| A        | 500         | 1        | 0.00     |
| B        | 400         | 1        | 0.20     |
| C        | 400         | 2        | 0.20     |
| D        | 300         | 2        | 0.60     |
| E        | 200         | 3        | 0.80     |
| F        | 100         | 4        | 1.00     |

-- QUERY
SELECT customer, total_spent,
       NTILE(4) OVER (ORDER BY total_spent DESC, customer) AS quartile,
       ROUND((PERCENT_RANK() OVER (ORDER BY total_spent DESC))::numeric, 2) AS pct_rank
FROM customer_spend
ORDER BY total_spent DESC, customer;

-- ===== Giải thích =====
-- NTILE(4): chia các dòng (đã sắp) thành 4 nhóm gần bằng nhau. Số dòng dư được chia cho
--   các nhóm ĐẦU: 6 dòng thì nhóm có 2,2,1,1 dòng. NTILE không quan tâm dòng hòa, nên B và C
--   (cùng 400) vẫn có thể rơi vào 2 nhóm khác nhau. Vì vậy cần cột phá hòa để kết quả ổn định.
-- PERCENT_RANK = (RANK - 1) / (số dòng - 1), từ 0 đến 1. Dòng hòa có cùng giá trị.
--   (CUME_DIST là họ hàng: tỷ lệ số dòng <= dòng hiện tại.)
-- Lỗi hay gặp: PERCENT_RANK trả về double precision, mà ROUND(double, 2) KHÔNG tồn tại trong
--   PostgreSQL (báo lỗi function round(double precision, integer) does not exist).
--   Phải ép kiểu ::numeric trước khi ROUND.
