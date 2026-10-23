# Churn, growth accounting và NRR

> Bài liên quan: `churn/01`–`06`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** mỗi kỳ mất bao nhiêu khách (hoặc bao nhiêu tiền), và lượng khách mới hay khách quay lại có bù được không?

**Vì sao khó:** churn là *"kỳ trước có hoạt động, kỳ này không"*. Tức là churn xảy ra đúng ở **kỳ không có dòng dữ liệu nào** của user. Nếu chỉ dùng `LAG` trên các tháng có dữ liệu thì không bao giờ phát hiện được churn. User 3 (hoạt động 01 và 04) cho thấy điều đó:

| user_id | m | prev_m |
| --- | --- | --- |
| 3 | 2024-01 | NULL |
| 3 | 2024-04 | 2024-01 |

Tháng 02 (churn) không có dòng nào để gắn nhãn.

Bốn bước:

1. Định nghĩa "hoạt động" theo từng kỳ
2. Dựng lưới user × kỳ
3. So sánh với kỳ trước để gắn trạng thái
4. Đếm theo kỳ, tính tỷ lệ

Ví dụ chạy xuyên suốt dùng bảng `activity`:

| user_id | activity_date |
| --- | --- |
| 1 | 2024-01-03 |
| 1 | 2024-01-20 |
| 1 | 2024-02-14 |
| 1 | 2024-03-01 |
| 1 | 2024-05-30 |
| 2 | 2024-02-29 |
| 3 | 2024-01-31 |
| 3 | 2024-04-01 |
| 4 | 2024-03-10 |
| 4 | 2024-04-10 |
| 4 | 2024-05-10 |
| 5 | 2024-05-01 |
| 5 | 2024-05-02 |

---

## B1. Định nghĩa "hoạt động" theo từng kỳ

- **Vấn đề:** cần biết mỗi user có hoạt động trong mỗi tháng hay không. Nhiều sự kiện trong cùng một tháng vẫn chỉ tính là một tháng hoạt động.
- **Tại sao:** `DATE_TRUNC` đưa ngày về đầu tháng, `DISTINCT` bỏ trùng.

```sql
act AS (SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m FROM activity)
```

| user_id | m |
| --- | --- |
| 1 | 2024-01 |
| 1 | 2024-02 |
| 1 | 2024-03 |
| 1 | 2024-05 |
| 2 | 2024-02 |
| 3 | 2024-01 |
| 3 | 2024-04 |
| 4 | 2024-03 |
| 4 | 2024-04 |
| 4 | 2024-05 |
| 5 | 2024-05 |

**Khi chỉ có một ngày chốt** (gắn nhãn Active / At risk / Lapsed):
- Không cần lưới. Lấy `MAX(order_date)` của mỗi khách rồi dùng `CASE` theo `ngày_chốt - MAX(order_date)`.
- Đi từ `customers LEFT JOIN orders`, điều kiện lọc đơn đặt trong `ON`.
- Nhánh `IS NULL` ('Never bought') đặt đầu tiên. Người chưa từng mua thì không thể "rời bỏ".

**Khi dữ liệu là hợp đồng** (`start_date`, `end_date`):
- "Hoạt động vào ngày d" nghĩa là `start_date <= d AND (end_date IS NULL OR d < end_date)`. Đây là khoảng nửa mở: thuê bao kết thúc đúng ngày d thì không còn chạy vào ngày d.
- Kiểm tra điều kiện đó vào ngày 1 của mỗi tháng.

**Khi đo bằng tiền** (MRR): mỗi khách có nhiều dòng sản phẩm, nên gộp `SUM(mrr) GROUP BY customer_id, month` **trước**. Nếu không, khách đổi gói Pro sang Basic sẽ bị tính thành một dòng churn cộng một dòng mới.

## B2. Dựng lưới user × kỳ

- **Vấn đề:** tháng user không hoạt động phải **có dòng**, thì mới gắn nhãn `churned` được.
- **Tại sao:**
  - `generate_series` sinh đủ mọi tháng.
  - `JOIN` với điều kiện `m >= first_m` để không sinh dòng trước khi user xuất hiện.
  - `LEFT JOIN` với `act` để biết user có hoạt động trong tháng đó hay không.

```sql
months AS (SELECT generate_series(MIN(m), MAX(m), INTERVAL '1 month')::date AS m FROM act),
firsts AS (SELECT user_id, MIN(m) AS first_m FROM act GROUP BY user_id),
grid AS (
  SELECT f.user_id, mo.m, f.first_m, a.user_id IS NOT NULL AS active
  FROM firsts f
  JOIN months mo ON mo.m >= f.first_m
  LEFT JOIN act a ON a.user_id = f.user_id AND a.m = mo.m
)
```

User 1 và 3:

