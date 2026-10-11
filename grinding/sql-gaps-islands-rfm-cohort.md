# Gaps & Islands, RFM, Cohort: học nhanh để làm bài

> Phương ngữ: **SQLite** (đúng như đề: `strftime`, `julianday`). Mọi query và output dưới đây đã **chạy thật trên SQLite 3.37** với dữ liệu mẫu của đề.
> Cách học: nhận ra dạng bài → áp công thức → kiểm tra bẫy. Mỗi dạng chỉ có **một công thức**, thuộc nó là đủ.

---

## Phần 1. Gaps & Islands (chuỗi liên tiếp)

### 1.1 Nhận diện nhanh

Đề có các từ: *"liên tiếp"*, *"chuỗi"*, *"streak"*, *"không bị đứt quãng"*, *"khoảng trống"*. Bài toán luôn là: **gom các giá trị nằm sát nhau thành từng "đảo" (island), đếm độ dài, lấy đảo dài nhất** (hoặc tìm các "khoảng trống" giữa các đảo).

### 1.2 Mẹo cốt lõi (hiểu cái này là xong)

Nếu một dãy số **tăng đúng 1 mỗi bước** thì `giá trị − số thứ tự dòng` là **hằng số**. Khi bị đứt quãng, hiệu số **nhảy lên** → sang đảo mới.

| value | row_number | value − row_number | Đảo |
| --- | --- | --- | --- |
| 1 | 1 | 0 | A |
| 2 | 2 | 0 | A |
| 3 | 3 | 0 | A |
| 5 | 4 | **1** | B (đứt giữa 3 và 5) |
| 6 | 5 | 1 | B |
| 9 | 6 | **3** | C |

Hiệu số này chính là **nhãn đảo** (`grp`). Chỉ cần `GROUP BY` nhãn đó là ra từng chuỗi.

### 1.3 Công thức 4 bước (dùng cho mọi bài dạng này)

| Bước | Việc cần làm | Lý do |
| --- | --- | --- |
| 1 | **Đưa về đơn vị cần xét và khử trùng** (`SELECT DISTINCT customer_id, tháng`) | Một khách mua 2 đơn trong cùng tháng vẫn chỉ là 1 tháng; trùng sẽ làm hỏng phép trừ |
| 2 | **Đổi sang số nguyên liên tục** | Để phép "kề nhau" = "hơn kém 1 đơn vị" |
| 3 | `grp = số_nguyên − ROW_NUMBER() OVER (PARTITION BY khách ORDER BY số_nguyên)` | Nhãn đảo |
| 4 | `GROUP BY khách, grp` → `COUNT(*)` là độ dài; `MAX` lấy chuỗi dài nhất | Kết quả |

**Cách đổi sang số nguyên liên tục** (bước 2), ghi nhớ một dòng:

| Đơn vị | Biểu thức (SQLite) |
| --- | --- |
| Tháng (**vắt qua năm được**) | `năm * 12 + tháng` |
| Ngày | `CAST(julianday(order_date) AS INTEGER)` |
| Tuần | `CAST(julianday(order_date) / 7 AS INTEGER)` |

> Vì sao dùng `năm*12 + tháng`: nếu chỉ lấy `tháng` thì tháng 12 → tháng 1 là `12 → 1`, không liên tiếp. Với `năm*12 + tháng`, `2023-12 = 24288` và `2024-01 = 24289`, tự nhiên hơn kém 1. Đây là **điểm bẫy chính của đề** ("chuỗi được phép vắt qua năm mới").

### 1.4 Lời giải đề (có chú thích từng bước)

```sql
WITH monthly AS (                                   -- Bước 1 + 2: mỗi (khách, tháng) một dòng
  SELECT DISTINCT customer_id,
         CAST(strftime('%Y', order_date) AS INTEGER) * 12
       + CAST(strftime('%m', order_date) AS INTEGER) AS month_idx
  FROM orders
),
grouped AS (                                        -- Bước 3: nhãn đảo
  SELECT customer_id, month_idx,
         month_idx - ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month_idx) AS grp
  FROM monthly
),
streaks AS (                                        -- Bước 4a: độ dài từng đảo
  SELECT customer_id, grp, COUNT(*) AS streak_len
  FROM grouped
  GROUP BY customer_id, grp
)
SELECT customer_id, MAX(streak_len) AS longest_streak   -- Bước 4b: đảo dài nhất của mỗi khách
FROM streaks
GROUP BY customer_id
ORDER BY longest_streak DESC, customer_id;
```

