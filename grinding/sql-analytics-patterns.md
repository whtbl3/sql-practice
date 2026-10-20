# SQL phân tích thực chiến: Gaps & Islands, RFM, Cohort, Funnel, chỉ số và Dashboard

> Phương ngữ: **PostgreSQL** (đúng engine của `check.py`). Mọi query và output dưới đây đã **chạy thật bằng `check.py`** với dữ liệu mẫu đi kèm.
> Cách học: nhận ra dạng bài → áp công thức → kiểm tra bẫy. Mỗi dạng chỉ có **một công thức**, thuộc nó là đủ.
> Bẫy chung (NULL, chia số nguyên, fan-out, frame của window) nằm ở [sql-common-pitfalls.md](sql-common-pitfalls.md); tài liệu này trỏ tới bằng mã mục (A5, C3, E6, F2…).

**Mục lục**

| Phần | Dạng bài | Bài tập |
| --- | --- | --- |
| 0 | Bản đồ: dạng bài nào trả lời câu hỏi gì, CTE + Window, bẫy thiếu dòng | |
| 1 | Gaps & Islands, chuỗi giảm liên tiếp | `islands/*`, `sessions/01` |
| 2 | RFM | `cohort/02` |
| 3 | Cohort / Retention | `cohort/01`, `03`, `04` |
| 4 | Funnel (phễu) | `funnel/01`, `02` |
| 5 | Chỉ số: tỷ lệ so với tổng, biên lợi nhuận, Gap Analysis, running total có điều kiện, Top N | `misc/01`, `02`, `topn/*` |
| 6 | Dashboard tổng hợp | `misc/03` |
| 7 | Chiến lược làm bài và bảng thuộc lòng | |

---

## Phần 0. Bản đồ: dạng bài nào trả lời câu hỏi gì

Đọc phần này trước. Mỗi dạng bài là **một câu hỏi nghiệp vụ** đi kèm **một kỹ thuật**. Nhận ra câu hỏi thì biết ngay kỹ thuật.

### 0.1 Bảng tổng quan

| Dạng bài | Câu hỏi nghiệp vụ | Kỹ thuật cốt lõi | Cách làm (tóm tắt) | Mục |
| --- | --- | --- | --- | --- |
| Gaps & Islands | Khách duy trì hoạt động **liên tục** bao lâu? Bỏ lỡ những kỳ nào? | `ROW_NUMBER`, `LAG`/`LEAD` | Khử trùng → đổi ra số liên tục → `x − ROW_NUMBER` làm nhãn đảo → `GROUP BY` nhãn | 1.2–1.6 |
| Sessionization | Một lượt truy cập gồm những sự kiện nào? | `LAG` + `SUM` cờ | Cờ "nghỉ quá ngưỡng" → cộng dồn cờ thành số phiên | 1.6e |
| Consecutive Decline | Sản phẩm/chỉ số nào **đang đi xuống** nhiều kỳ liền (cảnh báo sớm)? | `LAG` + `SUM` cờ | Cờ "thấp hơn kỳ trước" → gom run → `HAVING COUNT >= N` | 1.7 |
| RFM | Khách **hiện tại** đang ở nhóm nào: VIP, trung thành, sắp rời bỏ? | `GROUP BY`, `NTILE`, `CASE` | R/F/M theo khách với ngày chốt cố định → chấm điểm `NTILE` → gắn nhãn `CASE` | 2 |
| Cohort / Retention | Khách **ở lại bao lâu** sau lần đầu? Nhóm nào giữ chân tốt hơn? | `MIN() OVER`, `FIRST_VALUE` | Cohort = tháng đầu → offset tháng → đếm khách ÷ quy mô cohort | 3 |
| Funnel | Khách **rơi rụng ở bước nào** trong hành trình? | `BOOL_OR` / `MIN() FILTER`, `COUNT FILTER` | Một dòng mỗi user với cờ từng bước → đếm có điều kiện "đã qua bước trước" | 4 |
| Tỷ lệ so với tổng | Sản phẩm/danh mục **đóng góp bao nhiêu phần**? | `SUM(SUM()) OVER` | Phần ÷ tổng bằng window không `ORDER BY` | 5.1 |
| Biên lợi nhuận | Bán cái gì thực sự **có lãi**? | `SUM`, `NULLIF` | `SUM(lãi) ÷ SUM(doanh thu)`, không lấy trung bình các biên | 5.2 |
| Gap Analysis | Kinh doanh **đạt kế hoạch** chưa, hụt bao nhiêu? | `LEFT JOIN`, `COALESCE` | Gộp thực tế về grain của mục tiêu → `LEFT JOIN` từ mục tiêu → chênh lệch, % đạt | 5.3 |
| Running total có điều kiện | Lũy kế tới nay bao nhiêu, khi nào chạm ngưỡng? | `SUM() FILTER OVER`, `PARTITION BY` | Đưa điều kiện vào trong hàm, reset bằng `PARTITION BY` | 5.4 |
| Top N per group | Ai/cái gì đứng đầu **trong từng nhóm**? | `ROW_NUMBER` / `RANK` / `DENSE_RANK` | Xếp hạng trong subquery → lọc ở ngoài | 5.5 |
| MoM / so kỳ trước | Kỳ này tăng hay giảm so với kỳ trước bao nhiêu %? | `LAG` | `(nay − trước) ÷ NULLIF(trước, 0)` | 6 |
| Dashboard | Bức tranh tổng thể theo tháng | CTE nhiều tầng + window | Lọc → gộp về grain tháng → window so sánh | 6 |

### 0.2 Các dạng bổ sung cho nhau, không thay thế nhau

| | RFM | Cohort | Funnel | Gap Analysis |
| --- | --- | --- | --- | --- |
| Góc nhìn | **Ảnh chụp** tại một ngày chốt | **Theo thời gian** từ lần đầu | **Theo hành trình** từng bước | **So với kế hoạch** |
| Mỗi dòng kết quả | Một khách | Một (cohort, offset) | Một bước | Một kỳ (hoặc kỳ × đơn vị) |
| Trả lời | Khách **đang** thế nào? | Khách **ở lại** bao lâu? | Khách **rơi** ở đâu? | Doanh nghiệp **đạt** chưa? |
| Dùng để | Phân khúc khách hàng (customer segmentation): chọn ai để chăm sóc, ai cần kéo lại | Đo hiệu quả giữ chân, so sánh các đợt khách | Tìm bước cần cải thiện trong sản phẩm | Đánh giá hiệu quả kinh doanh, tìm kỳ/đơn vị hụt chỉ tiêu |

Ví dụ kết hợp: cohort cho thấy khách tháng 3 rời bỏ nhanh → RFM tìm trong số đó ai còn giá trị cao (M cao, R đang xấu đi) để gửi ưu đãi → Gap Analysis đo xem doanh thu sau chiến dịch đã bù được phần hụt chỉ tiêu chưa.

### 0.3 Vì sao gần như bài nào cũng là CTE + Window

- **CTE** chia bài thành các bước, mỗi bước một việc, chạy thử được từng bước.
- **Window function** tính so sánh (với dòng trước, với tổng, với hạng) **mà không gộp mất dòng** như `GROUP BY`.
- Khung chung của hầu hết bài phân tích:

```text
CTE 1: lọc dữ liệu hợp lệ (status, khoảng thời gian)
CTE 2: gộp về đúng grain (khách, tháng, khách × tháng…)
CTE 3: window function để so sánh / xếp hạng / đánh dấu
SELECT cuối: lọc, định dạng, ORDER BY
```

**Câu hỏi nào → hàm window nào:**

| Câu hỏi | Hàm |
| --- | --- |
| So với dòng trước/sau (tăng giảm, khoảng cách, liên tiếp) | `LAG`, `LEAD` |
| Chiếm bao nhiêu % tổng/nhóm | `SUM(x) OVER ()`, `SUM(x) OVER (PARTITION BY …)` |
| Lũy kế tới hiện tại | `SUM(x) OVER (ORDER BY …)` |
| Đứng thứ mấy, lấy top N | `ROW_NUMBER`, `RANK`, `DENSE_RANK` |
| Chia khách thành n nhóm đều nhau (chấm điểm) | `NTILE(n)` |
| Giá trị đầu tiên/nhỏ nhất của nhóm gắn vào mọi dòng (cohort, mẫu số) | `MIN() OVER (PARTITION BY …)`, `FIRST_VALUE` |
| Đánh số đảo/phiên/nhóm reset | `SUM(cờ) OVER (ORDER BY …)` |