| user_id | m | active |
| --- | --- | --- |
| 1 | 2024-01 | true |
| 1 | 2024-02 | true |
| 1 | 2024-03 | true |
| 1 | 2024-04 | **false** |
| 1 | 2024-05 | true |
| 3 | 2024-01 | true |
| 3 | 2024-02 | **false** |
| 3 | 2024-03 | **false** |
| 3 | 2024-04 | true |
| 3 | 2024-05 | **false** |

**Khi kỳ báo cáo ngắn hơn lịch sử** (báo cáo 2024 nhưng có dữ liệu 2023):
- Lưới của mỗi user vẫn phải bắt đầu từ **tháng đầu tiên của user**, kể cả khi tháng đó thuộc năm 2023. Nếu không, user cũ bị tính là `new` ở tháng 01/2024.
- Dùng `CROSS JOIN LATERAL generate_series(f.first_m, <cuối kỳ>, INTERVAL '1 month')` để mỗi user có một chuỗi tháng riêng.
- Chỉ cắt về kỳ báo cáo ở B4.

## B3. So sánh với kỳ trước để gắn trạng thái

- **Vấn đề:** mỗi dòng cần biết tháng trước user có hoạt động hay không.
- **Tại sao:**
  - `LAG(active)` lấy cờ hoạt động của tháng trước.
  - `CASE` dừng ở nhánh đúng đầu tiên, nên nhánh `new` phải đứng trước. Ở tháng đầu của user, `LAG` là `NULL`, và `WHEN NULL` được coi là sai nên các nhánh sau vẫn an toàn.

| Tháng trước | Tháng này | Trạng thái |
| --- | --- | --- |
| (chưa có) | có | `new` |
| có | có | `retained` |
| không | có | `resurrected` |
| có | không | `churned` |
| không | không | (bỏ) |

```sql
labeled AS (
  SELECT user_id, m,
         CASE WHEN active AND m = first_m       THEN 'new'
              WHEN active AND LAG(active) OVER w THEN 'retained'
              WHEN active                       THEN 'resurrected'
              WHEN LAG(active) OVER w           THEN 'churned'
         END AS status
  FROM grid
  WINDOW w AS (PARTITION BY user_id ORDER BY m)
)
```

| user_id | m | active | prev_active | status |
| --- | --- | --- | --- | --- |
| 1 | 2024-01 | true | NULL | new |
| 1 | 2024-02 | true | true | retained |
| 1 | 2024-03 | true | true | retained |
| 1 | 2024-04 | false | true | churned |
| 1 | 2024-05 | true | false | resurrected |
| 3 | 2024-01 | true | NULL | new |
| 3 | 2024-02 | false | true | churned |
| 3 | 2024-03 | false | false | NULL |
| 3 | 2024-04 | true | false | resurrected |
| 3 | 2024-05 | false | true | churned |

Window function không dùng được trong `WHERE` của cùng tầng `SELECT`, nên việc lọc `status IS NOT NULL` phải làm ở tầng ngoài.

**Khi chỉ cần tìm người quay lại sau ít nhất N tháng im lặng:**
- Không cần lưới. Đổi tháng thành số `năm*12 + tháng`, rồi `month_no - LAG(month_no) - 1` chính là số tháng trống ở giữa.
- Tính theo **tháng lịch**, không theo ngày. Ví dụ 31/01 → 01/04 chỉ cách 61 ngày nhưng đã im lặng 2 tháng.

```sql
month_no - LAG(month_no) OVER (PARTITION BY customer_id ORDER BY month_no) - 1 AS silent_months
```

| customer_id | month_no | silent_months |
| --- | --- | --- |
| 3 | 24287 | NULL |
| 3 | 24291 | 3 |
| 3 | 24297 | 5 |
| 5 | 24289 | NULL |
| 5 | 24292 | 2 |

**Khi đo bằng tiền** (NRR):
- Chỉ so 2 mốc. Đi `LEFT JOIN` **từ kỳ gốc** sang kỳ đích, điều kiện tháng đích đặt trong `ON`. Khách không còn ở kỳ đích thì `COALESCE(t, 0)`.
- Khách mới ở kỳ đích không được tính.
- Mỗi khách rơi vào một loại:
  - `t > b`: expansion (tăng)
  - `0 < t < b`: contraction (giảm)
  - `t = 0`: churned

## B4. Đếm theo kỳ, tính tỷ lệ

- **Vấn đề:** gom trạng thái thành một dòng mỗi tháng. Tháng không có ai cũng phải hiện ra.
- **Tại sao:**
  - Dùng spine của kỳ báo cáo rồi `LEFT JOIN` nhãn từ B3, sau đó `COUNT(*) FILTER (WHERE status = ...)`.
  - Mẫu số của churn rate là số user hoạt động **đầu kỳ**, tức MAU tháng trước. Không phải MAU tháng này, cũng không phải tổng số user từng có.
  - Quick ratio: `(new + resurrected) / churned`. Lớn hơn 1 là đang tăng trưởng.

