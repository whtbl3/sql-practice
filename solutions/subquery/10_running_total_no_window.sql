-- Problem subquery/10: Running total without window functions  [Medium]
-- Pattern: Correlated subquery with an inequality (x.id <= t.id)
-- Variant: the keyword OVER is forbidden
--
-- Task: Return txn_id, amount and running_total (sum of amount over all transactions with txn_id <=
--   this one) WITHOUT window functions (OVER is rejected). Sort by txn_id.
-- @forbid: \bOVER\s*\(
-- Learn: grinding/sql-subquery-window.md, mục S2

-- INPUT
transactions
| txn_id | amount |
|--------|--------|
| 1      | 100    |
| 2      | -30    |
| 3      | 50     |
| 5      | 20     |

-- EXPECTED
| txn_id | amount | running_total |
|--------|--------|---------------|
| 1      | 100    | 100           |
| 2      | -30    | 70            |
| 3      | 50     | 120           |
| 5      | 20     | 140           |

-- QUERY
SELECT t.txn_id, t.amount,
       (SELECT SUM(x.amount) FROM transactions x WHERE x.txn_id <= t.txn_id) AS running_total
FROM transactions t
ORDER BY t.txn_id;

-- ===== Giải thích =====
-- Tương quan không nhất thiết là dấu "=". Ở đây x.txn_id <= t.txn_id nghĩa là
--   "mọi giao dịch từ đầu tới giao dịch hiện tại".
-- Cách khác không dùng window: self join rồi gộp:
--   FROM transactions t JOIN transactions x ON x.txn_id <= t.txn_id GROUP BY t.txn_id, t.amount
-- Vì sao vẫn nên học: một số hệ thống cũ (MySQL < 8) không có window function, và cách tư duy
--   "tập các dòng thỏa điều kiện so với dòng hiện tại" dùng lại ở rất nhiều bài.
-- Chi phí: mỗi dòng quét lại các dòng trước, khoảng O(n^2).
--   SUM(...) OVER (ORDER BY txn_id) chỉ quét một lần.
