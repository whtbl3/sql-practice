-- Problem window/09: Detect price changes  [Medium]
-- Pattern: LAG + IS DISTINCT FROM to keep only rows that changed
-- Variant: change detection
--
-- Task: price_history has one snapshot per product per day, and most days repeat the price. Return
--   only the snapshots where the price differs from that product's previous snapshot (NULL counts as
--   a value), plus each product's first snapshot. Return product, changed_on, old_price (previous
--   snapshot's price), new_price. Sort by product, changed_on.
-- Learn: grinding/sql-window.md, B4

-- INPUT
price_history
| product | changed_on | price |
|---------|------------|-------|
| A       | 2024-01-01 | 10    |
| A       | 2024-01-02 | 10    |
| A       | 2024-01-03 | 12    |
| A       | 2024-01-04 | 12    |
| A       | 2024-01-05 | 10    |
| B       | 2024-01-01 | 5     |
| B       | 2024-01-02 | 5     |

-- EXPECTED
| product | changed_on | old_price | new_price |
|---------|------------|-----------|-----------|
| A       | 2024-01-01 | NULL      | 10        |
| A       | 2024-01-03 | 10        | 12        |
| A       | 2024-01-05 | 12        | 10        |
| B       | 2024-01-01 | NULL      | 5         |

-- QUERY
WITH x AS (
    SELECT product, changed_on, price,
           LAG(price)   OVER w AS old_price,
           ROW_NUMBER() OVER w AS rn
    FROM price_history
    WINDOW w AS (PARTITION BY product ORDER BY changed_on)
)
SELECT product, changed_on, old_price, price AS new_price
FROM x
WHERE rn = 1 OR price IS DISTINCT FROM old_price
ORDER BY product, changed_on;

-- ===== Giải thích =====
-- Ý tưởng: LAG(price) đưa giá hôm trước lên cùng dòng, rồi giữ dòng có giá khác hôm trước.
-- Lỗi hay gặp: viết WHERE price <> old_price.
--   - Dòng đầu: old_price là NULL, nên 10 <> NULL ra UNKNOWN và dòng bị loại.
--   - Giá đổi sang/từ NULL cũng bị loại vì cùng lý do.
--   IS DISTINCT FROM so sánh "an toàn với NULL": NULL IS DISTINCT FROM 10 là TRUE,
--   NULL IS DISTINCT FROM NULL là FALSE.
-- Vì sao cần rn = 1: nếu snapshot đầu tiên có giá NULL thì
--   NULL IS DISTINCT FROM NULL(LAG) ra FALSE và dòng đầu bị mất. Đánh số dòng để chắc chắn giữ nó.
-- Nhắc lại: phải lọc ở truy vấn NGOÀI vì WHERE không thấy được window function.