### 0.4 Nguyên tắc chung: `GROUP BY` chỉ sinh ra nhóm **có dữ liệu**

Đây là bẫy xuất hiện ở **mọi dạng có trục thời gian hoặc danh sách bước**: kỳ/bước không có hoạt động **bị thiếu dòng**, không tự hiện ra với giá trị 0.

| Dạng | Bị thiếu gì | Hậu quả nếu không xử lý |
| --- | --- | --- |
| Cohort | Ô (cohort, offset) không ai hoạt động | Ma trận lủng ô, tưởng chưa có dữ liệu thay vì retention 0 |
| Dashboard / MoM | Tháng không có đơn | `LAG` so với tháng cách xa hơn, MoM sai |
| Gap Analysis | Tháng có mục tiêu nhưng không có doanh số | Mất đúng tháng tệ nhất |
| Funnel dạng dọc | Bước không ai đạt | Bước đó biến mất khỏi phễu |

**Cách xử lý:** tạo **khung đầy đủ** trước, rồi `LEFT JOIN` dữ liệu vào và điền giá trị thiếu.

| Khung | Cách tạo | Ví dụ |
| --- | --- | --- |
| Lịch tháng/ngày | `generate_series(min, max, INTERVAL '1 month')` | 3.5c, Phần 6 |
| Danh sách bước | `VALUES (1, 'view'), (2, 'cart'), …` | 4.3 |
| Bảng mục tiêu có sẵn | Đi từ bảng mục tiêu: `FROM targets LEFT JOIN actual` | 5.3 |

**Điền 0 hay để `NULL` là quyết định nghiệp vụ**, không phải kỹ thuật: retention của tháng không ai quay lại là **0%** (`COALESCE(…, 0)`), nhưng MoM khi tháng trước bằng 0 là **không xác định** (`NULL`, nhờ `NULLIF`). Đọc đề xem họ muốn thấy gì; đề không nói thì giữ đúng những dòng có dữ liệu.

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

| Đơn vị | Biểu thức (PostgreSQL) |
| --- | --- |
| Tháng (**vắt qua năm được**) | `EXTRACT(YEAR FROM d)::int * 12 + EXTRACT(MONTH FROM d)::int` |
| Ngày (cột `DATE`) | Dùng thẳng `d`: `d - ROW_NUMBER() OVER (...)::int` ra một **ngày** làm nhãn đảo |
| Tuần | `(d - DATE '2000-01-03') / 7` (2000-01-03 là thứ Hai, chia nguyên ra số tuần) |

> Vì sao dùng `năm*12 + tháng`: nếu chỉ lấy `tháng` thì tháng 12 → tháng 1 là `12 → 1`, không liên tiếp. Với `năm*12 + tháng`, `2023-12 = 24288` và `2024-01 = 24289`, tự nhiên hơn kém 1. Đây là **điểm bẫy chính** của dạng "chuỗi được phép vắt qua năm mới".

### 1.4 Lời giải mẫu: chuỗi tháng liên tiếp dài nhất (có chú thích từng bước)

```sql
WITH monthly AS (                                   -- Bước 1 + 2: mỗi (khách, tháng) một dòng
  SELECT DISTINCT customer_id,
         EXTRACT(YEAR FROM order_date)::int * 12 + EXTRACT(MONTH FROM order_date)::int AS month_idx
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

**Trace** (khách 1: 2023-11, 2023-12, 2024-01, 2024-02; khách 2: 2024-01, 2024-03)

| customer_id | month_idx | row_number | grp | Ghi chú |
| --- | --- | --- | --- | --- |
| 1 | 24287 | 1 | 24286 | cùng `grp` → một đảo 4 tháng |
| 1 | 24288 | 2 | 24286 | |
| 1 | 24289 | 3 | 24286 | |
| 1 | 24290 | 4 | 24286 | |
| 2 | 24289 | 1 | 24288 | |
| 2 | 24291 | 2 | 24289 | `grp` khác → hai đảo, mỗi đảo dài 1 |

**Output**

| customer_id | longest_streak |
| --- | --- |
| 1 | 4 |
| 2 | 1 |

Nếu khách 1 có **hai đơn trong tháng 1** mà quên `DISTINCT` thì `month_idx` bị lặp (24289, 24289, 24290), `ROW_NUMBER` vẫn tăng nên `grp` lệch và chuỗi bị tách sai.

### 1.5 Cách giải thứ hai: `LAG` + tổng tích lũy (dễ đọc, dễ mở rộng điều kiện)

```sql
WITH monthly AS (
  SELECT DISTINCT customer_id,
         EXTRACT(YEAR FROM order_date)::int * 12 + EXTRACT(MONTH FROM order_date)::int AS m
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
FROM (SELECT customer_id, island_id, COUNT(*) AS cnt
      FROM numbered GROUP BY customer_id, island_id) s       -- PostgreSQL bắt buộc alias subquery
GROUP BY customer_id
ORDER BY longest_streak DESC, customer_id;
```

Dòng đầu của mỗi khách có `LAG = NULL` → phép trừ ra `NULL` → rơi vào `ELSE 1` (đúng ý: dòng đầu luôn mở một đảo mới).

| | Cách 1 (`m − ROW_NUMBER`) | Cách 2 (`LAG` + `SUM`) |
| --- | --- | --- |
| Độ dài code | Ngắn | Dài hơn |
| Dễ giải thích | Cần hiểu mẹo toán | Trực quan: "đứt thì mở đảo mới" |
| Khi nào dùng | Khi đơn vị là số nguyên/ngày liên tục | Khi điều kiện đứt quãng **không phải "hơn 1"**: khoảng cách > 30 phút (1.6e), doanh thu giảm (1.7) |

### 1.6 Biến thể hay gặp

**a) Tìm các khoảng trống (gaps):** khách bỏ lỡ những tháng nào? Dùng `LEAD` để nhìn dòng kế tiếp; khoảng trống là chỗ dòng kế cách hơn 1 đơn vị.

```sql
WITH monthly AS (
  SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS m
  FROM orders
),
nexted AS (
  SELECT customer_id, m, LEAD(m) OVER (PARTITION BY customer_id ORDER BY m) AS next_m
  FROM monthly
)
SELECT customer_id,
       (m + INTERVAL '1 month')::date      AS gap_from,
       (next_m - INTERVAL '1 month')::date AS gap_to
FROM nexted
WHERE next_m > m + INTERVAL '1 month'
ORDER BY customer_id, gap_from;
```

Với dữ liệu ở 1.4, output là `customer_id = 2, gap_from = 2024-02-01, gap_to = 2024-02-01`: khách 2 bỏ tháng 2. Với số nguyên (số hóa đơn, `islands/03`) thì viết gọn: `WHERE next_no - no > 1`, `gap_start = no + 1`, `gap_end = next_no - 1`.

**b) Liệt kê mọi đảo kèm ngày bắt đầu/kết thúc** (`islands/05`); **d) đơn vị là ngày** (`islands/02`). Với cột `DATE`, trừ thẳng số thứ tự ra một ngày làm nhãn đảo:

```sql
WITH d AS (SELECT DISTINCT user_id, login_date FROM logins),
g AS (
  SELECT user_id, login_date,
         login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
  FROM d
)
SELECT user_id, MIN(login_date) AS start_date, MAX(login_date) AS end_date, COUNT(*) AS days
FROM g
GROUP BY user_id, grp
ORDER BY user_id, start_date;
```

**Input** `logins`: user 1 đăng nhập 01-01, 01-02 (hai lần), 01-03, 01-05; user 2 đăng nhập 2024-02-28, 02-29, 03-01.

| user_id | start_date | end_date | days |
| --- | --- | --- | --- |
| 1 | 2024-01-01 | 2024-01-03 | 3 |
| 1 | 2024-01-05 | 2024-01-05 | 1 |
| 2 | 2024-02-28 | 2024-03-01 | 3 |

- **Phải có `::int`**: `ROW_NUMBER()` trả `bigint`, mà PostgreSQL không có phép `date - bigint` (lỗi `operator does not exist: date - bigint`).
- Phép trừ ngày tự xử lý năm nhuận và cuối tháng (02-28 → 02-29 → 03-01 vẫn liên tiếp).
- Muốn **chuỗi dài nhất kèm ngày**: lấy kết quả trên rồi `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY days DESC, start_date) = 1` (xem E6 nếu có đồng hạng).

**c) Chuỗi hiện tại (đang diễn ra)** (`islands/04`): giữ lại đúng đảo chứa ngày hoạt động **cuối cùng** của người đó.

```sql
WITH d AS (SELECT DISTINCT user_id, login_date FROM logins),
g AS (
  SELECT user_id, login_date,
         login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
  FROM d
),
isl AS (
  SELECT user_id, COUNT(*) AS len, MAX(login_date) AS last_day
  FROM g GROUP BY user_id, grp
)
SELECT user_id, len AS current_streak
FROM isl i
WHERE last_day = (SELECT MAX(login_date) FROM logins l WHERE l.user_id = i.user_id)
ORDER BY user_id;
```

Cùng dữ liệu trên: user 1 → `1` (chuỗi cuối chỉ có ngày 01-05, dù chuỗi dài nhất là 3), user 2 → `3`. Nếu đề nói "hiện tại" là **so với một ngày chốt** (ví dụ hôm nay) thì thêm điều kiện `last_day = ngày_chốt`, người không hoạt động ngày đó có chuỗi 0.

**e) Chia phiên (sessionization)** (`sessions/01`): phiên mới bắt đầu khi khoảng cách tới sự kiện trước **lớn hơn 30 phút**. Điều kiện đứt quãng là một ngưỡng, nên dùng cách 2:

```sql
WITH flagged AS (
  SELECT user_id, event_time,
         CASE WHEN event_time - LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time)
                   > INTERVAL '30 minutes' THEN 1 ELSE 0 END AS new_session
  FROM events
),
numbered AS (
  SELECT user_id, event_time,
         1 + SUM(new_session) OVER (PARTITION BY user_id ORDER BY event_time) AS session_no
  FROM flagged
)
SELECT user_id, session_no, MIN(event_time) AS session_start, MAX(event_time) AS session_end,
       COUNT(*) AS events
