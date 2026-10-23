-- Problem window/03: Running balance with same-day transactions  [Medium]
-- Pattern: Running SUM, and the default RANGE frame with ties
-- Variant: window frame
--
-- Task: Return every transaction with running_balance = sum of amount over all transactions up to
--   and including this one, in order of txn_date then txn_id. Each row must add exactly its own
--   amount, even when several transactions share a date. Sort by txn_date, txn_id.
-- Learn: grinding/sql-window.md, B2–B3

-- INPUT
transactions
| txn_id | txn_date   | amount |
|--------|------------|--------|
| 1      | 2024-01-01 | 100    |
| 2      | 2024-01-02 | -30    |
| 3      | 2024-01-02 | 50     |
| 4      | 2024-01-03 | -20    |
| 5      | 2024-01-05 | 10     |

-- EXPECTED
| txn_id | txn_date   | amount | running_balance |
|--------|------------|--------|-----------------|
| 1      | 2024-01-01 | 100    | 100             |
| 2      | 2024-01-02 | -30    | 70              |
| 3      | 2024-01-02 | 50     | 120             |
| 4      | 2024-01-03 | -20    | 100             |
| 5      | 2024-01-05 | 10     | 110             |

-- QUERY
SELECT txn_id, txn_date, amount,
       SUM(amount) OVER (ORDER BY txn_date, txn_id
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
FROM transactions
ORDER BY txn_date, txn_id;

-- ===== Giải thích =====
-- Ý tưởng: thêm ORDER BY vào OVER thì phép gộp trở thành TỔNG DỒN.
-- Cái bẫy: khi có ORDER BY mà không ghi frame, frame mặc định là
--   RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--   RANGE coi mọi dòng có CÙNG giá trị ORDER BY là "ngang hàng" (peers) và cộng tất cả cùng lúc.
--   Nếu chỉ viết OVER (ORDER BY txn_date) thì giao dịch 2 và 3 (cùng ngày) đều ra 120, sai.
-- Hai cách sửa (dùng cách nào cũng đúng):
--   1) Thêm cột phá hòa cho ORDER BY là duy nhất: ORDER BY txn_date, txn_id
--   2) Dùng ROWS thay RANGE: ROWS tính theo từng DÒNG vật lý, không gộp peers.
-- Thói quen tốt: tổng dồn nên luôn ghi ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW.