```sql
SELECT m,
       COUNT(*) FILTER (WHERE status IN ('new', 'retained', 'resurrected')) AS mau,
       COUNT(*) FILTER (WHERE status = 'new')         AS new_users,
       COUNT(*) FILTER (WHERE status = 'retained')    AS retained,
       COUNT(*) FILTER (WHERE status = 'resurrected') AS resurrected,
       COUNT(*) FILTER (WHERE status = 'churned')     AS churned
FROM report_months r LEFT JOIN labeled l USING (m)
GROUP BY m
-- tầng ngoài:
--   churn_rate_pct = 100.0 * churned / NULLIF(LAG(mau) OVER (ORDER BY m), 0)
--   quick_ratio    = (new_users + resurrected)::numeric / NULLIF(churned, 0)
```

| month | mau | new_users | retained | resurrected | churned | churn_rate_pct | quick_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 2 | 2 | 0 | 0 | 0 | NULL | NULL |
| 2024-02 | 2 | 1 | 1 | 0 | 1 | 50.0 | 1.00 |
| 2024-03 | 2 | 1 | 1 | 0 | 1 | 50.0 | 1.00 |
| 2024-04 | 2 | 0 | 1 | 1 | 1 | 50.0 | 1.00 |
| 2024-05 | 3 | 1 | 1 | 1 | 1 | 50.0 | 2.00 |

**Tự kiểm tra:** `MAU(t) = MAU(t−1) + new + resurrected − churned`. Ví dụ tháng 05: 2 + 1 + 1 − 1 = 3.

**Khi dữ liệu là hợp đồng:**
- `active_start` = số thuê bao chạy vào ngày 1 của tháng.
- `churned` = những thuê bao trong số đó **không còn chạy vào ngày 1 tháng sau** (`end_date <= next_start`).
- Đừng dùng "`end_date` nằm trong tháng": thuê bao kết thúc đúng ngày 01/05 sẽ không bị tính churn ở tháng nào cả.

**Khi đo bằng tiền:**
- `NRR = SUM(t) / SUM(b)`. Kết quả có thể vượt 100% nếu phần tăng của khách cũ lớn hơn phần mất.
- `GRR = (start − contraction − churned) / start`. Không cộng phần expansion, nên tối đa là 100%.

---

## Tổng kết: query đầy đủ

Ghép B1 → B4 thành một câu:

```sql
WITH act AS (                                      -- B1: (user, tháng hoạt động)
  SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m FROM activity
),
months AS (SELECT generate_series(MIN(m), MAX(m), INTERVAL '1 month')::date AS m FROM act),
firsts AS (SELECT user_id, MIN(m) AS first_m FROM act GROUP BY user_id),
grid AS (                                          -- B2: lưới user × tháng
  SELECT f.user_id, mo.m, f.first_m, a.user_id IS NOT NULL AS active
  FROM firsts f
  JOIN months mo ON mo.m >= f.first_m
  LEFT JOIN act a ON a.user_id = f.user_id AND a.m = mo.m
),
labeled AS (                                       -- B3: trạng thái so với tháng trước
  SELECT user_id, m,
         CASE WHEN active AND m = first_m       THEN 'new'
              WHEN active AND LAG(active) OVER w THEN 'retained'
              WHEN active                       THEN 'resurrected'
              WHEN LAG(active) OVER w           THEN 'churned'
         END AS status
  FROM grid
  WINDOW w AS (PARTITION BY user_id ORDER BY m)
),
counts AS (                                        -- B4: đếm theo tháng
  SELECT mo.m,
         COUNT(*) FILTER (WHERE l.status IN ('new', 'retained', 'resurrected')) AS mau,
         COUNT(*) FILTER (WHERE l.status = 'new')         AS new_users,
         COUNT(*) FILTER (WHERE l.status = 'retained')    AS retained,
         COUNT(*) FILTER (WHERE l.status = 'resurrected') AS resurrected,
         COUNT(*) FILTER (WHERE l.status = 'churned')     AS churned
  FROM months mo LEFT JOIN labeled l ON l.m = mo.m
  GROUP BY mo.m
)
SELECT TO_CHAR(m, 'YYYY-MM') AS month, mau, new_users, retained, resurrected, churned,
       ROUND(100.0 * churned / NULLIF(LAG(mau) OVER (ORDER BY m), 0), 1) AS churn_rate_pct,
       ROUND((new_users + resurrected)::numeric / NULLIF(churned, 0), 2) AS quick_ratio
FROM counts
ORDER BY m;
```

| month | mau | new_users | retained | resurrected | churned | churn_rate_pct | quick_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 2 | 2 | 0 | 0 | 0 | NULL | NULL |
| 2024-02 | 2 | 1 | 1 | 0 | 1 | 50.0 | 1.00 |
| 2024-03 | 2 | 1 | 1 | 0 | 1 | 50.0 | 1.00 |
| 2024-04 | 2 | 0 | 1 | 1 | 1 | 50.0 | 1.00 |
| 2024-05 | 3 | 1 | 1 | 1 | 1 | 50.0 | 2.00 |
