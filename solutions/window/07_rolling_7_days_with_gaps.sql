-- Problem window/07: Rolling 7-day revenue with missing days  [Medium]
-- Pattern: RANGE frame with an INTERVAL offset (ROWS vs RANGE)
-- Variant: calendar-based frame
--
-- Task: The table has one row per day WITH sales (days without sales are missing). For each row
--   return rolling_7d = total revenue from sale_date - 6 days to sale_date (a 7-calendar-day
--   window). Sort by sale_date.
-- Learn: grinding/sql-subquery-window.md, mục W3

-- INPUT
daily_sales
| sale_date  | revenue |
|------------|---------|
| 2024-01-01 | 10      |
| 2024-01-02 | 20      |
| 2024-01-04 | 30      |
| 2024-01-08 | 40      |
| 2024-01-09 | 50      |
| 2024-01-20 | 5       |

-- EXPECTED
| sale_date  | revenue | rolling_7d |
|------------|---------|------------|
| 2024-01-01 | 10      | 10         |
| 2024-01-02 | 20      | 30         |
| 2024-01-04 | 30      | 60         |
| 2024-01-08 | 40      | 90         |
| 2024-01-09 | 50      | 120        |
| 2024-01-20 | 5       | 5          |

-- QUERY
SELECT sale_date, revenue,
       SUM(revenue) OVER (ORDER BY sale_date
                          RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW) AS rolling_7d
FROM daily_sales
ORDER BY sale_date;

-- ===== Giải thích =====
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW = "6 DÒNG trước", không phải "6 NGÀY trước".
--   Khi có ngày bị thiếu, 6 dòng trước có thể trải dài hơn 7 ngày: ngày 2024-01-08 sẽ cộng
--   cả 01-01, ra 100 thay vì 90.
-- RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW lọc theo GIÁ TRỊ của cột ORDER BY:
--   lấy mọi dòng có sale_date trong [sale_date - 6 ngày, sale_date].
--   Điều kiện: ORDER BY chỉ được có MỘT cột, kiểu số / ngày / timestamp.
-- Cách khác: tạo lịch đủ ngày bằng generate_series, LEFT JOIN để điền 0, rồi dùng ROWS 6 PRECEDING
--   (cách này dùng được cả trên DBMS không hỗ trợ RANGE với INTERVAL).