**Trace Ví dụ 1** (khách 1: 2023-11, 2023-12, 2024-01, 2024-02; khách 2: 2024-01, 2024-03)

| customer_id | month_idx | row_number | grp | Ghi chú |
| --- | --- | --- | --- | --- |
| 1 | 24287 | 1 | 24286 | cùng `grp` → một đảo 4 tháng |
| 1 | 24288 | 2 | 24286 | |
| 1 | 24289 | 3 | 24286 | |
| 1 | 24290 | 4 | 24286 | |
| 2 | 24289 | 1 | 24288 | |
| 2 | 24291 | 2 | 24289 | `grp` khác → hai đảo, mỗi đảo dài 1 |

**Output** (khớp Expected result)

| customer_id | longest_streak |
| --- | --- |
| 1 | 4 |
| 2 | 1 |

**Ví dụ 2** cho `1 → 2` và `2 → 1`, cũng khớp. Lưu ý khách 1 có **hai đơn trong tháng 1**: nếu quên `DISTINCT` thì `month_idx` bị lặp (24289, 24289, 24290), `ROW_NUMBER` vẫn tăng nên `grp` lệch và chuỗi bị tách sai.

### 1.5 Cách giải thứ hai: `LAG` + tổng tích lũy (dễ đọc hơn với một số người)

```sql
WITH monthly AS (
  SELECT DISTINCT customer_id,
         CAST(strftime('%Y', order_date) AS INTEGER) * 12
       + CAST(strftime('%m', order_date) AS INTEGER) AS m
  FROM orders
),
flagged AS (                                         -- 1 = bắt đầu đảo mới, 0 = nối tiếp
  SELECT customer_id, m,
         CASE WHEN m - LAG(m) OVER (PARTITION BY customer_id ORDER BY m) = 1 THEN 0 ELSE 1 END AS is_new
  FROM monthly
),
numbered AS (                                        -- cộng dồn cờ → số thứ tự đảo
  SELECT customer_id, m,
         SUM(is_new) OVER (PARTITION BY customer_id ORDER BY m) AS island_id
  FROM flagged
)
SELECT customer_id, MAX(cnt) AS longest_streak
FROM (SELECT customer_id, island_id, COUNT(*) AS cnt FROM numbered GROUP BY customer_id, island_id)
GROUP BY customer_id
ORDER BY longest_streak DESC, customer_id;
```

Dòng đầu của mỗi khách có `LAG = NULL` → phép trừ ra `NULL` → rơi vào `ELSE 1` (đúng ý: dòng đầu luôn mở một đảo mới).

| | Cách 1 (`m − ROW_NUMBER`) | Cách 2 (`LAG` + `SUM`) |
| --- | --- | --- |
| Độ dài code | Ngắn | Dài hơn |
| Dễ giải thích | Cần hiểu mẹo toán | Trực quan: "đứt thì mở đảo mới" |
| Khi nào dùng | Khi chắc tay, muốn nhanh | Khi cần mở rộng điều kiện đứt quãng (khác "hơn 1") |

### 1.6 Biến thể hay gặp

**a) Tìm các khoảng trống (gaps):** khách bỏ lỡ những tháng nào?

```sql
WITH monthly AS (
  SELECT DISTINCT customer_id,
         CAST(strftime('%Y', order_date) AS INTEGER) * 12
       + CAST(strftime('%m', order_date) AS INTEGER) AS m
  FROM orders
)
SELECT customer_id, m + 1 AS gap_from, next_m - 1 AS gap_to
FROM (SELECT customer_id, m, LEAD(m) OVER (PARTITION BY customer_id ORDER BY m) AS next_m FROM monthly)
WHERE next_m - m > 1;
```

Trên Ví dụ 1, kết quả `customer_id = 2, gap_from = 24290, gap_to = 24290` tức là khách 2 bỏ tháng **2024-02** (từ chỉ số tháng đổi ngược lại: `24290 = 2024*12 + 2`).

**b) Chuỗi dài nhất kèm ngày bắt đầu/kết thúc:** ở bước 4a thêm `MIN(order_date)`, `MAX(order_date)` vào `streaks`, rồi dùng `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY streak_len DESC, ...) = 1` (xem E6 nếu có đồng hạng).

**c) Chuỗi **hiện tại** (đang diễn ra):** lấy đảo có `MAX(month_idx)` bằng tháng cuối cùng của dữ liệu.

**d) Ngày liên tiếp (login streak):** thay `month_idx` bằng `CAST(julianday(order_date) AS INTEGER)`; mọi thứ còn lại giữ nguyên.

