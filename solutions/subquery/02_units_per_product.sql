-- Problem subquery/02: Units sold per product and share of total  [Medium]
-- Pattern: Correlated scalar subquery in SELECT
-- Variant: subquery per row
--
-- Task: For every product (including never-ordered ones) return name, units_sold (total qty, 0 if
--   none) and pct_of_units = units_sold as % of all units sold, 1 decimal (NULL if nothing was
--   sold at all). Sort by units_sold DESC, name.
-- Learn: grinding/sql-subquery.md, B2

-- INPUT
products
| product_id | name |
|------------|------|
| 1          | Pen  |
| 2          | Mug  |
| 3          | Lamp |
| 4          | Desk |

order_items
| order_id | product_id | qty |
|----------|------------|-----|
| 1        | 1          | 3   |
| 1        | 2          | 1   |
| 2        | 1          | 2   |
| 3        | 3          | 4   |

-- EXPECTED
| name | units_sold | pct_of_units |
|------|------------|--------------|
| Pen  | 5          | 50.0         |
| Lamp | 4          | 40.0         |
| Mug  | 1          | 10.0         |
| Desk | 0          | 0.0          |

-- QUERY
SELECT name, units_sold,
       ROUND(100.0 * units_sold / NULLIF((SELECT SUM(qty) FROM order_items), 0), 1) AS pct_of_units
FROM (
    SELECT p.name,
           COALESCE((SELECT SUM(i.qty) FROM order_items i WHERE i.product_id = p.product_id), 0) AS units_sold
    FROM products p
) t
ORDER BY units_sold DESC, name;

-- ===== Giải thích =====
-- Subquery TƯƠNG QUAN (correlated): WHERE i.product_id = p.product_id tham chiếu dòng p
--   của truy vấn ngoài. Về logic, nó chạy lại cho TỪNG sản phẩm.
-- Khi không có dòng nào khớp, SUM trả NULL (không phải 0), nên phải COALESCE(..., 0).
-- Subquery (SELECT SUM(qty) FROM order_items) thì không tương quan: tổng của cả bảng.
--   NULLIF(..., 0) tránh lỗi chia cho 0 khi chưa bán được gì.
-- Bọc vào bảng dẫn xuất t để dùng lại tên units_sold (không dùng được alias của SELECT
--   trong chính SELECT đó).
-- Cách khác (thường nhanh hơn trên bảng lớn):
--   products LEFT JOIN (SELECT product_id, SUM(qty) ... GROUP BY product_id) s USING (product_id)