FROM numbered
GROUP BY user_id, session_no
ORDER BY user_id, session_no;
```

| user_id | session_no | session_start | session_end | events |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-01 09:00:00 | 2024-01-01 09:20:00 | 2 |
| 1 | 2 | 2024-01-01 10:05:00 | 2024-01-01 10:05:00 | 1 |
| 2 | 1 | 2024-01-01 08:00:00 | 2024-01-01 08:00:00 | 1 |

Ở đây dòng đầu có `LAG = NULL` → `ELSE 0`, nên phải `1 +` để phiên đầu là số 1. Ngược với 1.5 (ở đó dòng đầu rơi vào `ELSE 1`). Tự kiểm tra dòng đầu mỗi lần viết.

### 1.7 Chuỗi giảm liên tiếp (Consecutive Decline)

**Đề:** tìm các sản phẩm có doanh thu **giảm liên tiếp ít nhất 3 tháng** (mỗi tháng thấp hơn tháng trước). Trả về tháng giảm đầu tiên, tháng giảm cuối cùng, số tháng giảm.

Đây vẫn là Gaps & Islands, nhưng "đảo" là **các dòng thỏa một điều kiện so với dòng trước**, không phải các giá trị hơn kém 1. Công thức:

1. `LAG` gắn cờ `is_down` cho từng dòng.
2. Dòng **không** giảm thì mở một "run" mới: `SUM(CASE WHEN is_down THEN 0 ELSE 1 END) OVER (...)`.
3. Chỉ giữ dòng `is_down`, `GROUP BY run_id`, `HAVING COUNT(*) >= 3`.

```sql
WITH flagged AS (
  SELECT product, month, revenue,
         revenue < LAG(revenue) OVER (PARTITION BY product ORDER BY month) AS is_down
  FROM monthly_sales
),
runs AS (
  SELECT product, month, is_down,
         SUM(CASE WHEN is_down THEN 0 ELSE 1 END)
           OVER (PARTITION BY product ORDER BY month) AS run_id
  FROM flagged
)
SELECT product, MIN(month) AS first_down, MAX(month) AS last_down, COUNT(*) AS months_down
FROM runs
WHERE is_down
GROUP BY product, run_id
HAVING COUNT(*) >= 3
ORDER BY product, first_down;
```

**Trace** (`monthly_sales`, mỗi sản phẩm một dòng mỗi tháng)

| product | month | revenue | is_down | run_id |
| --- | --- | --- | --- | --- |
| A | 2024-01-01 | 100 | NULL | 1 |
| A | 2024-02-01 | 90 | true | 1 |
| A | 2024-03-01 | 80 | true | 1 |
| A | 2024-04-01 | 70 | true | 1 |
| A | 2024-05-01 | 75 | false | 2 |
| B | 2024-01-01 | 50 | NULL | 1 |
| B | 2024-02-01 | 40 | true | 1 |
| B | 2024-03-01 | 45 | false | 2 |
| B | 2024-04-01 | 30 | true | 2 |
| B | 2024-05-01 | 20 | true | 2 |

**Output**

| product | first_down | last_down | months_down |
| --- | --- | --- | --- |
| A | 2024-02-01 | 2024-04-01 | 3 |

B chỉ có chuỗi giảm dài 1 và 2 nên bị loại.

- `first_down` là tháng **đầu tiên thấp hơn tháng trước**. Nếu đề hỏi "bắt đầu từ đỉnh" thì đỉnh là tháng liền trước `first_down`.
- **Tháng bị thiếu:** query trên giả định mỗi sản phẩm có đủ mọi tháng. Nếu có thể thiếu tháng, phải coi khoảng trống là đứt chuỗi: thêm điều kiện `month = LAG(month) OVER (...) + INTERVAL '1 month'` vào `is_down`, hoặc sinh đủ tháng bằng `generate_series` rồi `LEFT JOIN`.
- Biến thể "tăng liên tiếp", "giá đứng yên liên tiếp" chỉ cần đổi điều kiện trong `is_down`.

### 1.8 Bẫy cần tự kiểm tra

1. **Quên `DISTINCT`** ở bước 1 → nhiều dòng cùng đơn vị làm hỏng nhãn đảo.
2. **Chỉ lấy `tháng` mà không kèm `năm`** → mất tính liên tiếp khi vắt qua năm.
3. **Quên `PARTITION BY`** → chuỗi chạy xuyên qua các khách khác nhau.
4. **`date - ROW_NUMBER()` thiếu `::int`** → lỗi kiểu `date - bigint`.
5. **Dòng đầu tiên của `LAG` là `NULL`**: tự hỏi dòng đầu nên mở đảo mới (`ELSE 1`) hay không (`ELSE 0` rồi `1 +`).
6. **`ORDER BY` kết quả cuối** có tiebreaker (`customer_id`) như đề yêu cầu.

---

## Phần 2. RFM

### 2.1 Nhận diện nhanh

**Dùng để làm gì:** RFM là nền tảng của **phân khúc khách hàng** (customer segmentation): chụp lại khách **đang** thế nào tại một ngày chốt để chọn ai cần chăm sóc, ai cần kéo lại.

Đề nói *"phân khúc khách hàng"*, *"khách VIP / sắp rời bỏ"*, hoặc cho các chỉ số *gần đây, tần suất, giá trị*. Công thức là **một lần `GROUP BY customer_id`** với ba phép tổng hợp.

| Chỉ số | Ý nghĩa | Biểu thức |
| --- | --- | --- |
| **R**ecency | Mua gần nhất cách bao nhiêu ngày | `ngày_chốt − MAX(order_date)` |
| **F**requency | Số đơn | `COUNT(*)` |
| **M**onetary | Tổng tiền | `SUM(total_amount)` |

### 2.2 Ba quyết định phải nói rõ khi làm bài

1. **Ngày chốt (`as_of_date`) cố định**, không dùng `CURRENT_DATE`, để kết quả không đổi theo ngày chạy. Cách hay dùng: ngày sau đơn hoàn tất mới nhất.
2. **Chỉ tính đơn hợp lệ** (`status = 'Completed'`) trong `WHERE`.
3. **Nhóm theo `customer_id`**, không nhóm theo tên (tên có thể trùng, xem D1).

### 2.3 Tính R, F, M rồi chấm điểm bằng `NTILE` (`cohort/02`)

`NTILE(n)` chia đều khách thành n nhóm theo thứ tự.

```sql
WITH as_of AS (
  SELECT MAX(order_date) + 1 AS as_of_date            -- DATE + số nguyên = ngày
  FROM orders WHERE status = 'Completed'
),
rfm AS (
  SELECT o.customer_id,
         a.as_of_date - MAX(o.order_date) AS recency_days,   -- DATE − DATE = số ngày (int)
         COUNT(*)            AS frequency,
         SUM(o.total_amount) AS monetary
  FROM orders o CROSS JOIN as_of a
  WHERE o.status = 'Completed'
  GROUP BY o.customer_id, a.as_of_date
)
SELECT customer_id, recency_days, frequency, monetary,
       NTILE(3) OVER (ORDER BY recency_days DESC, customer_id) AS r_score,   -- DESC: xa nhất = 1, gần nhất = 3
       NTILE(3) OVER (ORDER BY frequency,        customer_id)  AS f_score,
       NTILE(3) OVER (ORDER BY monetary,         customer_id)  AS m_score