### 1.7 Bẫy cần tự kiểm tra

1. **Quên `DISTINCT`** ở bước 1 → nhiều dòng cùng đơn vị làm hỏng nhãn đảo.
2. **Chỉ lấy `tháng` mà không kèm `năm`** → mất tính liên tiếp khi vắt qua năm.
3. **Quên `PARTITION BY customer_id`** → chuỗi chạy xuyên qua các khách khác nhau.
4. `order_date` là `TEXT`: phải đúng dạng `YYYY-MM-DD` thì `strftime` mới hoạt động, nếu sai trả `NULL`.
5. **`ORDER BY` kết quả cuối** có tiebreaker `customer_id` như đề yêu cầu.

---

## Phần 2. RFM

### 2.1 Nhận diện nhanh

Đề nói *"phân khúc khách hàng"*, *"khách VIP / sắp rời bỏ"*, hoặc cho các chỉ số *gần đây, tần suất, giá trị*. Công thức là **một lần `GROUP BY customer_id`** với ba phép tổng hợp.

| Chỉ số | Ý nghĩa | Biểu thức |
| --- | --- | --- |
| **R**ecency | Mua gần nhất cách bao nhiêu ngày | `ngày_chốt − MAX(order_date)` |
| **F**requency | Số đơn | `COUNT(*)` |
| **M**onetary | Tổng tiền | `SUM(total_amount)` |

### 2.2 Ba quyết định phải nói rõ khi làm bài

1. **Ngày chốt (`as_of_date`) cố định**, không dùng `CURRENT_DATE`, để kết quả không đổi theo ngày chạy. Cách của đề: ngày sau đơn hoàn tất mới nhất.
2. **Chỉ tính đơn hợp lệ** (`status = 'Completed'`) trong `WHERE`.
3. **Nhóm theo `customer_id`**, không nhóm theo tên (tên có thể trùng, xem D1).

### 2.3 Tính R, F, M rồi chấm điểm bằng `NTILE`

Phần chấm điểm (1–5) là thứ đề thực tế hay hỏi tiếp, bài học gốc chưa có. `NTILE(n)` chia đều khách thành n nhóm theo thứ tự.

```sql
WITH as_of AS (
  SELECT DATE(MAX(order_date), '+1 day') AS as_of_date
  FROM orders WHERE status = 'Completed'
),
rfm AS (
  SELECT o.customer_id,
         CAST(julianday(a.as_of_date) - julianday(MAX(o.order_date)) AS INTEGER) AS recency_days,
         COUNT(*)            AS frequency,
         SUM(o.total_amount) AS monetary
  FROM orders o CROSS JOIN as_of a
  WHERE o.status = 'Completed'
  GROUP BY o.customer_id, a.as_of_date
)
SELECT customer_id, recency_days, frequency, monetary,
       NTILE(5) OVER (ORDER BY recency_days DESC, customer_id) AS r_score,   -- DESC: xa nhất = 1, gần nhất = 5
       NTILE(5) OVER (ORDER BY frequency,        customer_id)  AS f_score,
       NTILE(5) OVER (ORDER BY monetary,         customer_id)  AS m_score
FROM rfm;
```

**Quy tắc chiều sắp xếp (hay sai nhất):** với R thì **số ngày càng nhỏ càng tốt**, nên phải `ORDER BY recency_days DESC` để người mua gần đây nhận **điểm cao**. F và M thì càng lớn càng tốt nên `ORDER BY ... ASC` (mặc định).

**Input** — Table `orders` (sample)

| order_id | customer_id | order_date | total_amount | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-05 | 100 | Completed |
| 2 | 1 | 2024-02-10 | 200 | Completed |
| 3 | 2 | 2024-02-20 | 50 | Completed |
| 4 | 3 | 2024-01-15 | 500 | Completed |
| 5 | 3 | 2024-01-20 | 300 | Cancelled |

Ngày chốt = `2024-02-21` (sau đơn hoàn tất mới nhất 2024-02-20). Đơn 5 bị loại vì `Cancelled`. Demo dùng `NTILE(3)` cho 3 khách.

**Output**

| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 11 | 2 | 300 | 2 | 3 | 2 |
| 2 | 1 | 1 | 50 | 3 | 1 | 1 |
| 3 | 37 | 1 | 500 | 1 | 2 | 3 |

Thêm `customer_id` vào `ORDER BY` trong `NTILE` để **các giá trị bằng nhau (ties) được chia xác định**, không ngẫu nhiên (cùng lý do với E6).

