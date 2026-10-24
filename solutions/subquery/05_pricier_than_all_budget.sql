-- Problem subquery/05: Pricier than every Budget product  [Medium]
-- Pattern: > ALL (subquery), and how ALL behaves with an empty set and NULLs
-- Variant: quantified comparison
--
-- Task: Return non-'Budget' products whose price is higher than the price of EVERY 'Budget' product.
--   Ignore NULL prices (on both sides). If there are no Budget products, every non-Budget product
--   with a price qualifies. Sort by price DESC, name.
-- Learn: grinding/sql-subquery.md, V5

-- INPUT
products
| name | category | price |
|------|----------|-------|
| B1   | Budget   | 10    |
| B2   | Budget   | 25    |
| P1   | Pro      | 30    |
| P2   | Pro      | 25    |
| P3   | Lux      | 50    |
| P4   | Pro      | 20    |

-- EXPECTED
| name | price |
|------|-------|
| P3   | 50    |
| P1   | 30    |

-- QUERY
SELECT name, price
FROM products
WHERE category <> 'Budget'
  AND price IS NOT NULL
  AND price > ALL (SELECT price FROM products
                   WHERE category = 'Budget' AND price IS NOT NULL)
ORDER BY price DESC, name;

-- ===== Giải thích =====
-- x > ALL (tập) đúng khi x lớn hơn MỌI phần tử. x > ANY (tập) đúng khi lớn hơn ÍT NHẤT MỘT.
--   (= ANY tương đương IN, <> ALL tương đương NOT IN.)
-- Ba điều cần nhớ về ALL:
--   1) Tập RỖNG: x > ALL (rỗng) là TRUE (không có phần tử nào để thua). Kể cả khi x là NULL,
--      nên phải tự thêm price IS NOT NULL ở ngoài.
--   2) Tập có NULL: 30 > ALL (10, NULL) ra UNKNOWN, nên không dòng nào qua.
--      Phải lọc price IS NOT NULL bên TRONG subquery.
--   3) So với cách dùng MAX: price > (SELECT MAX(price) ...) cho kết quả giống nhau khi có dữ liệu,
--      nhưng tập rỗng thì MAX ra NULL, nên price > NULL loại hết. Hai cách KHÁC nhau ở trường hợp
--      biên này. Đọc kỹ đề muốn hành vi nào.