FROM rfm
ORDER BY customer_id;
```

**Quy tắc chiều sắp xếp (hay sai nhất):** với R thì **số ngày càng nhỏ càng tốt**, nên phải `ORDER BY recency_days DESC` để người mua gần đây nhận **điểm cao**. F và M thì càng lớn càng tốt nên `ORDER BY ... ASC` (mặc định).

**Input** — Table `orders`

| order_id | customer_id | order_date | total_amount | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-05 | 100 | Completed |
| 2 | 1 | 2024-02-10 | 200 | Completed |
| 3 | 2 | 2024-02-20 | 50 | Completed |
| 4 | 3 | 2024-01-15 | 500 | Completed |
| 5 | 3 | 2024-01-20 | 300 | Cancelled |

Ngày chốt = `2024-02-21` (sau đơn hoàn tất mới nhất 2024-02-20). Đơn 5 bị loại vì `Cancelled`. Dữ liệu chỉ có 3 khách nên dùng `NTILE(3)`; đề thật thường dùng `NTILE(5)`.

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
FROM scored;   -- scored = truy vấn chấm điểm ở 2.3 viết thành CTE
```

`CASE` dừng ở nhánh đúng **đầu tiên**, nên xếp nhánh **cụ thể trước, chung sau**. Ngưỡng ở trên dành cho thang 1–5. Với dữ liệu 2.3 (thang 1–3), khách 1 ra `At Risk`, khách 2 ra `Others`, khách 3 ra `Lost`.

### 2.5 Bẫy RFM

1. `GROUP BY full_name` thay vì `customer_id` → gộp nhầm khách trùng tên.
2. Quên lọc `status` → tính cả đơn hủy.
3. Dùng ngày hiện tại thay vì ngày chốt cố định.
4. Nhầm chiều điểm R (đã nói ở 2.3).
5. `JOIN` đơn hàng với một bảng có nhiều dòng cho mỗi khách làm `SUM` bị nhân lên (xem C3, C5).

---

## Phần 3. Cohort / Retention

### 3.1 Nhận diện nhanh

**Dùng để làm gì:** đo **retention theo thời gian**: khách ở lại bao lâu sau lần đầu, và đợt khách nào giữ chân tốt hơn. RFM cho biết khách đang thế nào; cohort cho biết khách ở lại bao lâu.

Đề nói *"retention"*, *"giữ chân"*, *"khách quay lại sau n tháng"*, *"nhóm theo tháng mua đầu tiên"*. Ba bước:

1. **Cohort của khách** = tháng mua đầu tiên của chính khách đó.
2. **Month offset** = khoảng cách (bao nhiêu tháng) giữa tháng đơn hàng và tháng cohort (tháng 0, 1, 2, ...).
3. **Retention** = số khách còn hoạt động ở offset đó ÷ **quy mô cohort** (số khách ở offset 0).

### 3.2 Lời giải mẫu (`cohort/01`)

```sql
WITH orders_clean AS (                                  -- mỗi (khách, tháng) một dòng
  SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
  FROM orders WHERE status = 'Completed'
),
with_cohort AS (                                        -- gắn tháng mua đầu tiên cho mỗi khách
  SELECT customer_id, order_month,
         MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
  FROM orders_clean
),
activity AS (                                           -- đếm khách theo (cohort, offset)
  SELECT cohort_month,
         (EXTRACT(YEAR FROM order_month)::int  * 12 + EXTRACT(MONTH FROM order_month)::int)
       - (EXTRACT(YEAR FROM cohort_month)::int * 12 + EXTRACT(MONTH FROM cohort_month)::int) AS month_offset,
         COUNT(DISTINCT customer_id) AS active_customers
  FROM with_cohort
  GROUP BY cohort_month, month_offset
)
SELECT TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month, month_offset, active_customers,
       ROUND(100.0 * active_customers /
             FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1) AS retention_pct
FROM activity
ORDER BY cohort_month, month_offset;
```

- `DATE_TRUNC('month', ...)` đưa mọi ngày về ngày 1 của tháng; `::date` bỏ phần giờ. `TO_CHAR(..., 'YYYY-MM')` chỉ dùng ở `SELECT` cuối để hiển thị.
- Offset 0 luôn tồn tại cho mọi cohort (theo định nghĩa), nên `FIRST_VALUE(...)` chính là **quy mô cohort**. `FIRST_VALUE` không bị bẫy frame như `LAST_VALUE` (F3).
- Phép tính offset dùng đúng mẹo `năm*12 + tháng` của Phần 1.
- `GROUP BY cohort_month, month_offset` dùng được alias của `SELECT`: PostgreSQL cho phép `GROUP BY` theo alias (nhưng `WHERE` thì không, xem E7).

**Input** — Table `orders` (đều `Completed`)

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

Cohort `2024-01` có 2 khách (2 và 3); sau 2 tháng chỉ khách 2 quay lại → 50%. **Lưu ý:** không có dòng `month_offset = 1` cho cohort này vì không ai mua ở tháng đó. Query chỉ trả về những tổ hợp **có dữ liệu** (cách lấp đủ ở 3.5c).

### 3.3 Pivot thành ma trận retention

PostgreSQL không có `PIVOT`. Dùng **conditional aggregation** với số cột cố định; cú pháp `FILTER` gọn hơn `CASE`:

```sql
SELECT cohort_month,
       MAX(retention_pct) FILTER (WHERE month_offset = 0) AS m0,
       MAX(retention_pct) FILTER (WHERE month_offset = 1) AS m1,
       MAX(retention_pct) FILTER (WHERE month_offset = 2) AS m2,
       MAX(retention_pct) FILTER (WHERE month_offset = 3) AS m3
FROM retention          -- retention = truy vấn ở 3.2 viết thành CTE
GROUP BY cohort_month
ORDER BY cohort_month;
```

| cohort_month | m0 | m1 | m2 | m3 |
| --- | --- | --- | --- | --- |
| 2023-11 | 100.0 | 100.0 | 100.0 | 100.0 |
| 2024-01 | 100.0 | NULL | 50.0 | NULL |

Ô không có dữ liệu ra `NULL` (bọc `COALESCE(..., 0)` nếu đề muốn 0). Viết kiểu `MAX(CASE WHEN month_offset = 0 THEN retention_pct END)` cũng cho cùng kết quả.

### 3.4 Bẫy Cohort

1. **Quên `DISTINCT` / `COUNT(DISTINCT customer_id)`** → một khách mua nhiều đơn cùng tháng bị đếm nhiều lần, retention vượt 100%.
2. **Lấy cohort từ bảng đã lọc sai**: cohort phải tính trên cùng tập đơn hợp lệ (`Completed`) với phần hoạt động.
3. **Chia cho sai mẫu số**: mẫu số là quy mô cohort, không phải tổng số khách toàn hệ thống.
4. **Nhầm `order_month` với `month_offset`** khi đề hỏi "tháng thứ n".
5. **Offset thiếu dòng** khi không ai hoạt động (xem 3.5c).

### 3.5 Biến thể hay gặp

**a) Cohort theo tháng đăng ký, có bảng `users` riêng** (`cohort/03`). Khác 3.2 ở hai chỗ:

- Quy mô cohort phải đếm **mọi user đã đăng ký**, kể cả người chưa có sự kiện nào. Vì vậy không dùng được `FIRST_VALUE`: offset 0 có thể không tồn tại hoặc thiếu người.
- Sự kiện **trước** tháng đăng ký cho offset âm, phải loại.