### 2.4 Gắn nhãn phân khúc (`CASE`)

```sql
SELECT customer_id,
       CASE
         WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
         WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
         WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
         WHEN r_score <= 2                                   THEN 'Lost'
         ELSE 'Others'
       END AS segment
FROM scored;   -- scored = truy vấn chấm điểm ở trên
```

`CASE` dừng ở nhánh đúng **đầu tiên**, nên xếp nhánh **cụ thể trước, chung sau**.

### 2.5 Gap Analysis (mục tiêu vs thực tế)

```sql
SELECT month, target_amount, actual_amount,
       actual_amount - target_amount AS gap,
       ROUND(100.0 * actual_amount / NULLIF(target_amount, 0), 1) AS attainment_pct
FROM sales_targets;
```

`100.0 *` đặt **trước** để tránh chia số nguyên, `NULLIF` để tránh chia cho 0 (xem A5).

### 2.6 Bẫy RFM

1. `GROUP BY full_name` thay vì `customer_id` → gộp nhầm khách trùng tên.
2. Quên lọc `status` → tính cả đơn hủy.
3. Dùng ngày hiện tại thay vì ngày chốt cố định.
4. Nhầm chiều điểm R (đã nói ở 2.3).
5. `JOIN` đơn hàng với một bảng có nhiều dòng cho mỗi khách làm `SUM` bị nhân lên (xem C3, C5).

---

## Phần 3. Cohort / Retention

### 3.1 Nhận diện nhanh

Đề nói *"retention"*, *"giữ chân"*, *"khách quay lại sau n tháng"*, *"nhóm theo tháng mua đầu tiên"*. Ba bước:

1. **Cohort của khách** = tháng mua đầu tiên của chính khách đó.
2. **Month offset** = khoảng cách (bao nhiêu tháng) giữa tháng đơn hàng và tháng cohort (tháng 0, 1, 2, ...).
3. **Retention** = số khách còn hoạt động ở offset đó ÷ **quy mô cohort** (số khách ở offset 0).

### 3.2 Lời giải (đã bổ sung `month_offset`)

Bản gốc của bài học xuất ra `cohort_month × order_month` mà chưa tính offset; khi làm bài thật gần như luôn bị yêu cầu *"tháng thứ n sau khi mua lần đầu"*, nên tôi thêm cột này.

```sql
WITH orders_clean AS (                                  -- mỗi (khách, tháng) một dòng
  SELECT DISTINCT customer_id, strftime('%Y-%m', order_date) AS order_month
  FROM orders WHERE status = 'Completed'
),
with_cohort AS (                                        -- gắn tháng mua đầu tiên cho mỗi khách
  SELECT customer_id, order_month,
         MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
  FROM orders_clean
),
activity AS (                                           -- đếm khách theo (cohort, offset)
  SELECT cohort_month,
         (CAST(substr(order_month,  1, 4) AS INTEGER) * 12 + CAST(substr(order_month,  6, 2) AS INTEGER))
       - (CAST(substr(cohort_month, 1, 4) AS INTEGER) * 12 + CAST(substr(cohort_month, 6, 2) AS INTEGER)) AS month_offset,
         COUNT(DISTINCT customer_id) AS active_customers
  FROM with_cohort
  GROUP BY cohort_month, month_offset
)
SELECT cohort_month, month_offset, active_customers,
       ROUND(100.0 * active_customers /
             FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1) AS retention_pct
FROM activity
ORDER BY cohort_month, month_offset;
```

- `MIN(order_month)` chạy đúng trên chuỗi `'YYYY-MM'` vì thứ tự từ điển trùng thứ tự thời gian.
- Offset 0 luôn tồn tại cho mọi cohort (theo định nghĩa), nên `FIRST_VALUE(...)` chính là **quy mô cohort**. `FIRST_VALUE` không bị bẫy frame như `LAST_VALUE` (F3).
- Phép tính offset dùng đúng mẹo `năm*12 + tháng` của Phần 1.

**Input** — Table `orders` (sample, đều `Completed`)

| order_id | customer_id | order_date |
| --- | --- | --- |
| 1 | 1 | 2023-11-10 |
| 2 | 1 | 2023-12-05 |
| 3 | 1 | 2024-01-15 |
| 4 | 1 | 2024-02-20 |
| 5 | 2 | 2024-01-08 |
| 6 | 2 | 2024-03-12 |
| 7 | 3 | 2024-01-20 |

**Output**

