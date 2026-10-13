-- Problem window/12: Record-breaking months  [Medium]
-- Pattern: Custom frame that excludes the current row (MAX ... 1 PRECEDING)
-- Variant: running max
--
-- Task: A month sets a record if its revenue is higher than every earlier month (the first month
--   always counts). Return month, revenue and previous_best (highest revenue of all earlier months,
--   NULL for the first) for record months only. Sort by month.
-- Learn: grinding/sql-subquery-window.md, mục W3

-- INPUT
monthly_revenue
| month      | revenue |
|------------|---------|
| 2024-01-01 | 100     |
| 2024-02-01 | 80      |
| 2024-03-01 | 120     |
| 2024-04-01 | 120     |
| 2024-05-01 | 150     |
| 2024-06-01 | 90      |

-- EXPECTED
| month      | revenue | previous_best |
|------------|---------|---------------|
| 2024-01-01 | 100     | NULL          |
| 2024-03-01 | 120     | 100           |
| 2024-05-01 | 150     | 120           |

-- QUERY
WITH x AS (
    SELECT month, revenue,
           MAX(revenue) OVER (ORDER BY month
                              ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS previous_best
    FROM monthly_revenue
)
SELECT month, revenue, previous_best
FROM x
WHERE previous_best IS NULL OR revenue > previous_best
ORDER BY month;

-- ===== Giải thích =====
-- Frame có thể kết thúc TRƯỚC dòng hiện tại:
--   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING = mọi dòng trước, KHÔNG gồm dòng này.
--   Nên MAX(...) cho "kỷ lục tính đến tháng trước", và tháng đầu tiên ra NULL (frame rỗng).
-- Lỗi hay gặp: dùng frame mặc định (tới CURRENT ROW) rồi so revenue >= running_max.
--   Cách đó tính cả tháng HÒA kỷ lục (tháng 4: 120 = 120) là kỷ lục mới, sai đề.
-- Các cách ghi frame khác nên biết:
--   ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING   (cửa sổ trượt 5 dòng quanh dòng hiện tại)
--   ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING  (từ đây tới cuối)