```sql
WITH u AS (
  SELECT user_id, DATE_TRUNC('month', signup_date)::date AS cohort FROM users
),
sizes AS (                                         -- mẫu số lấy từ users, không từ events
  SELECT cohort, COUNT(*) AS cohort_size FROM u GROUP BY cohort
),
act AS (
  SELECT u.cohort,
         (EXTRACT(YEAR FROM e.event_date)::int * 12 + EXTRACT(MONTH FROM e.event_date)::int)
       - (EXTRACT(YEAR FROM u.cohort)::int     * 12 + EXTRACT(MONTH FROM u.cohort)::int) AS month_offset,
         COUNT(DISTINCT u.user_id) AS active_users
  FROM u JOIN events e ON e.user_id = u.user_id
  GROUP BY u.cohort, month_offset
)
SELECT TO_CHAR(a.cohort, 'YYYY-MM') AS cohort_month, a.month_offset, a.active_users,
       ROUND(100.0 * a.active_users / s.cohort_size, 1) AS retention_pct
FROM act a
JOIN sizes s ON s.cohort = a.cohort
WHERE a.month_offset >= 0
ORDER BY cohort_month, a.month_offset;
```

**Input:** `users` gồm user 1 (đăng ký 2024-01-10), user 2 (2024-01-20), user 3 (2024-02-05). `events` gồm user 1 vào 2024-01-12 và 2024-02-15, user 2 vào 2023-12-30 (trước khi đăng ký), user 3 vào 2024-03-01.

| cohort_month | month_offset | active_users | retention_pct |
| --- | --- | --- | --- |
| 2024-01 | 0 | 1 | 50.0 |
| 2024-01 | 1 | 1 | 50.0 |
| 2024-02 | 1 | 1 | 100.0 |

Cohort 2024-02 **không có dòng offset 0** (user 3 không hoạt động tháng 2): nếu dùng `FIRST_VALUE` thì mẫu số sẽ lấy nhầm offset 1.

**b) Tỷ lệ mua lại trong N ngày** (`cohort/04`): lấy đơn thứ 1 và thứ 2 bằng `ROW_NUMBER`, xoay về một dòng mỗi khách, rồi đếm có điều kiện.

```sql
WITH r AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn
  FROM orders
),
f AS (
  SELECT customer_id,
         MAX(order_date) FILTER (WHERE rn = 1) AS first_date,
         MAX(order_date) FILTER (WHERE rn = 2) AS second_date   -- NULL nếu chỉ có 1 đơn
  FROM r
  WHERE rn <= 2
  GROUP BY customer_id
)
SELECT TO_CHAR(first_date, 'YYYY-MM') AS cohort_month,
       COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE second_date - first_date <= 30) AS repeaters
FROM f
GROUP BY 1
ORDER BY 1;
```

`second_date - first_date` là `NULL` với khách chỉ mua một lần, nên `FILTER` tự loại họ, nhưng họ vẫn nằm trong `COUNT(*)` (mẫu số). Thêm `order_id` vào `ORDER BY` của `ROW_NUMBER` để hai đơn cùng ngày được xếp xác định.

**c) Ma trận đầy đủ, ô trống hiện 0:** sinh mọi offset bằng `generate_series` rồi `LEFT JOIN`.

```sql
-- retention = truy vấn 3.2 viết thành CTE (cohort_month đã TO_CHAR)
cohorts AS (SELECT DISTINCT cohort_month FROM retention),
offsets AS (SELECT generate_series(0, 3) AS month_offset)
SELECT c.cohort_month, o.month_offset, COALESCE(r.retention_pct, 0) AS retention_pct
FROM cohorts c
CROSS JOIN offsets o
LEFT JOIN retention r ON r.cohort_month = c.cohort_month AND r.month_offset = o.month_offset
ORDER BY c.cohort_month, o.month_offset;
```

Với dữ liệu 3.2, cohort 2024-01 giờ có thêm dòng offset 1 và 3 với giá trị `0`.

---

## Phần 4. Funnel (phễu chuyển đổi)

### 4.1 Nhận diện nhanh

Đề nói *"phễu"*, *"tỷ lệ chuyển đổi"*, *"bao nhiêu người đi tới bước…"*, *"rơi rụng ở bước nào"*. Công thức chung:

1. **Đưa về một dòng mỗi user** (`GROUP BY user_id`) với cờ/thời điểm của từng bước. Đếm **người**, không đếm sự kiện.
2. **Đếm có điều kiện** số user đạt mỗi bước, với điều kiện **đã qua mọi bước trước**.
3. **Tỷ lệ** = bước này ÷ bước đầu (tổng chuyển đổi) hoặc ÷ bước liền trước (chuyển đổi từng bước), có `NULLIF` để tránh chia 0 (A5).

### 4.2 Phễu nghiêm ngặt, không xét thứ tự thời gian (`funnel/01`)

```sql
WITH u AS (                                       -- một dòng mỗi user, mỗi bước một cờ
  SELECT user_id,
         BOOL_OR(step = 'view')     AS did_view,
         BOOL_OR(step = 'cart')     AS did_cart,
         BOOL_OR(step = 'purchase') AS did_purchase
  FROM events
  GROUP BY user_id
)
SELECT COUNT(*) FILTER (WHERE did_view)                              AS viewed,
       COUNT(*) FILTER (WHERE did_view AND did_cart)                 AS carted,
       COUNT(*) FILTER (WHERE did_view AND did_cart AND did_purchase) AS purchased,
       ROUND(100.0 * COUNT(*) FILTER (WHERE did_view AND did_cart AND did_purchase)
             / NULLIF(COUNT(*) FILTER (WHERE did_view), 0), 1)       AS conversion_pct
FROM u;
```

`BOOL_OR(điều_kiện)` trả `true` nếu **ít nhất một** dòng của user thỏa, giống `MAX(CASE WHEN ... THEN 1 ELSE 0 END) = 1` nhưng gọn hơn.

**Input** — Table `events`

| user_id | step | event_time |
| --- | --- | --- |
| 1 | view | 2024-01-01 10:00 |
| 1 | cart | 2024-01-01 10:05 |
| 1 | purchase | 2024-01-01 10:20 |
| 2 | view | 2024-01-01 11:00 |
| 2 | view | 2024-01-01 11:02 |
| 2 | cart | 2024-01-01 11:10 |
| 3 | view | 2024-01-02 09:00 |
| 4 | cart | 2024-01-02 08:00 |
| 4 | view | 2024-01-02 08:30 |
| 5 | view | 2024-01-03 12:00 |
| 5 | purchase | 2024-01-03 12:30 |

**Output**

| viewed | carted | purchased | conversion_pct |
| --- | --- | --- | --- |
| 5 | 3 | 1 | 20.0 |

User 5 có `purchase` nhưng bỏ qua `cart` nên **không** được tính ở bước purchase. User 2 xem 2 lần vẫn chỉ là 1 người.

### 4.3 Phễu có thứ tự thời gian, xuất dạng dọc

Khi đề yêu cầu "bước sau phải xảy ra **sau** bước trước", lấy **thời điểm đầu tiên** của mỗi bước rồi so sánh. Xuất mỗi bước một dòng để tính được tỷ lệ so với bước đầu và bước trước bằng window.

```sql
WITH firsts AS (                                  -- thời điểm đầu tiên của từng bước, mỗi user một dòng
  SELECT user_id,
         MIN(event_time) FILTER (WHERE step = 'view')     AS t_view,
         MIN(event_time) FILTER (WHERE step = 'cart')     AS t_cart,
         MIN(event_time) FILTER (WHERE step = 'purchase') AS t_purchase
  FROM events
  GROUP BY user_id
),
reached AS (                                      -- bước xa nhất user đạt được đúng thứ tự
  SELECT user_id,
         CASE WHEN t_purchase >= t_cart AND t_cart >= t_view THEN 3
              WHEN t_cart >= t_view                          THEN 2
              WHEN t_view IS NOT NULL                        THEN 1
              ELSE 0 END AS stage
  FROM firsts
),
steps (step_no, step) AS (                        -- bảng tên bước, để bước 0 người vẫn hiện ra
  VALUES (1, 'view'), (2, 'cart'), (3, 'purchase')
),
counts AS (
  SELECT s.step_no, s.step, COUNT(r.user_id) AS users
  FROM steps s
  LEFT JOIN reached r ON r.stage >= s.step_no
  GROUP BY s.step_no, s.step
)
SELECT step, users,
       ROUND(100.0 * users / NULLIF(FIRST_VALUE(users) OVER (ORDER BY step_no), 0), 1) AS pct_of_first,
       ROUND(100.0 * users / NULLIF(LAG(users) OVER (ORDER BY step_no), 0), 1)         AS pct_of_prev
FROM counts
ORDER BY step_no;
```