| cohort_month | month_offset | active_customers | retention_pct |
| --- | --- | --- | --- |
| 2023-11 | 0 | 1 | 100.0 |
| 2023-11 | 1 | 1 | 100.0 |
| 2023-11 | 2 | 1 | 100.0 |
| 2023-11 | 3 | 1 | 100.0 |
| 2024-01 | 0 | 2 | 100.0 |
| 2024-01 | 2 | 1 | 50.0 |

Cohort `2024-01` có 2 khách (2 và 3); sau 2 tháng chỉ khách 2 quay lại → 50%. **Lưu ý:** không có dòng `month_offset = 1` cho cohort này vì không ai mua ở tháng đó. Query chỉ trả về những tổ hợp **có dữ liệu**. Cần ma trận đầy đủ (hiển thị 0%) thì phải tạo bảng lịch các offset rồi `LEFT JOIN`.

### 3.3 Pivot thành ma trận retention

SQLite không có `PIVOT`. Dùng **conditional aggregation** với số cột cố định:

```sql
SELECT cohort_month,
       MAX(CASE WHEN month_offset = 0 THEN retention_pct END) AS m0,
       MAX(CASE WHEN month_offset = 1 THEN retention_pct END) AS m1,
       MAX(CASE WHEN month_offset = 2 THEN retention_pct END) AS m2,
       MAX(CASE WHEN month_offset = 3 THEN retention_pct END) AS m3
FROM retention          -- retention = truy vấn ở 3.2 viết thành CTE
GROUP BY cohort_month;
```

Ô không có dữ liệu ra `NULL` (có thể bọc `COALESCE(..., 0)` nếu đề muốn 0).

### 3.4 Bẫy Cohort

1. **Quên `DISTINCT` / `COUNT(DISTINCT customer_id)`** → một khách mua nhiều đơn cùng tháng bị đếm nhiều lần, retention vượt 100%.
2. **Lấy cohort từ bảng đã lọc sai**: cohort phải tính trên cùng tập đơn hợp lệ (`Completed`) với phần hoạt động.
3. **Chia cho sai mẫu số**: mẫu số là quy mô cohort (offset 0), không phải tổng số khách toàn hệ thống.
4. **Nhầm `order_month` với `month_offset`** khi đề hỏi "tháng thứ n".
5. **Offset thiếu dòng** khi không ai hoạt động (xem ghi chú trên).

---

## Phần 4. Chiến lược làm bài nhanh

**Quy trình 5 bước cho mọi đề SQL phân tích** (khoảng 10–15 phút mỗi bài):

1. **Xác định grain (đơn vị phân tích):** kết quả cuối mỗi dòng là gì (một khách? một cặp cohort-offset?). Viết ra trước khi gõ query.
2. **Nhận dạng pattern:** "liên tiếp" → Gaps & Islands; "gần đây, thường xuyên, tổng tiền" → RFM; "giữ chân theo tháng đầu tiên" → Cohort.
3. **Viết từng CTE, mỗi CTE một việc**, và chạy thử sau mỗi CTE trên dữ liệu mẫu của đề (thường chỉ 4–6 dòng, nhẩm được).
4. **Đối chiếu với Expected result của cả hai ví dụ**, ví dụ 2 thường chứa bẫy (trùng ngày, trùng tháng).
5. **Rà checklist bẫy** của dạng đó, rồi kiểm tra `ORDER BY` cuối đúng yêu cầu đề (ví dụ chuỗi giảm dần, bằng nhau thì mã nhỏ trước).

**Bảng thuộc lòng**

| Đề nói | Công thức |
| --- | --- |
| Chuỗi liên tiếp dài nhất | `DISTINCT` → số nguyên liên tục → `x − ROW_NUMBER()` → `GROUP BY` → `MAX(COUNT)` |
| Tháng liên tiếp qua năm | `năm*12 + tháng` |
| Khoảng trống giữa các giá trị | `LEAD(x) − x > 1` |
| Số ngày kể từ lần mua cuối | `ngày_chốt − MAX(order_date)`, ngày chốt cố định |
| Chấm điểm 1–5 | `NTILE(5) OVER (ORDER BY ... , id)`, R thì `DESC` |
| Cohort | `MIN(tháng) OVER (PARTITION BY khách)` + offset `năm*12+tháng` |
| Retention % | `active ÷ FIRST_VALUE(active)` theo cohort |

**Liên hệ tài liệu chính** ([sql-common-pitfalls.md](sql-common-pitfalls.md)): `DISTINCT` che lỗi (C5), fan-out (C3), ties trong xếp hạng (E6), chia cho 0 (A5), frame của window (F2, F3).