**Output** (cùng input 4.2)

| step | users | pct_of_first | pct_of_prev |
| --- | --- | --- | --- |
| view | 5 | 100.0 | NULL |
| cart | 2 | 40.0 | 40.0 |
| purchase | 1 | 20.0 | 50.0 |

So với 4.2, `cart` giảm từ 3 xuống 2: user 4 bỏ vào giỏ (08:00) **trước** khi xem (08:30) nên không tính khi xét thứ tự.

- So sánh với `NULL` ra `NULL`, nên `CASE` tự rơi xuống nhánh dưới khi thiếu bước. Không cần viết `IS NOT NULL` cho từng bước.
- `COUNT(r.user_id)` (không phải `COUNT(*)`) để bước không ai đạt ra `0` thay vì `1` (dòng `LEFT JOIN` không khớp vẫn có một dòng).
- Cách này dùng **lần đầu** của mỗi bước. Nếu user `cart` trước `view` rồi `view` và `cart` lại, họ vẫn bị loại. Đề đòi chính xác tới mức đó thì phải tìm "lần `cart` đầu tiên **sau** `t_view`" bằng subquery tương quan hoặc `LATERAL`.

### 4.4 Đường đi phổ biến nhất (`funnel/02`)

Ghép mỗi trang với 2 trang kế tiếp bằng `LEAD(page, 1)`, `LEAD(page, 2)` trên cùng một cửa sổ đặt tên `WINDOW w AS (PARTITION BY user_id ORDER BY seq)`, rồi `GROUP BY path`. Dòng cuối mỗi user có `LEAD = NULL` → chuỗi nối với `||` thành `NULL` → lọc `WHERE path IS NOT NULL`.

### 4.5 Bẫy Funnel

1. **Đếm sự kiện thay vì người** → user bấm nhiều lần làm phễu phình ra. Luôn gom về user trước.
2. **Không ép điều kiện "đã qua bước trước"** → bước sau có thể lớn hơn bước trước, phễu không còn là phễu.
3. **Chia 0** khi không ai vào bước đầu → `NULLIF` (A5).
4. **Nhầm hai loại tỷ lệ**: so với bước đầu (`FIRST_VALUE`) khác so với bước liền trước (`LAG`). Đọc kỹ đề hỏi loại nào.

---

## Phần 5. Chỉ số so sánh

### 5.1 Tỷ lệ so với tổng (`misc/02`)

Mẫu chung: `100.0 * phần / tổng`. Tổng lấy bằng window **không có `ORDER BY`** để có cùng một giá trị trên mọi dòng.

```sql
SELECT category, product,
       SUM(amount) AS revenue,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (PARTITION BY category), 1) AS pct_of_category,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 1)                      AS pct_of_total
FROM sales
GROUP BY category, product
ORDER BY category, product;
```

**Input** `sales`: (Book, B1, 30), (Book, B2, 10), (Book, B2, 20), (Toy, T1, 140).

| category | product | revenue | pct_of_category | pct_of_total |
| --- | --- | --- | --- | --- |
| Book | B1 | 30 | 50.0 | 15.0 |
| Book | B2 | 30 | 50.0 | 15.0 |
| Toy | T1 | 140 | 100.0 | 70.0 |

- `SUM(SUM(amount)) OVER (...)`: `SUM` trong là tổng của nhóm `GROUP BY`, `SUM ... OVER` ngoài cộng các tổng nhóm đó. Window chạy **sau** `GROUP BY` (F1).
- `OVER ()` rỗng = cả bảng; `OVER (PARTITION BY category)` = trong danh mục.
- **Không** thêm `ORDER BY` vào `OVER` ở đây: có `ORDER BY` thì tổng biến thành tổng dồn (F2a).
- `100.0 *` đặt **trước** để tránh chia số nguyên (A5).

### 5.2 Biên lợi nhuận (profit margin)

`margin_pct = 100 × (doanh thu − giá vốn) ÷ doanh thu`.

```sql
SELECT product,
       SUM(qty * unit_price)                    AS revenue,
       SUM(qty * (unit_price - unit_cost))      AS gross_profit,
       ROUND(100.0 * SUM(qty * (unit_price - unit_cost))
             / NULLIF(SUM(qty * unit_price), 0), 1) AS margin_pct
FROM order_items
GROUP BY product
ORDER BY product;
```

**Input** `order_items`

| category | product | qty | unit_price | unit_cost |
| --- | --- | --- | --- | --- |
| Book | B1 | 10 | 20 | 12 |
| Book | B2 | 1 | 100 | 40 |
| Toy | T1 | 5 | 30 | 30 |
| Toy | T2 | 0 | 50 | 20 |

**Output**

| product | revenue | gross_profit | margin_pct |
| --- | --- | --- | --- |
| B1 | 200 | 80 | 40.0 |
| B2 | 100 | 60 | 60.0 |
| T1 | 150 | 0 | 0.0 |
| T2 | 0 | 0 | NULL |

T2 không bán được nên doanh thu 0 → `NULLIF` trả `NULL` thay vì lỗi chia cho 0.

**Bẫy lớn nhất: biên của nhóm ≠ trung bình các biên.** Biên của danh mục phải là `SUM(lợi nhuận) / SUM(doanh thu)` (bình quân có trọng số theo doanh thu), không phải `AVG(margin_pct)`:

```sql
WITH by_product AS (
  SELECT category, product,
         SUM(qty * unit_price)               AS revenue,
         SUM(qty * (unit_price - unit_cost)) AS gross_profit
  FROM order_items
  GROUP BY category, product
)
SELECT category,
       ROUND(100.0 * SUM(gross_profit) / NULLIF(SUM(revenue), 0), 1)  AS margin_pct,       -- đúng
       ROUND(AVG(100.0 * gross_profit / NULLIF(revenue, 0)), 1)       AS avg_of_margins    -- sai
FROM by_product
GROUP BY category
ORDER BY category;
```

| category | margin_pct | avg_of_margins |
| --- | --- | --- |
| Book | 46.7 | 50.0 |
| Toy | 0.0 | 0.0 |

Book: (80 + 60) / (200 + 100) = 46.7%, còn trung bình hai biên (40 + 60) / 2 = 50% là sai vì B2 bán ít hơn mà được tính ngang B1. Ở Toy, `AVG` bỏ qua `NULL` của T2 (A3) nên tình cờ ra đúng.

### 5.3 Gap Analysis (mục tiêu so với thực tế)

**Dùng để làm gì:** đánh giá **hiệu quả kinh doanh** bằng cách đặt thực tế cạnh kế hoạch: kỳ nào, đơn vị nào hụt chỉ tiêu, hụt bao nhiêu.

**Đề:** so sánh doanh thu thực tế mỗi tháng với mục tiêu: chênh lệch, % đạt, đạt hay chưa.

```sql
WITH actual AS (                                    -- gộp về đúng grain tháng TRƯỚC khi JOIN
  SELECT DATE_TRUNC('month', order_date)::date AS month, SUM(amount) AS actual_amount
  FROM orders
  WHERE status = 'Completed'
  GROUP BY 1
)
SELECT t.month, t.target_amount,
       COALESCE(a.actual_amount, 0)                   AS actual_amount,
       COALESCE(a.actual_amount, 0) - t.target_amount AS gap,
       ROUND(100.0 * COALESCE(a.actual_amount, 0) / NULLIF(t.target_amount, 0), 1) AS attainment_pct,
       CASE WHEN COALESCE(a.actual_amount, 0) >= t.target_amount THEN 'Đạt'
            ELSE 'Chưa đạt' END                       AS status
FROM sales_targets t
LEFT JOIN actual a ON a.month = t.month
ORDER BY t.month;
```

**Input** `sales_targets`: 2024-01 → 300, 2024-02 → 200, 2024-03 → 100. `orders`: 01-05 200, 01-20 150, 02-03 120 (đều Completed), 02-14 90 (Cancelled); tháng 3 không có đơn.

| month | target_amount | actual_amount | gap | attainment_pct | status |
| --- | --- | --- | --- | --- | --- |
| 2024-01-01 | 300 | 350 | 50 | 116.7 | Đạt |
| 2024-02-01 | 200 | 120 | -80 | 60.0 | Chưa đạt |
| 2024-03-01 | 100 | 0 | -100 | 0.0 | Chưa đạt |

- **Gộp thực tế theo tháng trước, rồi mới `JOIN`**. Nếu `JOIN` thẳng `sales_targets` với `orders` rồi `SUM(target_amount)`, mục tiêu bị nhân lên theo số đơn (fan-out, C3).
- **`LEFT JOIN` từ bảng mục tiêu** để tháng không có đơn (tháng 3) vẫn hiện với thực tế 0. `INNER JOIN` sẽ làm mất tháng tệ nhất.
- `COALESCE(..., 0)` trước khi trừ: `NULL - 100` ra `NULL`, không ra `-100`.
- Biến thể: mục tiêu theo **nhân viên/khu vực** thì gộp thực tế theo đúng khóa đó; "lũy kế đạt bao nhiêu % mục tiêu năm" thì kết hợp với 5.4.

### 5.4 Running total có điều kiện

Running total thường là `SUM(x) OVER (ORDER BY ...)` (`misc/01`, xem F2b về `ROWS` khi có giá trị trùng). Bốn biến thể có điều kiện:

| Đề nói | Kỹ thuật |
| --- | --- |
| Chỉ cộng dòng thỏa điều kiện, **vẫn giữ mọi dòng** | `SUM(x) FILTER (WHERE ...) OVER (...)` hoặc `SUM(CASE WHEN ... THEN x ELSE 0 END) OVER (...)` |
| Reset theo kỳ (đầu tháng, đầu năm) | `PARTITION BY DATE_TRUNC('month', d)` |
| Reset khi gặp một sự kiện | Đánh số nhóm bằng đếm dồn sự kiện, rồi `PARTITION BY` nhóm đó (giống Gaps & Islands cách 2) |
| Dòng đầu tiên đạt ngưỡng | Tính running total trong CTE, rồi `WHERE running >= ngưỡng ORDER BY ... LIMIT 1` |

**a) + b) Chỉ cộng đơn Completed, và reset mỗi tháng:**

```sql
SELECT sale_id, sale_date, status, amount,
       SUM(amount) FILTER (WHERE status = 'Completed')
         OVER (ORDER BY sale_id)                                   AS running_completed,
       SUM(CASE WHEN status = 'Completed' THEN amount ELSE 0 END)
         OVER (PARTITION BY DATE_TRUNC('month', sale_date) ORDER BY sale_id) AS mtd_completed
FROM sales
ORDER BY sale_id;
```

| sale_id | sale_date | status | amount | running_completed | mtd_completed |
| --- | --- | --- | --- | --- | --- |
| 1 | 2024-01-03 | Completed | 100 | 100 | 100 |
| 2 | 2024-01-15 | Cancelled | 40 | 100 | 100 |
| 3 | 2024-01-28 | Completed | 60 | 160 | 160 |
| 4 | 2024-02-02 | Completed | 80 | 240 | 80 |
| 5 | 2024-02-10 | Cancelled | 20 | 240 | 80 |
| 6 | 2024-02-20 | Completed | 50 | 290 | 130 |

- Đặt điều kiện ở `WHERE status = 'Completed'` sẽ **mất** dòng 2 và 5. Đề yêu cầu "liệt kê mọi giao dịch" thì phải đưa điều kiện vào trong hàm (`FILTER` hoặc `CASE`).
- Dòng 4 là đầu tháng 2 nên `mtd_completed` bắt đầu lại từ 80.

**c) Reset khi gặp sự kiện:** điểm thưởng cộng dồn, mỗi lần `redeem` thì về 0.

```sql
WITH g AS (
  SELECT id, log_date, kind, pts,
         COUNT(*) FILTER (WHERE kind = 'redeem') OVER (ORDER BY id) AS reset_grp
  FROM points_log
)
SELECT id, log_date, kind, pts, reset_grp,
       SUM(pts) OVER (PARTITION BY reset_grp ORDER BY id) AS balance
FROM g
ORDER BY id;
```

| id | log_date | kind | pts | reset_grp | balance |
| --- | --- | --- | --- | --- | --- |
| 1 | 2024-01-05 | earn | 100 | 0 | 100 |
| 2 | 2024-01-20 | earn | 50 | 0 | 150 |
| 3 | 2024-02-03 | redeem | 0 | 1 | 0 |
| 4 | 2024-02-10 | earn | 30 | 1 | 30 |
| 5 | 2024-02-25 | earn | 70 | 1 | 100 |
| 6 | 2024-03-01 | redeem | 0 | 2 | 0 |
| 7 | 2024-03-09 | earn | 40 | 2 | 40 |

Mỗi lần gặp `redeem`, đếm dồn tăng 1 → mở nhóm mới → tổng dồn chạy lại từ đầu. Đây chính là mẹo "cộng dồn cờ" của 1.5.

**d) Dòng đầu tiên đạt ngưỡng:** đơn nào làm tổng Completed vượt 200?

```sql
WITH r AS (
  SELECT sale_id, sale_date,
         SUM(amount) FILTER (WHERE status = 'Completed') OVER (ORDER BY sale_id) AS running_completed
  FROM sales
)
SELECT sale_id, sale_date, running_completed
FROM r
WHERE running_completed >= 200
ORDER BY sale_id
LIMIT 1;
```

Kết quả: `sale_id = 4`, `running_completed = 240`. Không viết được `WHERE SUM(...) OVER (...) >= 200` trực tiếp vì window chạy sau `WHERE` (E7), nên phải bọc CTE. Biến thể "các sản phẩm tạo nên 80% doanh thu" (Pareto, `window/11`) dùng đúng mẫu này với `running / total`.

### 5.5 Top N per Group (`topn/*`)

```sql
SELECT department, name, salary, rnk
FROM (
  SELECT department, name, salary,
         DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC NULLS LAST) AS rnk
  FROM employees
) t
WHERE rnk <= 2
ORDER BY department, rnk, name;
```

**Chọn hàm xếp hạng theo cách đề xử lý đồng hạng** (chi tiết ở E6):

| Đề nói | Hàm | IT: 900, 900, 700, 600 |
| --- | --- | --- |
| "đúng N dòng", "bản ghi mới nhất" | `ROW_NUMBER` + tiebreaker | 1, 2, 3, 4 |
| "top N, đồng hạng thì lấy hết, bỏ hạng kế" | `RANK` | 1, 1, 3, 4 |
| "N mức lương cao nhất", "lương cao thứ N" | `DENSE_RANK` | 1, 1, 2, 3 |

**Bẫy riêng của PostgreSQL:** `ORDER BY salary DESC` xếp `NULL` **lên đầu** (PostgreSQL coi `NULL` lớn hơn mọi giá trị). Không có `NULLS LAST` thì nhân viên chưa có lương nhận hạng 1. Cách khác: lọc `WHERE salary IS NOT NULL` trước.

- `WHERE rnk <= 2` phải nằm ở query **ngoài** (E7).
- Chỉ cần **top 1 mỗi nhóm** thì PostgreSQL có lối tắt `DISTINCT ON`:

```sql
SELECT DISTINCT ON (department) department, name, salary
FROM employees
WHERE salary IS NOT NULL
ORDER BY department, salary DESC, name;    -- cột đầu ORDER BY phải trùng DISTINCT ON
```

`DISTINCT ON` lấy đúng 1 dòng (giống `ROW_NUMBER = 1`), nên khi đồng hạng mà đề muốn lấy hết thì vẫn phải dùng `RANK`.

- **Không được dùng window** (`topn/04`): so với giá trị lớn nhất của chính nhóm đó bằng subquery tương quan. Đồng hạng tự được giữ hết:

```sql
SELECT e.department, e.name, e.salary
FROM employees e
WHERE e.salary = (SELECT MAX(x.salary) FROM employees x WHERE x.department = e.department)
ORDER BY e.department, e.name;
```

`MAX` bỏ qua `NULL` và `NULL = ...` không bao giờ đúng, nên nhân viên chưa có lương tự bị loại. Viết bằng `NOT EXISTS (SELECT 1 FROM employees x WHERE x.department = e.department AND x.salary > e.salary)` thì phải thêm `e.salary IS NOT NULL` (E1, E3).

---

## Phần 6. Dashboard tổng hợp (ghép mọi thứ bằng CTE)

**Đề:** báo cáo theo tháng gồm doanh thu, số đơn, số khách, khách mới, khách quay lại, giá trị đơn trung bình (AOV), tăng trưởng so với tháng trước (MoM), doanh thu lũy kế, tỷ trọng doanh thu.

Cách làm: **mỗi CTE một việc**, tất cả gộp về **một grain** (tháng) trước khi dùng window.

```sql
WITH clean AS (                                        -- 1. lọc đơn hợp lệ, gắn tháng
  SELECT order_id, customer_id, amount,
         DATE_TRUNC('month', order_date)::date AS month
  FROM orders
  WHERE status = 'Completed'
),
first_month AS (                                       -- 2. tháng mua đầu tiên của mỗi khách
  SELECT customer_id, MIN(month) AS first_month
  FROM clean
  GROUP BY customer_id
),
monthly AS (                                           -- 3. KPI theo tháng (grain = tháng)
  SELECT c.month,
         SUM(c.amount)                 AS revenue,
         COUNT(*)                      AS orders,
         COUNT(DISTINCT c.customer_id) AS customers,
         COUNT(DISTINCT c.customer_id) FILTER (WHERE c.month = f.first_month) AS new_customers
  FROM clean c
  JOIN first_month f ON f.customer_id = c.customer_id   -- 1 dòng/khách nên không fan-out
  GROUP BY c.month
)
SELECT TO_CHAR(month, 'YYYY-MM')                              AS month,   -- 4. chỉ số so sánh bằng window
       revenue, orders, customers, new_customers,
       customers - new_customers                              AS returning_customers,
       ROUND(1.0 * revenue / orders, 2)                       AS aov,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS mom_pct,
       SUM(revenue) OVER (ORDER BY month)                     AS running_revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)       AS pct_of_total
FROM monthly
ORDER BY month;
```

**Input** — Table `orders`

| order_id | customer_id | order_date | amount | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-05 | 100 | Completed |
| 2 | 2 | 2024-01-12 | 50 | Completed |
| 3 | 1 | 2024-01-25 | 30 | Completed |
| 4 | 3 | 2024-01-28 | 70 | Cancelled |
| 5 | 1 | 2024-02-10 | 60 | Completed |
| 6 | 3 | 2024-02-14 | 40 | Completed |
| 7 | 2 | 2024-03-03 | 90 | Completed |
| 8 | 4 | 2024-03-15 | 110 | Completed |
| 9 | 4 | 2024-03-20 | 50 | Completed |

**Output**

| month | revenue | orders | customers | new_customers | returning_customers | aov | mom_pct | running_revenue | pct_of_total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 180 | 3 | 2 | 2 | 0 | 60.00 | NULL | 180 | 34.0 |
| 2024-02 | 100 | 2 | 2 | 1 | 1 | 50.00 | -44.4 | 280 | 18.9 |
| 2024-03 | 250 | 3 | 2 | 1 | 1 | 83.33 | 150.0 | 530 | 47.2 |

- Khách 3 có đơn tháng 1 nhưng bị `Cancelled`, nên là **khách mới của tháng 2**. Đây là lý do `first_month` phải tính từ `clean`, không từ `orders` gốc (bẫy số 2 ở 3.4).
- `mom_pct` (`misc/03`): `LAG` lấy tháng liền trước. Tháng đầu `NULL`; tháng trước bằng 0 thì `NULLIF` trả `NULL`.
- **Tháng không có đơn sẽ biến mất**, và khi đó `LAG` so với tháng cách xa hơn. Đề đòi đủ tháng thì sinh lịch bằng `generate_series(min_month, max_month, INTERVAL '1 month')` rồi `LEFT JOIN monthly` (cùng ý với 3.5c, `misc/05`).
- Muốn thêm "top sản phẩm mỗi tháng" thì viết **một CTE riêng** ở grain (tháng, sản phẩm) dùng 5.5, rồi `JOIN` vào theo `month` sau khi đã lọc còn 1 dòng/tháng. Không `JOIN` bảng chi tiết vào `monthly` trước khi gộp (C3).

---

## Phần 7. Chiến lược làm bài nhanh

**Quy trình 5 bước cho mọi đề SQL phân tích** (khoảng 10–15 phút mỗi bài):

1. **Xác định grain (đơn vị phân tích):** kết quả cuối mỗi dòng là gì (một khách? một cặp cohort-offset? một tháng?). Viết ra trước khi gõ query.
2. **Nhận dạng pattern:** dùng bảng dưới.
3. **Viết từng CTE, mỗi CTE một việc**, và chạy thử sau mỗi CTE trên dữ liệu mẫu (thường chỉ 4–6 dòng, nhẩm được).
4. **Đối chiếu với Expected result**, chú ý dữ liệu bẫy (trùng ngày, trùng tháng, đơn hủy, tháng trống).
5. **Rà checklist bẫy** của dạng đó, rồi kiểm tra `ORDER BY` cuối đúng yêu cầu đề.

**Bảng thuộc lòng**

| Đề nói | Công thức | Mục |
| --- | --- | --- |
| Chuỗi liên tiếp dài nhất | `DISTINCT` → số nguyên liên tục → `x − ROW_NUMBER()` → `GROUP BY` → `MAX(COUNT)` | 1.4 |
| Tháng liên tiếp qua năm | `năm*12 + tháng` | 1.3 |
| Ngày liên tiếp | `d - ROW_NUMBER() OVER (...)::int` | 1.6d |
| Khoảng trống giữa các giá trị | `LEAD(x) − x > 1` | 1.6a |
| Chia phiên theo khoảng nghỉ | `LAG` + cờ `> ngưỡng` + `SUM` cờ | 1.6e |
| Giảm/tăng liên tiếp N kỳ | `LAG` gắn cờ → `SUM(CASE NOT cờ)` làm run → `HAVING COUNT >= N` | 1.7 |
| Số ngày kể từ lần mua cuối | `ngày_chốt − MAX(order_date)`, ngày chốt cố định | 2.3 |
| Chấm điểm 1–5 | `NTILE(5) OVER (ORDER BY ... , id)`, R thì `DESC` | 2.3 |
| Cohort | `MIN(tháng) OVER (PARTITION BY khách)` + offset `năm*12+tháng` | 3.2 |
| Retention % | `active ÷ FIRST_VALUE(active)` theo cohort (hoặc ÷ quy mô từ bảng users) | 3.2, 3.5a |
| Ma trận | `MAX(x) FILTER (WHERE offset = k)` | 3.3 |
| Phễu | `BOOL_OR` mỗi bước theo user → `COUNT(*) FILTER (WHERE a AND b ...)` | 4.2 |
| Phễu theo thứ tự | `MIN(t) FILTER` mỗi bước → so sánh thời điểm → `FIRST_VALUE` / `LAG` | 4.3 |
| % so với tổng | `100.0 * SUM(x) / SUM(SUM(x)) OVER (PARTITION BY ...)` | 5.1 |
| Biên lợi nhuận nhóm | `SUM(lợi nhuận) / NULLIF(SUM(doanh thu), 0)`, không `AVG(margin)` | 5.2 |
| Mục tiêu vs thực tế | Gộp thực tế theo grain → `LEFT JOIN` từ bảng mục tiêu → `COALESCE` | 5.3 |
| Tổng dồn có điều kiện | `SUM(x) FILTER (WHERE ...) OVER (...)` | 5.4 |
| Tổng dồn reset theo sự kiện | `COUNT(*) FILTER (WHERE sự_kiện) OVER` làm nhóm → `PARTITION BY` nhóm | 5.4c |
| Top N mỗi nhóm | `ROW_NUMBER` / `RANK` / `DENSE_RANK` trong subquery, `NULLS LAST` | 5.5 |
| Dashboard | CTE lọc → CTE grain tháng → window `LAG`, `SUM OVER` | 6 |

**Liên hệ tài liệu chính** ([sql-common-pitfalls.md](sql-common-pitfalls.md)): hàm tổng hợp bỏ qua NULL (A3), chia cho 0 (A5), fan-out (C3), `DISTINCT` che lỗi (C5), ties trong xếp hạng (E6), alias/window trong `WHERE` (E7), window trên `GROUP BY` (F1), frame của window (F2, F3).
