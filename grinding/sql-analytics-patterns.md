# SQL phân tích thực chiến: Gaps & Islands, RFM, Cohort, Funnel, chỉ số và Dashboard

> Phương ngữ: **PostgreSQL** (đúng engine của `check.py`). Mọi query và output dưới đây đã **chạy thật bằng `check.py`** với dữ liệu mẫu đi kèm.
> Cách học: nhận ra dạng bài → áp công thức → kiểm tra bẫy. Mỗi dạng chỉ có **một công thức**, thuộc nó là đủ.
> Bẫy chung (NULL, chia số nguyên, fan-out, frame của window) nằm ở [sql-common-pitfalls.md](sql-common-pitfalls.md); tài liệu này trỏ tới bằng mã mục (A5, C3, E6, F2…).

**Mục lục**

| Phần | Dạng bài | Bài tập |
| --- | --- | --- |
| 0 | Bản đồ: dạng bài nào trả lời câu hỏi gì, CTE + Window, bẫy thiếu dòng | |
| 1 | Gaps & Islands, chuỗi giảm liên tiếp | `islands/*`, `sessions/01` |
| 2 | RFM, hạng thành viên, Pareto khách hàng | `cohort/02`, `05`–`08`, `rfm/*` |
| 3 | Cohort / Retention | `cohort/01`, `03`, `04` |
| 4 | Funnel (phễu) | `funnel/01`, `02` |
| 5 | Chỉ số: tỷ lệ so với tổng, biên lợi nhuận, Gap Analysis, running total có điều kiện, Top N | `misc/01`, `02`, `topn/*` |
| 6 | Dashboard tổng hợp | `misc/03` |
| 7 | Chiến lược làm bài và bảng thuộc lòng | |
| 8 | Churn, growth accounting, NRR | `churn/*` |
| 9 | Khoảng cách giữa các lần mua | `gaps/*` |
| 10 | Trung vị và phân vị | `median/*`, `misc/04` |
| 11 | LTV (giá trị vòng đời khách hàng) | `ltv/*` |
| 12 | Khoảng thời gian và as-of | `intervals/*`, `misc/07` |
| 13 | FIFO (nhập trước, xuất trước) | `fifo/*` |
| 14 | Chuỗi trạng thái (state machine) | `misc/08` |

---

## Phần 0. Bản đồ: dạng bài nào trả lời câu hỏi gì

Đọc phần này trước. Mỗi dạng bài là **một câu hỏi nghiệp vụ** đi kèm **một kỹ thuật**. Nhận ra câu hỏi thì biết ngay kỹ thuật.

### 0.1 Bảng tổng quan

| Dạng bài | Câu hỏi nghiệp vụ | Kỹ thuật cốt lõi | Cách làm (tóm tắt) | Mục |
| --- | --- | --- | --- | --- |
| Gaps & Islands | Khách duy trì hoạt động **liên tục** bao lâu? Bỏ lỡ những kỳ nào? | `ROW_NUMBER`, `LAG`/`LEAD` | Khử trùng → đổi ra số liên tục → `x − ROW_NUMBER` làm nhãn đảo → `GROUP BY` nhãn | 1.2–1.6 |
| Sessionization | Một lượt truy cập gồm những sự kiện nào? | `LAG` + `SUM` cờ | Cờ "nghỉ quá ngưỡng" → cộng dồn cờ thành số phiên | 1.6e |
| Consecutive Decline | Sản phẩm/chỉ số nào **đang đi xuống** nhiều kỳ liền (cảnh báo sớm)? | `LAG` + `SUM` cờ | Cờ "thấp hơn kỳ trước" → gom run → `HAVING COUNT >= N` | 1.7 |
| RFM | Khách **hiện tại** đang ở nhóm nào: VIP, trung thành, sắp rời bỏ? | `GROUP BY`, `NTILE`, `CASE` | R/F/M theo khách với ngày chốt cố định → chấm điểm `NTILE` → gắn nhãn `CASE` | 2.1–2.8 |
| Hạng thành viên / ngưỡng trong bảng | Khách được hạng gì? Điểm lấy theo bảng ngưỡng nào? | `CASE` nhiều điều kiện, non-equi join | Lọc cửa sổ thời gian → gộp bảng con trước khi nối → `CASE` / `JOIN ... ON v >= min AND v <= max` | 2.9–2.10 |
| Pareto khách hàng | Bao nhiêu % khách tạo 80% doanh thu? | `SUM() OVER (... EXCLUDE GROUP)` | Doanh thu khách giàu hơn hẳn < 80% tổng → đếm có điều kiện | 2.11 |
| Điểm theo phân vị / bảng luật | Khách bằng nhau có cùng điểm không? Khách khớp luật nào trước? | `CUME_DIST`, `LATERAL ... LIMIT 1` | `CEIL(5 × CUME_DIST)`; regex `~` + luật có priority nhỏ nhất | 2.12–2.13 |
| Churn / trạng thái khách | Khách nào đang rời bỏ? Tháng này mất bao nhiêu % khách đầu kỳ? | `MAX(date)` + `CASE`, kiểm tra khoảng `start <= d < end` | Ngày chốt → nhãn theo số ngày; thuê bao: đang chạy ngày 1 tháng này mà không chạy ngày 1 tháng sau | 8.2–8.3 |
| Growth accounting | MAU tăng/giảm vì khách mới, khách quay lại hay khách rời? | Calendar spine + `LAG(cờ)` | User × mọi tháng → cờ hoạt động → new / retained / resurrected / churned → đếm | 8.4–8.6 |
| NRR / GRR | Khách cũ trả nhiều hơn hay ít hơn trước? | `LEFT JOIN` kỳ gốc → kỳ đích, `SUM FILTER` | Gộp MRR mỗi khách-tháng → tách expansion / contraction / churned | 8.7 |
| Khoảng cách giữa các lần mua | Bao lâu khách mua lại một lần? Ai đang vắng lâu bất thường? | `DISTINCT` ngày + `LAG`/`LEAD`, `PERCENTILE_CONT` | Khử trùng ngày → khoảng cách tới lần trước → tổng hợp theo khách / nhóm / kênh | 9 |
| Trung vị / phân vị | Giá trị điển hình là bao nhiêu? Dữ liệu có bị vài giá trị lớn kéo lệch không? | `PERCENTILE_CONT` / `DISC`, `ROW_NUMBER` + `COUNT` | Trung vị theo nhóm; tự viết khi bị cấm hàm; từ bảng tần suất dùng tổng lũy kế; trượt thì dùng `LATERAL` | 10 |
| LTV | Một khách mang về bao nhiêu tiền trong suốt thời gian gắn bó? | Tỷ số của tổng, cửa sổ N ngày, spine + `SUM() OVER` | Công thức AOV × tần suất × vòng đời; giá trị N ngày đầu của khách đủ tuổi; đường lũy kế theo `month_offset` | 11 |
| Khoảng thời gian / as-of | Có trùng lịch không? Gộp thành mấy đợt? Lúc đông nhất bao nhiêu? Giá tại ngày X? | Công thức chồng nhau, `MAX(end) OVER`, sự kiện ±1, `LATERAL ... LIMIT 1` | Self-join chồng nhau; gộp đợt bằng cờ; tổng lũy kế sự kiện; dòng hiệu lực gần nhất | 12 |
| FIFO | Còn bao nhiêu hàng và trị giá bao nhiêu? Lần bán này có giá vốn bao nhiêu? Hóa đơn nào đã được trả? | Tổng lũy kế thành khoảng `(lo, hi]` | `GREATEST(0, LEAST(qty, cum − used))`; join hai dãy khoảng | 13 |
| State machine | Đơn có đi đúng quy trình không? | `LAG(status)` + `NOT EXISTS` + `IS NOT DISTINCT FROM` | Cặp (từ, đến) → so với bảng bước hợp lệ | 14 |
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

`CASE` dừng ở nhánh đúng **đầu tiên**, nên xếp nhánh **cụ thể trước, chung sau**. Bài luyện với thang 1–3: `cohort/05`. Ngưỡng ở trên dành cho thang 1–5. Với dữ liệu 2.3 (thang 1–3), khách 1 ra `At Risk`, khách 2 ra `Others`, khách 3 ra `Lost`.

### 2.5 Bẫy RFM

1. `GROUP BY full_name` thay vì `customer_id` → gộp nhầm khách trùng tên.
2. Quên lọc `status` → tính cả đơn hủy.
3. Dùng ngày hiện tại thay vì ngày chốt cố định.
4. Nhầm chiều điểm R (đã nói ở 2.3).
5. `JOIN` đơn hàng với một bảng có nhiều dòng cho mỗi khách làm `SUM` bị nhân lên (xem C3, C5). Với bảng hoàn tiền thì phải gộp về một dòng mỗi đơn trước khi nối (2.9).
6. Ngưỡng trong bảng có `max_value` NULL: `BETWEEN` với NULL ra NULL nên khách hạng cao nhất bị mất điểm (2.10).
7. `NTILE` chia hai khách bằng nhau sang hai điểm khác nhau. Nếu đề yêu cầu "bằng nhau thì cùng điểm" thì dùng `CUME_DIST` (2.12).
8. Pareto mà tách hòa theo id thì một trong hai khách bằng doanh thu bị loại khỏi nhóm top (2.11).

### 2.6 Chấm điểm theo ngưỡng cố định, giữ cả khách chưa mua (`cohort/06`)

`NTILE` chia **theo thứ hạng tương đối**: khách mua 1 đơn vẫn có thể được f_score = 2 nếu mọi người đều ít đơn. Khi doanh nghiệp đã có **ngưỡng cụ thể** (mua trong 30 ngày, từ 3 đơn, từ 1000…), chấm điểm bằng `CASE`.

```sql
WITH rfm AS (
  SELECT c.customer_id,
         DATE '2024-07-01' - MAX(o.order_date) AS recency_days,   -- NULL nếu chưa có đơn
         COUNT(o.order_id)                     AS frequency,      -- không dùng COUNT(*): khách không đơn sẽ ra 1
         COALESCE(SUM(o.total_amount), 0)      AS monetary
  FROM customers c
  LEFT JOIN orders o
         ON o.customer_id = c.customer_id
        AND o.status = 'Completed'                 -- điều kiện lọc bảng bên phải để trong ON
        AND o.order_date < DATE '2024-07-01'       -- đơn sau ngày chốt không được tính
  GROUP BY c.customer_id
)
SELECT *,
       CASE WHEN recency_days <= 30 THEN 3 WHEN recency_days <= 90 THEN 2 ELSE 1 END AS r_score
       -- f_score, m_score tương tự; rfm_code = CONCAT(r_score, f_score, m_score)
FROM rfm;
```

- **Điều kiện lọc `orders` phải nằm trong `ON`**. Để ở `WHERE` sẽ loại mất dòng NULL, `LEFT JOIN` thành `INNER JOIN` và khách chưa mua biến mất (bẫy thiếu dòng, xem Phần 0).
- `recency_days` là NULL thì `NULL <= 30` ra NULL, không vào nhánh nào nên rơi xuống `ELSE 1`. Đó đúng là điểm R thấp nhất mình muốn.
- Ngưỡng `<=` hay `<` phải theo đúng đề. Hidden test thường kiểm tra đúng ngày biên (30/31, 90/91).

### 2.7 Tổng hợp theo phân khúc, đủ mọi phân khúc (`cohort/07`)

Sếp thường hỏi mỗi phân khúc có bao nhiêu khách và đóng góp bao nhiêu phần trăm doanh thu. Có hai điểm cần làm đúng: phân khúc **không có khách vẫn phải hiện** (với số 0), và **thứ tự sắp xếp theo nghiệp vụ**, không theo bảng chữ cái.

```sql
WITH segments(segment, sort_key) AS (
  VALUES ('Champions', 1), ('Loyal', 2), ('New', 3), ('At Risk', 4), ('Lost', 5)
)
SELECT s.segment,
       COUNT(l.segment)             AS customers,          -- đếm cột bên phải, không COUNT(*)
       COALESCE(SUM(l.monetary), 0) AS revenue,
       ROUND(100.0 * COALESCE(SUM(l.monetary), 0)
             / NULLIF(SUM(SUM(l.monetary)) OVER (), 0), 1) AS revenue_pct
FROM segments s
LEFT JOIN labeled l ON l.segment = s.segment            -- labeled = khách đã gắn nhãn (2.4)
GROUP BY s.segment, s.sort_key
ORDER BY s.sort_key;
```

Bảng `VALUES` cho cả danh sách phân khúc lẫn thứ tự. `SUM(SUM()) OVER ()` lấy tổng toàn bộ, giống 5.1. `NULLIF` để không chia cho 0 khi không có doanh thu.

### 2.8 Khách chuyển phân khúc giữa hai kỳ (`cohort/08`)

Câu hỏi đặt ra là ai đã rơi từ Champion xuống At Risk, ai từ chưa mua thành Active. Cách làm là tính RFM tại **nhiều ngày chốt** cùng lúc rồi xoay ngang ra để so sánh:

1. `customers CROSS JOIN snapshots(snap, snap_date)`: mỗi khách có một dòng cho mỗi ngày chốt.
2. `LEFT JOIN orders ... AND o.order_date < s.snap_date`: điều kiện ngày đặt trong `ON`, nên mỗi ngày chốt chỉ thấy đơn trước nó.
3. `GROUP BY customer_id, snap` → tính R/F → `CASE` gắn nhãn. Nhánh `frequency = 0` đặt **trước tiên** (`'Not Started'`).
4. Xoay ngang: `MAX(segment) FILTER (WHERE snap = 'q1')`, tương tự cho `q2`.
5. Lọc `segment_q1 <> segment_q2`. Vì bước 3 không để nhãn nào là NULL nên dùng `<>` được. Nếu có thể NULL thì dùng `IS DISTINCT FROM`.

Bỏ `WHERE` ở bước 5 và `GROUP BY segment_q1, segment_q2` thì ra **ma trận chuyển dịch** (số khách đi từ phân khúc nào sang phân khúc nào).

> Bài khởi động cho cả Phần 2: `rfm/01` (chỉ tính R, F, M thô với ngày chốt cho sẵn, đúng khung ở 2.3 nhưng chưa chấm điểm).

### 2.9 Hạng thành viên: cửa sổ thời gian, hoàn tiền và điều kiện `AND` (`rfm/02`)

Chương trình khách hàng thân thiết (Diamond / Gold / Standard) là RFM dạng **ngưỡng cố định** (2.6), có thêm ba chi tiết hay bị làm sai:

1. **Cửa sổ thời gian** viết thành khoảng nửa mở `order_date >= '2024-01-01' AND order_date < '2025-01-01'`. Cách này đúng cả khi cột là `timestamp`, còn `BETWEEN ... AND '2024-12-31'` sẽ bỏ sót các đơn trong ngày 31/12 khi cột có giờ.
2. **Hoàn tiền nằm ở bảng con** (một đơn có thể có nhiều dòng hoàn). Phải gộp `refunds` về **một dòng mỗi đơn trước** rồi mới `JOIN`. Nếu `JOIN` thẳng thì đơn có 2 lần hoàn bị nhân đôi tiền và nhân đôi số đơn (bẫy fan-out, xem C3, C5).
3. **Hạng cao cần đủ cả hai điều kiện** (`net_spend >= 10tr AND orders >= 5`). Khách mua 2 đơn hết 12tr chỉ được Gold. Nhánh khó nhất đặt đầu tiên trong `CASE`.

```sql
WITH counted AS (                                   -- đơn được tính: đã giao, đặt trong 2024
  SELECT order_id, customer_id, amount_vnd
  FROM orders
  WHERE status = 'delivered'
    AND order_date >= DATE '2024-01-01' AND order_date < DATE '2025-01-01'
),
refund_per_order AS (                               -- gộp về một dòng mỗi đơn TRƯỚC khi join
  SELECT order_id, SUM(refund_vnd) AS refunded
  FROM refunds
  GROUP BY order_id
),
per_customer AS (
  SELECT c.customer_id,
         COUNT(*)                                    AS orders_2024,
         SUM(c.amount_vnd - COALESCE(r.refunded, 0)) AS net_spend
  FROM counted c
  LEFT JOIN refund_per_order r ON r.order_id = c.order_id
  GROUP BY c.customer_id
)
SELECT m.customer_id, m.full_name,
       COALESCE(p.orders_2024, 0) AS orders_2024,
       COALESCE(p.net_spend, 0)   AS net_spend,
       CASE
         WHEN p.net_spend >= 10000000 AND p.orders_2024 >= 5 THEN 'Diamond'
         WHEN p.net_spend >= 3000000                         THEN 'Gold'
         ELSE 'Standard'                                      -- NULL (chưa mua) rơi xuống đây
       END AS tier
FROM customers m
LEFT JOIN per_customer p ON p.customer_id = m.customer_id
ORDER BY net_spend DESC, m.customer_id;
```

Vì sao lọc đơn trước rồi mới nối hoàn tiền: khoản hoàn của một đơn năm 2023 hay của đơn đã hủy **không được trừ**. Nối hoàn tiền vào `counted` (chứ không vào toàn bộ `orders`) thì các khoản đó tự động bị loại.

Output với dữ liệu của đề (khách 1 có đơn bị hoàn 2 lần 400k + 200k, khách 3 có 12tr nhưng chỉ 2 đơn):

| customer_id | full_name | orders_2024 | net_spend | tier |
| --- | --- | --- | --- | --- |
| 2 | Bella Turner | 6 | 12000000 | Diamond |
| 3 | Chris Lewis | 2 | 12000000 | Gold |
| 1 | Andrew Walker | 5 | 9900000 | Gold |
| 4 | Daniel Price | 0 | 0 | Standard |
| 5 | Hannah Vaughn | 0 | 0 | Standard |

### 2.10 Ngưỡng nằm trong bảng: non-equi join (`rfm/03`)

Khi phòng marketing muốn tự sửa ngưỡng mà không phải sửa SQL, các ngưỡng được lưu trong một bảng `rfm_thresholds(metric, score, min_value, max_value)`. Phép nối lúc này **không dùng dấu `=`** mà dùng **khoảng** (non-equi join):

```sql
SELECT c.customer_id,
       COALESCE(r.score, 0) AS r_score,
       COALESCE(f.score, 0) AS f_score,
       COALESCE(m.score, 0) AS m_score
FROM customer_metrics c
LEFT JOIN rfm_thresholds r                         -- mỗi chỉ số một lần join, một alias riêng
       ON r.metric = 'R'
      AND c.recency_days >= r.min_value
      AND (r.max_value IS NULL OR c.recency_days <= r.max_value)   -- NULL = không có cận trên
LEFT JOIN rfm_thresholds f ON f.metric = 'F' AND c.frequency    >= f.min_value AND (f.max_value IS NULL OR c.frequency    <= f.max_value)
LEFT JOIN rfm_thresholds m ON m.metric = 'M' AND c.monetary_vnd >= m.min_value AND (m.max_value IS NULL OR c.monetary_vnd <= m.max_value);
```

- **`LEFT JOIN` + `COALESCE(score, 0)`**: giá trị không rơi vào khoảng nào (ví dụ frequency = 0 trong khi bảng bắt đầu từ 1, hoặc recency NULL) vẫn giữ được dòng khách, điểm ra 0.
- **`c.recency_days BETWEEN r.min_value AND r.max_value` sai khi `max_value` là NULL**: so sánh với NULL ra NULL nên khách hạng cao nhất mất điểm. Phải viết `max_value IS NULL OR ...`, hoặc `<= COALESCE(max_value, 2147483647)`.
- Bảng ngưỡng **chồng nhau** (một giá trị nằm trong hai khoảng) làm một khách ra hai dòng. Nếu không chắc bảng sạch, kiểm tra bằng `GROUP BY customer_id HAVING COUNT(*) > 1`.
- Cách khác: unpivot ba chỉ số thành `(customer_id, metric, value)`, join **một lần**, rồi xoay lại bằng `MAX(score) FILTER (WHERE metric = 'R')`. Cách này gọn hơn khi có nhiều chỉ số.

### 2.11 Pareto theo khách, đồng hạng đi cùng nhau (`rfm/04`)

Câu hỏi đặt ra: bao nhiêu phần trăm khách tạo ra 80% doanh thu. Dạng này giống `window/11` (Pareto theo sản phẩm), nhưng khác ở hai điểm: kết quả chỉ là **một dòng tóm tắt**, và **những khách có doanh thu bằng nhau phải cùng vào hoặc cùng ra**.

Quy tắc: khách thuộc nhóm top khi **tổng doanh thu của các khách giàu hơn hẳn mình** còn dưới 80%. "Giàu hơn hẳn" chính là frame `RANGE` mặc định **bỏ nhóm đồng hạng** của dòng hiện tại:

```sql
WITH revenue AS (
  SELECT customer_id, SUM(amount_vnd) AS revenue
  FROM orders WHERE status = 'delivered'
  GROUP BY customer_id
),
ranked AS (
  SELECT revenue,
         COALESCE(SUM(revenue) OVER (ORDER BY revenue DESC
                                     RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                     EXCLUDE GROUP), 0) AS higher_revenue,   -- của khách giàu hơn hẳn
         SUM(revenue) OVER () AS total_revenue
  FROM revenue
)
SELECT COUNT(*) AS total_customers,
       COUNT(*) FILTER (WHERE higher_revenue < 0.8 * total_revenue) AS top_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE higher_revenue < 0.8 * total_revenue)
             / NULLIF(COUNT(*), 0), 1) AS top_customers_pct,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE higher_revenue < 0.8 * total_revenue)
             / NULLIF(SUM(revenue), 0), 1) AS top_revenue_pct
FROM ranked;                                       -- tổng hợp không GROUP BY: luôn ra đúng 1 dòng
```

- `EXCLUDE GROUP` bỏ **mọi dòng đồng hạng** với dòng hiện tại (kể cả chính nó) khỏi frame. Các lựa chọn khác: `EXCLUDE CURRENT ROW` (chỉ bỏ chính dòng đó), `EXCLUDE TIES` (bỏ các dòng đồng hạng nhưng giữ chính nó).
- Khách giàu nhất có frame rỗng nên `SUM` ra NULL, phải `COALESCE(..., 0)`.
- Với doanh thu 40, 35, 10, 10, 2, 1, 1, 1 (triệu): nếu cộng dồn và tách hòa theo `customer_id` như `window/11` thì chỉ lấy 3 khách, còn quy tắc đồng hạng lấy 4 khách (50% khách tạo 95% doanh thu).
- Bảng rỗng: `COUNT` ra 0, các tỷ lệ ra NULL nhờ `NULLIF`, và vẫn có 1 dòng vì truy vấn tổng hợp không có `GROUP BY`.

### 2.12 Đồng hạng phải cùng điểm: `NTILE` so với `CUME_DIST` (`rfm/05`)

`NTILE(5)` cắt danh sách đã sắp xếp thành 5 phần **bằng nhau về số dòng**, nên hai khách cùng frequency vẫn có thể bị chia sang hai điểm khác nhau. `cohort/02` chấp nhận điều này và tách hòa theo `customer_id` cho kết quả cố định. Nếu nghiệp vụ yêu cầu **giá trị bằng nhau thì điểm bằng nhau**, hãy chấm theo **phân vị**:

```
score = ceiling(5 × k / n)     k = số khách có giá trị ≤ giá trị của mình (tính cả mình), n = tổng số khách
```

`k / n` chính là `CUME_DIST()`. Hàm này đếm cả các dòng đồng hạng, nên khách bằng nhau luôn ra cùng điểm:

```sql
SELECT customer_id,
       CEIL(5 * CUME_DIST() OVER (ORDER BY recency_days DESC))::int AS r_score,   -- R: ít ngày = tốt → DESC
       CEIL(5 * CUME_DIST() OVER (ORDER BY frequency))::int         AS f_score,
       CEIL(5 * CUME_DIST() OVER (ORDER BY monetary_vnd))::int      AS m_score
FROM customer_metrics;
```

| Hàm | Khách đồng hạng | Số khách mỗi điểm | Dùng khi |
| --- | --- | --- | --- |
| `NTILE(5)` | Có thể khác điểm (phải thêm cột tách hòa để kết quả cố định) | Gần bằng nhau | Cần 5 nhóm đều nhau (chia danh sách gọi điện) |
| `CEIL(5 * CUME_DIST())` | Luôn cùng điểm | Có thể lệch nhiều | Cần công bằng: cùng hành vi thì cùng điểm |
| `PERCENT_RANK()` | Luôn cùng điểm | | Công thức `(rank − 1) / (n − 1)`: dòng thấp nhất ra 0, dễ lệch khi n nhỏ |

Hệ quả cần nhớ: nếu 6 trên 8 khách cùng frequency = 1 thì cả 6 người được `ceil(5·6/8) = 4`. Một nhóm đồng hạng lớn ở đáy **đẩy điểm của cả nhóm lên cao**. Nếu cả bảng bằng nhau thì mọi khách đều được 5 (với `NTILE` thì sẽ ra 1, 2, 3, 4…).

Cách viết không dùng `CUME_DIST`: `COUNT(*) OVER (ORDER BY frequency)` dùng frame `RANGE` mặc định, đã đếm cả các dòng đồng hạng, nên `k = COUNT(*) OVER (ORDER BY frequency)` và `n = COUNT(*) OVER ()`. Khi tính `5 * k / n` thì nhân trước để tránh chia số nguyên (A5): `CEIL(5.0 * k / n)`.

### 2.13 Bảng luật phân khúc + chọn luật ưu tiên cao nhất (`rfm/06`)

Khi luật phân khúc nằm trong bảng `segment_rules(priority, segment, pattern)` với `pattern` là regex trên mã RFM (`'^5[45][45]$'`), mỗi khách có thể khớp **nhiều luật**. Bài toán lúc này là **top-1 theo nhóm** (5.5): lấy luật khớp có `priority` nhỏ nhất.

```sql
WITH coded AS (
  SELECT customer_id, CONCAT(r_score, f_score, m_score) AS rfm_code FROM customer_rfm
)
SELECT c.customer_id, c.rfm_code,
       COALESCE(best.segment, 'Unclassified') AS segment
FROM coded c
LEFT JOIN LATERAL (                                 -- chạy lại cho TỪNG khách
  SELECT r.segment
  FROM segment_rules r
  WHERE c.rfm_code ~ r.pattern                      -- ~ : khớp regex POSIX (~* : không phân biệt hoa thường)
  ORDER BY r.priority
  LIMIT 1
) best ON TRUE                                      -- LEFT ... ON TRUE: giữ khách không khớp luật nào
ORDER BY c.customer_id;
```

Ba cách viết cho cùng một ý "top-1 mỗi khách":

| Cách | Viết thế nào | Ghi chú |
| --- | --- | --- |
| `LATERAL ... LIMIT 1` | Như trên | Dễ đọc nhất; muốn giữ khách không khớp thì phải `LEFT JOIN LATERAL ... ON TRUE` |
| `DISTINCT ON` | `SELECT DISTINCT ON (c.customer_id) ... LEFT JOIN segment_rules r ON c.rfm_code ~ r.pattern ORDER BY c.customer_id, r.priority` | Riêng PostgreSQL; `ORDER BY` phải bắt đầu bằng đúng các cột trong `DISTINCT ON` |
| `ROW_NUMBER` | `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY priority)` rồi lọc `= 1` | Chạy trên mọi DB |

- Không được dựa vào **thứ tự dòng trong bảng luật** hay thứ tự chữ cái của tên phân khúc. Chỉ `priority` quyết định.
- `LIKE` chỉ có hai ký tự đại diện là `_` và `%`, không diễn đạt được "4 hoặc 5". Cần nhóm ký tự thì dùng `~` (regex) hoặc `SIMILAR TO`.
- Mã RFM ghép từ số bằng `CONCAT` ra **text**. So sánh `'545' > '5'` là so sánh chữ, không phải so sánh số.

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
| Hạng thành viên | Lọc cửa sổ nửa mở → gộp bảng con (hoàn tiền) trước khi nối → `CASE` có `AND` | 2.9 |
| Ngưỡng nằm trong bảng | `LEFT JOIN t ON v >= t.min AND (t.max IS NULL OR v <= t.max)` | 2.10 |
| Pareto, đồng hạng đi cùng nhau | `SUM() OVER (ORDER BY x DESC RANGE ... EXCLUDE GROUP)` < 80% tổng | 2.11 |
| Điểm 1–5, bằng nhau cùng điểm | `CEIL(5 * CUME_DIST() OVER (ORDER BY x))` | 2.12 |
| Chọn luật ưu tiên cao nhất | `LEFT JOIN LATERAL (... WHERE code ~ pattern ORDER BY priority LIMIT 1) ON TRUE` | 2.13 |
| Churn rate thuê bao | Spine tháng `LEFT JOIN` thuê bao chạy ngày 1 → `FILTER (WHERE end_date <= next_start)` | 8.3 |
| Quay lại sau N tháng im lặng | `DISTINCT` tháng → `năm*12+tháng` → `LAG` → `hiện − trước − 1 >= N` | 8.4 |
| new / retained / resurrected / churned | User × spine tháng → cờ `active` → `LAG(active)` → `CASE` | 8.5 |
| Quick ratio | `(new + resurrected) / NULLIF(churned, 0)` | 8.6 |
| NRR / GRR | `SUM(t) / SUM(b)`; GRR bỏ expansion | 8.7 |
| Khoảng cách giữa các lần mua | `DISTINCT` ngày → `d − LAG(d) OVER (PARTITION BY khách ORDER BY d)` | 9.2 |
| Quãng vắng đang mở | `LEAD(d, 1, ngày_chốt)`; mở khi `LEAD(d) IS NULL` | 9.3 |
| Phân bố theo nhóm | Bảng `VALUES(nhóm, thứ_tự, lo, hi)` `LEFT JOIN` theo khoảng | 9.4 |
| Trung vị theo nhóm | `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)::numeric` | 9.5 |
| Lần mua thứ 2 | `ROW_NUMBER` trên ngày khác nhau → `MAX(d) FILTER (WHERE rn = 2)` | 9.6 |
| Trung vị không dùng hàm có sẵn | `ROW_NUMBER` + `COUNT(*) OVER` → `rn IN ((n+1)/2, (n+2)/2)` → `AVG` | 10.3 |
| Trung vị từ bảng tần suất | `SUM(freq) OVER (ORDER BY v)::bigint` → vị trí giữa `BETWEEN cum−freq+1 AND cum` | 10.4 |
| Trung vị trượt | `ROW_NUMBER` + `LATERAL (PERCENTILE_CONT ... WHERE rn BETWEEN rn−k AND rn+k)` | 10.5 |
| LTV công thức | `SUM(rev)/NULLIF(COUNT(order),0) × COUNT(order)/NULLIF(COUNT(DISTINCT cust),0) × 1/NULLIF(churn,0)` | 11.2 |
| Giá trị N ngày đầu | `MIN(d) OVER (PARTITION BY khách)` → `FILTER (WHERE d <= first + N − 1)`, chỉ khách có `first + N − 1 <= ngày_chốt` | 11.3 |
| Đường LTV lũy kế | Cohort × `generate_series` tới cuối kỳ → `SUM(COALESCE(rev,0)) OVER (PARTITION BY cohort ORDER BY m) / size` | 11.5 |
| Hai khoảng chồng nhau | Nửa mở: `a.s < b.e AND b.s < a.e`; đóng: `<=`; cặp: `a.id < b.id` | 12.2 |
| Chia giá trị theo năm | `LATERAL generate_series(năm đầu, năm cuối)` + `LEAST(end, 31/12) − GREATEST(start, 1/1) + 1` | 12.3 |
| Gộp khoảng | `start > MAX(end) OVER (... ROWS UNBOUNDED PRECEDING AND 1 PRECEDING) + 1` → `SUM` cờ | 12.4 |
| Đồng thời lớn nhất | `UNION ALL` (+1, −1) → `GROUP BY ts` → `SUM() OVER (ORDER BY ts)` → `MAX` | 12.5 |
| As-of | `LEFT JOIN LATERAL (... valid_from <= d ORDER BY valid_from DESC LIMIT 1) ON TRUE` | 12.6 |
| FIFO còn lại | `GREATEST(0, LEAST(qty, SUM(qty) OVER (... ORDER BY date, id) − tổng_dùng))` | 13.2 |
| FIFO từng lần dùng | Hai dãy `(cum − qty, cum]` → `JOIN ON a.lo < b.hi AND b.lo < a.hi` → `LEAST(hi) − GREATEST(lo)` | 13.4 |
| Bước chuyển sai | `LAG(status)` → `NOT EXISTS (... from IS NOT DISTINCT FROM ... AND to = ...)` | 14.2 |

**Liên hệ tài liệu chính** ([sql-common-pitfalls.md](sql-common-pitfalls.md)): hàm tổng hợp bỏ qua NULL (A3), chia cho 0 (A5), fan-out (C3), `DISTINCT` che lỗi (C5), ties trong xếp hạng (E6), alias/window trong `WHERE` (E7), window trên `GROUP BY` (F1), frame của window (F2, F3).

---

## Phần 8. Churn, growth accounting và NRR

### 8.1 Nhận diện nhanh

**Dùng để làm gì:** churn (rời bỏ) trả lời câu hỏi *bao nhiêu khách đang mất đi, mất đi bao nhiêu tiền, và có bù lại được không*. Cohort (Phần 3) nhìn theo **thế hệ khách**, còn churn nhìn theo **từng kỳ** (tháng này mất bao nhiêu so với đầu tháng).

Đề nói *"rời bỏ / ngừng hoạt động / hủy gói / quay lại / MAU / quick ratio / NRR / MRR"*. Trước khi viết SQL, xác định dữ liệu thuộc loại nào:

| Loại dữ liệu | Churn nghĩa là | Kỹ thuật | Mục |
| --- | --- | --- | --- |
| **Sự kiện** (đơn hàng, đăng nhập) | Không còn sự kiện trong một khoảng thời gian | `MAX(date)` + ngưỡng ngày, hoặc cờ hoạt động theo tháng + `LAG` | 8.2, 8.4–8.6 |
| **Hợp đồng** (thuê bao có `start_date`, `end_date`) | Hợp đồng kết thúc | Kiểm tra "đang chạy vào ngày d" tại các mốc đầu kỳ | 8.3 |
| **Tiền định kỳ** (MRR) | Doanh thu định kỳ giảm hoặc mất | So MRR từng khách giữa kỳ gốc và kỳ đích | 8.7 |

Ba quyết định phải nói rõ khi làm bài (giống 2.2):

1. **Ngày chốt hoặc kỳ báo cáo cố định**, không dùng `CURRENT_DATE`.
2. **Đơn vị đếm**: khách hay thuê bao? Một khách có thể có hai thuê bao (`churn/02` đếm thuê bao).
3. **Mẫu số** của tỷ lệ churn: số đang hoạt động **đầu kỳ**, không phải cuối kỳ, cũng không phải tổng số khách từng có.

### 8.2 Nhãn trạng thái tại ngày chốt (`churn/01`)

Đây là bài cơ bản nhất: một dòng mỗi khách, gắn nhãn theo số ngày kể từ lần mua cuối. Khung giống 2.6: `LEFT JOIN` từ `customers`, **điều kiện lọc đơn để trong `ON`**, nhánh NULL (chưa mua) đặt đầu tiên trong `CASE`.

```sql
WITH last_order AS (
  SELECT c.customer_id, c.full_name, MAX(o.order_date) AS last_order_date
  FROM customers c
  LEFT JOIN orders o
         ON o.customer_id = c.customer_id
        AND o.status = 'delivered'
        AND o.order_date <= DATE '2024-12-31'          -- đơn sau ngày chốt không được tính
  GROUP BY c.customer_id, c.full_name
)
SELECT customer_id, full_name, last_order_date,
       DATE '2024-12-31' - last_order_date AS days_inactive,
       CASE
         WHEN last_order_date IS NULL                   THEN 'Never bought'
         WHEN DATE '2024-12-31' - last_order_date <= 30 THEN 'Active'
         WHEN DATE '2024-12-31' - last_order_date <= 90 THEN 'At risk'
         ELSE 'Lapsed'
       END AS status
FROM last_order
ORDER BY customer_id;
```

Nếu bỏ nhánh `IS NULL` đi thì khách chưa mua vẫn rơi xuống `ELSE 'Lapsed'`. Như vậy là **sai nghĩa**: người chưa từng mua thì không thể "rời bỏ". Đặt nhánh NULL đầu tiên để nói rõ ý đó.

### 8.3 Churn rate thuê bao: ai được tính là "đang chạy đầu kỳ" (`churn/02`)

Với dữ liệu hợp đồng, mọi thứ quy về **một phép kiểm tra**: thuê bao đang chạy vào ngày d khi `start_date <= d AND (end_date IS NULL OR d < end_date)` (khoảng nửa mở, `end_date` là ngày đã ngừng).

- `active_start` = số thuê bao chạy vào **ngày 1** của tháng.
- `churned` = trong số đó, những thuê bao **không còn chạy vào ngày 1 tháng sau**, tức `end_date <= next_start`.
- `churn_rate = churned / active_start`.

```sql
WITH months AS (
  SELECT d::date AS month_start, (d + INTERVAL '1 month')::date AS next_start
  FROM generate_series(DATE '2024-01-01', DATE '2024-06-01', INTERVAL '1 month') AS d
)
SELECT TO_CHAR(m.month_start, 'YYYY-MM') AS month,
       COUNT(s.sub_id) AS active_start,
       COUNT(s.sub_id) FILTER (WHERE s.end_date <= m.next_start) AS churned,
       ROUND(100.0 * COUNT(s.sub_id) FILTER (WHERE s.end_date <= m.next_start)
             / NULLIF(COUNT(s.sub_id), 0), 1) AS churn_rate_pct
FROM months m
LEFT JOIN subscriptions s                              -- chỉ thuê bao đang chạy ngày 1 mới được nối
       ON s.start_date <= m.month_start
      AND (s.end_date IS NULL OR m.month_start < s.end_date)
GROUP BY m.month_start
ORDER BY m.month_start;
```

Output với dữ liệu của đề:

| month | active_start | churned | churn_rate_pct |
| --- | --- | --- | --- |
| 2024-01 | 4 | 1 | 25.0 |
| 2024-02 | 3 | 2 | 66.7 |
| 2024-03 | 4 | 0 | 0.0 |
| 2024-04 | 4 | 1 | 25.0 |
| 2024-05 | 4 | 0 | 0.0 |
| 2024-06 | 4 | 1 | 25.0 |

- **Định nghĩa "hủy trong tháng" bằng `end_date` nằm trong tháng là sai ở biên**: thuê bao kết thúc đúng ngày 01/05 thì đã chạy hết tháng 4, nhưng `end_date` lại nằm trong tháng 5, trong khi đầu tháng 5 nó không còn chạy. Kết quả là nó không được tính churn ở tháng nào cả. Định nghĩa "chạy ngày 1 tháng này, không chạy ngày 1 tháng sau" không bị lỗ hổng này.
- Thuê bao **bắt đầu và kết thúc trong cùng một tháng** không nằm trong mẫu số, nên cũng không nằm trong tử số. Đó là quy ước chuẩn. Nếu đề muốn tính cả loại này thì phải nói rõ.
- `generate_series` làm **xương sống tháng** (calendar spine). Tháng không có thuê bao nào vẫn có dòng, và `NULLIF` cho tỷ lệ ra NULL.

### 8.4 Hồi sinh sau quãng im lặng: đổi tháng ra số nguyên rồi `LAG` (`churn/03`)

"Im lặng ≥ 2 tháng" tính theo **tháng lịch**, không theo ngày. Mua 31/01 rồi 01/04 chỉ cách 61 ngày nhưng tháng 2 và tháng 3 trống, nên đã im lặng 2 tháng. Ngược lại, mua 01/01 rồi 31/03 cách 90 ngày nhưng chỉ có tháng 2 trống.

```sql
WITH active AS (                                       -- DISTINCT: nhiều đơn trong tháng = 1 tháng hoạt động
  SELECT DISTINCT customer_id,
         EXTRACT(YEAR FROM order_date)::int * 12 + EXTRACT(MONTH FROM order_date)::int AS month_no,
         DATE_TRUNC('month', order_date)::date AS month_start
  FROM orders
),
with_prev AS (
  SELECT *, LAG(month_no)    OVER (PARTITION BY customer_id ORDER BY month_no) AS prev_no,
            LAG(month_start) OVER (PARTITION BY customer_id ORDER BY month_no) AS prev_start
  FROM active
)
SELECT customer_id, TO_CHAR(prev_start, 'YYYY-MM') AS last_active_month,
       TO_CHAR(month_start, 'YYYY-MM') AS returned_month,
       month_no - prev_no - 1 AS silent_months             -- số tháng NẰM GIỮA, nên trừ 1
FROM with_prev
WHERE month_no - prev_no - 1 >= 2
ORDER BY customer_id, month_start;
```

Đây là bài 1.6a (tìm khoảng trống) áp cho tháng: `năm*12 + tháng` biến tháng thành số nguyên liên tục, kể cả khi qua năm mới (11/2023 → 02/2024 là im lặng 2 tháng).

### 8.5 Calendar spine và 4 trạng thái (`churn/04`)

Bốn trạng thái của một user trong tháng t:

| Tháng t−1 | Tháng t | Trạng thái |
| --- | --- | --- |
| (chưa tồn tại) | hoạt động | `new` |
| hoạt động | hoạt động | `retained` |
| không | hoạt động | `resurrected` |
| hoạt động | không | `churned` |
| không | không | (không có dòng) |

**Vì sao cần spine:** `churned` xảy ra ở tháng user **không có dữ liệu**. Nếu chỉ `LAG` trên các tháng có hoạt động thì tháng đó không tồn tại, nên không bao giờ bắt được churn. Phải sinh lưới **user × mọi tháng từ tháng đầu của user**, rồi `LEFT JOIN` cờ hoạt động vào lưới:

```sql
WITH act AS (
  SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m FROM activity
),
months AS (
  SELECT generate_series(MIN(m), MAX(m), INTERVAL '1 month')::date AS m FROM act
),
firsts AS (SELECT user_id, MIN(m) AS first_m FROM act GROUP BY user_id),
grid AS (
  SELECT f.user_id, mo.m, f.first_m, a.user_id IS NOT NULL AS active
  FROM firsts f
  JOIN months mo ON mo.m >= f.first_m                  -- không sinh dòng trước khi user xuất hiện
  LEFT JOIN act a ON a.user_id = f.user_id AND a.m = mo.m
),
labeled AS (
  SELECT user_id, m,
         CASE
           WHEN active AND m = first_m       THEN 'new'
           WHEN active AND LAG(active) OVER w THEN 'retained'
           WHEN active                       THEN 'resurrected'
           WHEN LAG(active) OVER w           THEN 'churned'
         END AS status
  FROM grid
  WINDOW w AS (PARTITION BY user_id ORDER BY m)        -- WINDOW: đặt tên cho cửa sổ dùng nhiều lần
)
SELECT TO_CHAR(m, 'YYYY-MM') AS month, user_id, status
FROM labeled WHERE status IS NOT NULL
ORDER BY m, user_id;
```

- `LAG(active)` ở tháng đầu tiên của user ra NULL. Nhánh `new` đứng trước nên không bị ảnh hưởng. Ở các nhánh sau, `WHEN NULL` được coi là sai, nên vẫn an toàn.
- Window function **dùng được trong `CASE`** ở cùng tầng `SELECT`, nhưng **không dùng được trong `WHERE`** của tầng đó (E7). Vì vậy việc lọc `status IS NOT NULL` phải làm ở tầng ngoài.
- Spine lấy từ `MIN(m)` đến `MAX(m)` của **toàn bộ dữ liệu**, nên tháng không ai hoạt động vẫn có dòng (user tháng trước vẫn bị gắn `churned`).

### 8.6 Growth accounting và Quick Ratio (`churn/05`)

Growth accounting gom 4 trạng thái của 8.5 thành **một dòng mỗi tháng**:

```
MAU(t)      = new + retained + resurrected
MAU(t)      = MAU(t−1) + new + resurrected − churned        ← đẳng thức dùng để tự kiểm tra
Quick ratio = (new + resurrected) / churned                 ← > 1: tăng trưởng, < 1: đang co lại
```

Điểm khó của `churn/05`: **kỳ báo cáo** (2024-01 đến 2024-06) **khác với kỳ lịch sử**. Hoạt động năm 2023 không được in ra, nhưng vẫn quyết định trạng thái của tháng 1: user có hoạt động 12/2023 thì tháng 1 là `retained`, user có hoạt động 10/2023 thì tháng 1 là `resurrected`, user chỉ hoạt động 12/2023 thì bị tính `churned` ở tháng 1. Vì vậy:

1. Lưới của mỗi user chạy từ **tháng đầu của user** (có thể năm 2023) đến cuối kỳ báo cáo. Dùng `CROSS JOIN LATERAL generate_series(f.first_m, DATE '2024-06-01', INTERVAL '1 month')`, mỗi user một chuỗi tháng riêng.
2. Gắn nhãn như 8.5.
3. Spine **riêng của kỳ báo cáo** `LEFT JOIN` nhãn, rồi đếm `COUNT(*) FILTER (WHERE status = ...)`. Tháng trước kỳ báo cáo tự rơi ra, tháng trống ra 0.

```sql
-- labeled = (m, status) như 8.5 nhưng lưới theo từng user đến 2024-06
report AS (SELECT generate_series(DATE '2024-01-01', DATE '2024-06-01', INTERVAL '1 month')::date AS m)
SELECT TO_CHAR(r.m, 'YYYY-MM') AS month,
       COUNT(*) FILTER (WHERE l.status IN ('new', 'retained', 'resurrected')) AS mau,
       COUNT(*) FILTER (WHERE l.status = 'new')         AS new_users,
       COUNT(*) FILTER (WHERE l.status = 'retained')    AS retained,
       COUNT(*) FILTER (WHERE l.status = 'resurrected') AS resurrected,
       COUNT(*) FILTER (WHERE l.status = 'churned')     AS churned
FROM report r LEFT JOIN labeled l ON l.m = r.m
GROUP BY r.m ORDER BY r.m;
-- quick_ratio = ROUND((new_users + resurrected)::numeric / NULLIF(churned, 0), 2) ở tầng ngoài
```

Output với dữ liệu của đề (kiểm tra đẳng thức: tháng 2 là 3 + 1 + 0 − 2 = 2):

| month | mau | new_users | retained | resurrected | churned | quick_ratio |
| --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 3 | 1 | 1 | 1 | 0 | NULL |
| 2024-02 | 2 | 1 | 1 | 0 | 2 | 0.50 |
| 2024-03 | 2 | 0 | 1 | 1 | 1 | 1.00 |
| 2024-04 | 3 | 1 | 2 | 0 | 0 | NULL |
| 2024-05 | 1 | 0 | 1 | 0 | 2 | 0.00 |
| 2024-06 | 3 | 1 | 1 | 1 | 0 | NULL |

`COUNT(*) FILTER` trên `LEFT JOIN`: tháng không có nhãn nào vẫn có một dòng với `l.status` NULL. `COUNT(*)` không có `FILTER` sẽ đếm dòng NULL đó thành 1, nhưng vì mọi cột đều có `FILTER (WHERE l.status ...)` nên dòng NULL bị loại và kết quả ra 0. Nhớ ép `::numeric` trước khi chia (A5).

### 8.7 MRR, NRR và GRR (`churn/06`)

**NRR** (Net Revenue Retention) cho biết: các khách **đã có ở kỳ gốc**, đến kỳ đích trả bao nhiêu phần trăm so với trước. Con số này **không tính khách mới**. NRR > 100% nghĩa là phần khách cũ nâng gói đã bù được phần khách rời đi.

| Thành phần | Điều kiện (b = MRR kỳ gốc, t = MRR kỳ đích) | Giá trị |
| --- | --- | --- |
| Expansion | t > b | t − b |
| Contraction | 0 < t < b | b − t |
| Churned | t = 0 | b |

```
NRR = (start + expansion − contraction − churned) / start  =  SUM(t) / SUM(b)
GRR = (start − contraction − churned) / start               ← không cộng expansion, tối đa 100%
```

```sql
WITH mrr AS (                                          -- gộp các dòng sản phẩm thành MRR mỗi khách-tháng TRƯỚC
  SELECT customer_id, billing_month, SUM(mrr_vnd) AS mrr
  FROM subscription_items GROUP BY customer_id, billing_month
),
pairs AS (                                             -- chỉ khách của kỳ gốc; không có ở kỳ đích → 0
  SELECT b.customer_id, b.mrr AS b, COALESCE(t.mrr, 0) AS t
  FROM mrr b
  LEFT JOIN mrr t ON t.customer_id = b.customer_id AND t.billing_month = DATE '2024-07-01'
  WHERE b.billing_month = DATE '2024-01-01' AND b.mrr > 0
)
SELECT COALESCE(SUM(b), 0)                                    AS starting_mrr,
       COALESCE(SUM(t - b) FILTER (WHERE t > b), 0)           AS expansion_mrr,
       COALESCE(SUM(b - t) FILTER (WHERE t > 0 AND t < b), 0) AS contraction_mrr,
       COALESCE(SUM(b) FILTER (WHERE t = 0), 0)               AS churned_mrr,
       COALESCE(SUM(t), 0)                                    AS ending_mrr
FROM pairs;   -- nrr_pct, grr_pct tính ở tầng ngoài, chia NULLIF(starting_mrr, 0)
```

Với dữ liệu của đề: start 2.000.000, expansion 200.000, contraction 150.000, churned 300.000, ending 1.750.000, nên **NRR = 87.5%, GRR = 77.5%**. Khách 5 (chỉ xuất hiện ở tháng 7, 900.000) không được tính. Nếu tính nhầm thì NRR sẽ vượt 130%.

- **Gộp line item trước khi so sánh**: nếu so từng dòng sản phẩm, khách đổi gói Pro sang Basic sẽ bị tính thành một dòng churn cộng một dòng mới, thay vì một lần contraction.
- **Khách tạm ngưng giữa kỳ rồi quay lại**: NRR chỉ so hai mốc (khách 6 nghỉ từ tháng 3 đến tháng 6 nhưng tháng 7 trả như cũ, nên không thay đổi gì).
- `LEFT JOIN` từ kỳ gốc sang kỳ đích, **điều kiện tháng đích đặt trong `ON`**. Đặt ở `WHERE` sẽ làm mất khách churn (bẫy thiếu dòng, Phần 0).

### 8.8 Bẫy churn

1. **Mẫu số sai**: chia cho số khách cuối kỳ hoặc tổng số khách từng có, thay vì số đang hoạt động **đầu kỳ**.
2. **Không có spine**: `LAG` trên các tháng có dữ liệu sẽ bỏ qua tháng trống, nên không bao giờ thấy `churned`, và tháng không ai hoạt động thì biến mất khỏi báo cáo.
3. **Tính im lặng theo ngày khi đề nói tháng** (8.4), hoặc ngược lại.
4. **Bỏ qua lịch sử trước kỳ báo cáo**: user cũ bị tính là `new` ở tháng đầu kỳ (8.6).
5. **Khách mới lọt vào NRR**: phải `LEFT JOIN` **từ** kỳ gốc, không `FULL JOIN` và không gộp cả kỳ đích (8.7).
6. **Biên `end_date`**: khoảng nửa mở `d < end_date`. Kết thúc đúng ngày 1 thì không còn chạy ngày đó (8.3).
7. **Chia cho 0** khi đầu kỳ không có ai, hoặc tháng không có churn: dùng `NULLIF(..., 0)` và để kết quả là NULL, không phải 0.

---

## Phần 9. Khoảng cách giữa các lần mua

### 9.1 Nhận diện nhanh

**Dùng để làm gì:** đo **nhịp mua** của khách: bao lâu mua một lần, bao lâu thì quay lại, ai đang vắng lâu bất thường. Kết quả dùng để đặt lịch nhắc mua lại, chọn ngưỡng "có nguy cơ rời bỏ" cho churn (8.2), và so sánh chất lượng các kênh thu hút khách.

Đề nói *"khoảng cách giữa hai lần mua"*, *"bao lâu thì quay lại"*, *"vắng lâu nhất"*, *"nhịp mua"*. Ba dạng gần giống nhau nhưng khác bản chất:

| Dạng | Câu hỏi | Kỹ thuật | Mục |
| --- | --- | --- | --- |
| Gaps & Islands | Các **chuỗi liên tiếp** dài bao nhiêu, thiếu số nào? | `x − ROW_NUMBER()` | 1 |
| Im lặng theo tháng | Có quay lại sau N **tháng lịch** trống không? | `năm*12+tháng` + `LAG` | 8.4 |
| **Khoảng cách giữa các lần mua** | Hai lần mua cách nhau **bao nhiêu ngày**, phân bố thế nào? | `DISTINCT` ngày → `LAG` → tổng hợp | 9 |

Khung chung của mọi bài trong phần này:

```sql
WITH days AS (                                         -- 1. khử trùng: nhiều đơn cùng ngày = 1 lần mua
  SELECT DISTINCT customer_id, order_date FROM orders
),
gaps AS (                                              -- 2. khoảng cách tới lần mua trước (NULL ở lần đầu)
  SELECT customer_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS gap
  FROM days
)
-- 3. tổng hợp: theo khách (9.2, 9.5), theo nhóm khoảng (9.4), theo kênh (9.6)
```

Bỏ bước 1 thì hai đơn cùng ngày sinh ra khoảng cách **0**, kéo `MIN` và `AVG` xuống, và làm sai các quy tắc như "lần mua thứ 2".

### 9.2 Thống kê theo khách (`gaps/01`)

```sql
SELECT customer_id,
       COUNT(*)           AS purchase_days,            -- đếm cả ngày đầu tiên (gap NULL)
       MIN(gap)           AS min_gap,                  -- MIN / AVG / MAX bỏ qua NULL (A3)
       ROUND(AVG(gap), 1) AS avg_gap,
       MAX(gap)           AS max_gap
FROM gaps
GROUP BY customer_id
HAVING COUNT(*) >= 2                                   -- hoặc COUNT(gap) >= 1
ORDER BY customer_id;
```

- `DATE − DATE` ra **số nguyên** (số ngày), nên `AVG` ra `numeric` và `ROUND(…, 1)` dùng được ngay. Nếu cột là `timestamp` thì phép trừ ra `interval`. Khi đó dùng `order_ts::date` hoặc `EXTRACT(EPOCH FROM …) / 86400`.
- `COUNT(*)` và `COUNT(gap)` khác nhau đúng 1 với mỗi khách: dòng đầu tiên có `gap` là NULL.
- `LAG` sắp theo `ORDER BY` **trong `OVER`**, không phụ thuộc thứ tự dòng trong bảng (hidden test có dữ liệu không sắp xếp).

### 9.3 Quãng đang mở: `LEAD(…, 1, ngày_chốt)` (`gaps/02`)

Một khách mua lần cuối từ tháng 3 và chưa quay lại thì **quãng im lặng dài nhất đang diễn ra**, chưa kết thúc. Dùng `LEAD` thay cho `LAG` để mỗi ngày mua nhìn về **lần mua kế tiếp**. Tham số thứ 3 của `LEAD` là giá trị thay thế khi không có dòng kế tiếp, ở đây là ngày chốt:

```sql
silences AS (
  SELECT customer_id,
         order_date AS gap_start,
         LEAD(order_date, 1, DATE '2024-12-31') OVER (PARTITION BY customer_id ORDER BY order_date) AS gap_end,
         LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) IS NULL AS is_open
  FROM days                                            -- days đã lọc order_date <= ngày chốt
),
ranked AS (
  SELECT *, gap_end - gap_start AS gap_days,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY gap_end - gap_start DESC, gap_start) AS rn
  FROM silences
)
SELECT customer_id, gap_start, gap_end, gap_days,
       CASE WHEN is_open THEN 'open' ELSE 'closed' END AS gap_type
FROM ranked WHERE rn = 1;                              -- top-1 mỗi khách (5.5)
```

- **Phải lọc đơn sau ngày chốt trước khi gọi `LEAD`**. Nếu không, một đơn năm 2025 sẽ đóng quãng mở lại và cho ra một khoảng cách vượt quá ngày chốt.
- Khách chỉ có một ngày mua vẫn có một dòng (quãng mở). Khách mua đúng vào ngày chốt có quãng mở dài 0 ngày.
- Để biết dòng nào là quãng mở, kiểm tra `LEAD(…)` **không có giá trị mặc định** `IS NULL`. Không so `gap_end = ngày_chốt` được, vì một quãng đóng cũng có thể kết thúc đúng ngày chốt.
- Khi hai quãng dài bằng nhau, thêm `gap_start` vào `ORDER BY` để chọn quãng sớm nhất một cách xác định (E6).

### 9.4 Chia nhóm và đủ nhóm (`gaps/03`)

Biểu đồ phân bố khoảng lặng là dạng "đủ mọi phân khúc" của 2.7, kết hợp với bảng ngưỡng của 2.10: một bảng `VALUES` chứa tên nhóm, thứ tự và cận dưới/trên, sau đó `LEFT JOIN` theo khoảng.

```sql
buckets(bucket, sort_key, lo, hi) AS (
  VALUES ('1-7 days', 1, 1, 7), ('8-30 days', 2, 8, 30), ('31-90 days', 3, 31, 90), ('91+ days', 4, 91, NULL)
)
SELECT b.bucket,
       COUNT(g.gap) AS gaps,
       ROUND(100.0 * COUNT(g.gap) / NULLIF(SUM(COUNT(g.gap)) OVER (), 0), 1) AS pct_of_gaps
FROM buckets b
LEFT JOIN gaps g ON g.gap >= b.lo AND (b.hi IS NULL OR g.gap <= b.hi)
GROUP BY b.bucket, b.sort_key
ORDER BY b.sort_key;
```

| bucket | gaps | pct_of_gaps |
| --- | --- | --- |
| 1-7 days | 2 | 20.0 |
| 8-30 days | 3 | 30.0 |
| 31-90 days | 3 | 30.0 |
| 91+ days | 2 | 20.0 |

- Gap NULL của ngày mua đầu tiên không khớp nhóm nào, nên tự rơi ra. Không cần lọc `WHERE gap IS NOT NULL`.
- Viết `CASE WHEN gap <= 7 THEN … END` rồi `GROUP BY` thì **nhóm rỗng sẽ biến mất**, và sắp theo tên nhóm thì `'31-90'` đứng trước `'8-30'` (so sánh chữ). Bảng `VALUES` giải quyết được cả hai vấn đề.
- Khi không có khoảng cách nào, `SUM(COUNT()) OVER ()` bằng 0, `NULLIF` biến nó thành NULL, nên tỷ lệ ra NULL thay vì báo lỗi chia cho 0.

### 9.5 Ngưỡng tương đối theo trung vị của chính khách (`gaps/04`)

Một ngưỡng chung "vắng hơn 30 ngày" là sai với cả hai loại khách: khách mua hằng tuần vắng 25 ngày đã là bất thường, còn khách mua theo quý vắng 60 ngày vẫn bình thường. Hãy so mỗi khách với **nhịp của chính họ**:

```sql
per_customer AS (
  SELECT customer_id,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap)::numeric AS median_gap,
         DATE '2024-12-31' - MAX(order_date)                       AS days_since_last
  FROM gaps
  GROUP BY customer_id
  HAVING COUNT(gap) >= 3                               -- quá ít khoảng cách thì trung vị không đáng tin
)
SELECT customer_id, ROUND(median_gap, 1) AS median_gap, days_since_last,
       ROUND(days_since_last / median_gap, 1) AS ratio
FROM per_customer
WHERE days_since_last > 2 * median_gap
ORDER BY days_since_last / median_gap DESC, customer_id;
```

- **Vì sao dùng trung vị chứ không dùng trung bình:** chỉ một lần nghỉ dài đã kéo trung bình lên rất cao. Khách 3 của đề có các khoảng 10, 100, 12, 14: trung bình là 34, nên ngưỡng 2 × 34 = 68 không bắt được 27 ngày vắng. Trung vị là 13, ngưỡng 26 thì bắt được.
- `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)` là hàm tổng hợp **có thứ tự** (ordered-set aggregate). Nó dùng được với `GROUP BY` như `AVG`, và khi số phần tử chẵn thì lấy trung bình hai giá trị giữa. `PERCENTILE_DISC` thì lấy một giá trị có thật trong dữ liệu.
- `PERCENTILE_CONT` trả về `double precision`, mà PostgreSQL **không có `ROUND(double precision, int)`**. Phải ép `::numeric` trước khi `ROUND`, nếu không sẽ gặp lỗi `function round(double precision, integer) does not exist`.
- `ORDER BY` theo biểu thức gốc (`days_since_last / median_gap`), không theo `ratio` đã làm tròn, để hai khách có ratio làm tròn bằng nhau vẫn được sắp đúng.

### 9.6 Thời gian tới lần mua thứ 2, trung bình và trung vị (`gaps/05`)

Dạng này giống `cohort/04` ở chỗ lấy ngày mua thứ 1 và thứ 2 bằng `ROW_NUMBER` rồi xoay về một dòng mỗi khách bằng `MAX(...) FILTER`. Điểm khác là phần tổng hợp theo kênh:

```sql
SELECT c.channel,
       COUNT(p.customer_id)    AS buyers,              -- LEFT JOIN: khách chưa mua không có dòng p
       COUNT(p.days_to_return) AS returned,            -- NULL = chưa quay lại
       ROUND(100.0 * COUNT(p.days_to_return) / NULLIF(COUNT(p.customer_id), 0), 1) AS return_rate_pct,
       ROUND(AVG(p.days_to_return), 1) AS avg_days,    -- chỉ tính khách đã quay lại
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.days_to_return))::numeric, 1) AS median_days
FROM customers c
LEFT JOIN per_customer p ON p.customer_id = c.customer_id
GROUP BY c.channel;
```

| channel | buyers | returned | return_rate_pct | avg_days | median_days |
| --- | --- | --- | --- | --- | --- |
| Facebook | 3 | 2 | 66.7 | 35.0 | 35.0 |
| Referral | 0 | 0 | NULL | NULL | NULL |
| Shopee | 1 | 0 | 0.0 | NULL | NULL |
| TikTok Shop | 4 | 4 | 100.0 | 52.3 | 3.5 |

- **Ba mẫu số khác nhau trong cùng một dòng**: số khách của kênh (`COUNT(*)`, không dùng), số người mua (`COUNT(p.customer_id)`) và số người quay lại (`AVG` và `PERCENTILE_CONT` ngầm dùng con số này vì bỏ qua NULL). Đọc kỹ đề để biết tỷ lệ nào chia cho mẫu số nào.
- TikTok Shop: ba khách quay lại sau 2–4 ngày, một khách sau 200 ngày. Trung bình 52.3 ngày không đại diện cho ai cả, còn trung vị 3.5 ngày mới mô tả đúng hành vi phổ biến. Khi báo cáo "thời gian quay lại", nên đưa cả hai con số.
- Đơn thứ 2 trong **cùng ngày** không được tính là quay lại. Vì vậy phải `ROW_NUMBER` trên `DISTINCT` ngày, không đánh số trên từng đơn.

### 9.7 Bẫy khoảng cách

1. **Không khử trùng ngày**: đơn cùng ngày tạo khoảng cách 0, và "lần mua thứ 2" bị lấy nhầm vào cùng ngày.
2. **Quên quãng đang mở** khi đề hỏi "vắng lâu nhất" (9.3), hoặc ngược lại, tính quãng mở khi đề chỉ hỏi khoảng cách giữa hai lần mua.
3. **Đơn sau ngày chốt** chưa bị lọc mà đã vào `LEAD`/`LAG`.
4. **Trung bình bị một giá trị ngoại lai kéo lệch**: với nhịp mua hãy dùng trung vị (9.5, 9.6).
5. **`ROUND(double precision, int)` không tồn tại**: ép `::numeric` sau `PERCENTILE_CONT`, `CUME_DIST`, `EXTRACT`.
6. **Nhóm rỗng biến mất, nhóm sắp theo chữ cái**: dùng bảng `VALUES` có cột thứ tự (9.4).
7. **Khách 1 đơn**: tùy đề mà loại ra (`HAVING COUNT(gap) >= …`) hoặc giữ lại trong mẫu số (9.6). Không được ngầm loại họ ra khỏi tỷ lệ quay lại.

---

## Phần 10. Trung vị và phân vị

### 10.1 Nhận diện nhanh

**Dùng để làm gì:** trung vị (median) là giá trị **đứng giữa** khi sắp xếp dữ liệu. Nó trả lời câu hỏi *"một khách / một đơn / một ngày **điển hình** trông thế nào"*. Trung bình thì trả lời *"chia đều tổng cho mọi người thì mỗi người được bao nhiêu"*. Khi dữ liệu có vài giá trị rất lớn (lương giám đốc, đơn sỉ, ngày khuyến mãi), trung bình bị kéo lệch còn trung vị thì gần như không đổi.

Đề nói *"trung vị"*, *"giá trị điển hình"*, *"phân vị 50 / 90"*, *"không bị ảnh hưởng bởi ngoại lai"*.

| Công cụ | Kết quả | Số phần tử chẵn | Ghi chú |
| --- | --- | --- | --- |
| `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)` | `double precision` | Trung bình 2 giá trị giữa | Định nghĩa "trung vị" trong sách giáo khoa. Phải ép `::numeric` trước khi `ROUND` (9.5) |
| `PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY x)` | Cùng kiểu với `x` | Giá trị giữa **thấp hơn** | Luôn là một giá trị có thật trong dữ liệu |
| `ROW_NUMBER` + `COUNT` (10.3) | Tùy cách tính | Tự viết | Chạy trên mọi DB (MySQL không có `PERCENTILE_CONT`). Hay gặp khi phỏng vấn |
| `percentile_cont(ARRAY[0.25, 0.5, 0.75])` | Mảng | | Nhiều phân vị trong một lần gọi |

Hai đặc điểm phải nhớ:

1. `PERCENTILE_*` là **hàm tổng hợp có thứ tự** (ordered-set aggregate): dùng với `GROUP BY` như `AVG`, bỏ qua NULL, nhưng **không có dạng window**. `PERCENTILE_CONT(...) OVER (...)` báo lỗi `OVER is not supported for ordered-set aggregate percentile_cont`. Trung vị trượt phải làm theo cách khác (10.5).
2. PostgreSQL **không có hàm `MEDIAN()`**. Một số DB khác có (Oracle, Snowflake).

### 10.2 Trung bình và trung vị, đọc độ lệch (`median/01`)

```sql
WITH stats AS (
  SELECT category,
         COUNT(price_vnd)                                                AS products,
         AVG(price_vnd)                                                  AS avg_price,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_vnd)::numeric AS median_price,
         PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price_vnd)          AS median_disc
  FROM products
  WHERE price_vnd IS NOT NULL
  GROUP BY category
)
SELECT category, products, ROUND(avg_price) AS avg_price, ROUND(median_price) AS median_price, median_disc,
       CASE WHEN avg_price > 1.2 * median_price THEN 'right-skewed'
            WHEN avg_price < 0.8 * median_price THEN 'left-skewed'
            ELSE 'balanced' END AS shape
FROM stats
ORDER BY category;
```

| category | products | avg_price | median_price | median_disc | shape |
| --- | --- | --- | --- | --- | --- |
| Headphones | 3 | 300000 | 300000 | 300000 | balanced |
| Phone cases | 2 | 60000 | 60000 | 50000 | balanced |
| Phones | 4 | 10500000 | 4500000 | 4000000 | right-skewed |
| Power banks | 5 | 456000 | 600000 | 600000 | left-skewed |

- **Trung bình > trung vị → lệch phải**: có một số ít giá trị rất lớn (chiếc điện thoại 30 triệu). **Trung bình < trung vị → lệch trái**: có một số ít giá trị rất nhỏ (cục sạc 20 nghìn).
- So sánh bằng **giá trị chưa làm tròn**. Làm tròn trước rồi mới so có thể đổi nhãn ở đúng biên.
- `ORDER BY` trên chữ dùng collation `C.UTF-8` của `check.py`, tức là xếp theo **mã Unicode**: chữ hoa đứng trước chữ thường (`'Zoo' < 'apple'`), và chữ tiếng Việt có dấu (`'Điện thoại'`) đứng sau mọi chữ không dấu. Muốn xếp đúng kiểu tiếng Việt thì cần một collation ICU tiếng Việt. Collation này chỉ có khi PostgreSQL được build kèm ICU; môi trường `check.py` không có, nên `COLLATE "vi-VN-x-icu"` báo lỗi `collation ... does not exist`.

### 10.3 Tự viết trung vị bằng `ROW_NUMBER` + `COUNT` (`median/02`, `misc/04`)

Đánh số từng dòng trong nhóm, biết tổng số dòng `n`, rồi giữ lại **một hoặc hai dòng giữa** và lấy `AVG`:

```sql
WITH ranked AS (
  SELECT department, salary_vnd,
         ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary_vnd) AS rn,
         COUNT(*)     OVER (PARTITION BY department)                     AS n
  FROM employees
  WHERE salary_vnd IS NOT NULL                         -- lọc NULL TRƯỚC khi đánh số
)
SELECT department, ROUND(AVG(salary_vnd), 1) AS median_salary
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
GROUP BY department;
```

| n | `(n + 1) / 2` | `(n + 2) / 2` | Dòng được giữ |
| --- | --- | --- | --- |
| 3 | 2 | 2 | dòng 2 (một dòng) |
| 4 | 2 | 3 | dòng 2 và 3 (lấy trung bình) |

- Công thức chỉ đúng khi là **phép chia số nguyên**. `COUNT(*)` trả về `bigint` nên đúng. Nếu `n` là `numeric` (chẳng hạn đến từ `SUM`) thì `(4 + 1) / 2 = 2.5`, không khớp `rn` nào (10.4).
- **Phải dùng `ROW_NUMBER`, không dùng `RANK` hay `DENSE_RANK`**: với lương 10, 10, 30, 40 (trung vị 20) thì `RANK` cho 1, 1, 3, 4, chỉ giữ được dòng 30 nên ra 30. `DENSE_RANK` cho 1, 1, 2, 3, giữ được 30 và 40 nên ra 35. `ROW_NUMBER` coi hai giá trị 10 là hai vị trí riêng.
- NULL phải bị loại trong `WHERE` **trước** window function. Nếu lọc sau thì NULL vẫn chiếm vị trí trong `n` (`ORDER BY` xếp NULL cuối cùng), làm lệch vị trí giữa.
- Cách viết khác: `WHERE rn BETWEEN n / 2.0 AND n / 2.0 + 1`. Cách này đúng cho cả n chẵn và lẻ mà không cần chia số nguyên.

### 10.4 Trung vị từ bảng tần suất (`median/03`)

Dữ liệu đã gộp sẵn thành dạng (giá trị, số lần), ví dụ "có 1.000.000 đơn 1 món". Bung ra thành từng dòng bằng `generate_series` thì đúng nhưng tốn bộ nhớ. Cách đúng là **tính vị trí bằng tổng lũy kế**: giá trị v có `freq` lần sẽ chiếm các vị trí từ `cum − freq + 1` đến `cum`.

```sql
WITH cum AS (
  SELECT store, items, orders,
         SUM(orders) OVER (PARTITION BY store ORDER BY items)::bigint AS cum_to,
         SUM(orders) OVER (PARTITION BY store)::bigint                AS total
  FROM basket_sizes
),
middle AS (
  SELECT store, items, total
  FROM cum
  WHERE (total + 1) / 2 BETWEEN cum_to - orders + 1 AND cum_to      -- vị trí giữa dưới
     OR (total + 2) / 2 BETWEEN cum_to - orders + 1 AND cum_to      -- vị trí giữa trên
)
SELECT store, MAX(total) AS total_orders, ROUND(AVG(items), 1) AS median_items
FROM middle
GROUP BY store;
```

| items | orders | Vị trí chiếm (District 1, total = 10) |
| --- | --- | --- |
| 1 | 5 | 1–5 ← vị trí 5 |
| 2 | 3 | 6–8 ← vị trí 6 |
| 3 | 1 | 9 |
| 4 | 1 | 10 |

Trung vị = (1 + 2) / 2 = **1.5**.

- **Bẫy kiểu dữ liệu**: `SUM(bigint)` trả về **`numeric`**, không phải `bigint`. Khi đó `(10 + 1) / 2 = 5.5`, không nằm trong khoảng nào, nên chỉ còn lại vị trí 6 và kết quả sai thành 2.0. Lỗi này **chỉ xảy ra khi tổng chẵn**. Ép `::bigint`, hoặc dùng `div(total + 1, 2)`.
- Giá trị có `freq = 0` có khoảng rỗng (`cum − 0 + 1 > cum`), nên tự động không bao giờ được chọn.
- `ORDER BY items` trong `OVER` là bắt buộc. Thứ tự dòng trong bảng không có ý nghĩa gì.
- Cùng ý tưởng này áp dụng cho phân vị bất kỳ: phân vị p nằm ở vị trí `CEIL(p × total)` (theo kiểu `PERCENTILE_DISC`).

### 10.5 Trung vị trượt: vì sao không viết `OVER` được, và cách dùng `LATERAL` (`median/04`)

`AVG(x) OVER (ORDER BY d ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)` chạy được, nhưng `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x) OVER (...)` thì báo lỗi. Giải pháp là: đánh số dòng, rồi với **mỗi dòng** chạy một truy vấn con trên các dòng lân cận:

```sql
WITH numbered AS (
  SELECT sale_date, revenue_m, ROW_NUMBER() OVER (ORDER BY sale_date) AS rn FROM daily_sales
)
SELECT d.sale_date, d.revenue_m,
       ROUND(AVG(d.revenue_m) OVER (ORDER BY d.sale_date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 1) AS rolling_avg,
       ROUND(w.med::numeric, 1) AS rolling_median
FROM numbered d
CROSS JOIN LATERAL (
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n.revenue_m) AS med
  FROM numbered n
  WHERE n.rn BETWEEN d.rn - 2 AND d.rn + 2             -- ở hai đầu tự còn 3–4 dòng
) w
ORDER BY d.sale_date;
```

| sale_date | revenue_m | rolling_avg | rolling_median |
| --- | --- | --- | --- |
| 2024-02-01 | 100 | 110.0 | 110.0 |
| 2024-02-02 | 120 | 307.5 | 115.0 |
| 2024-02-03 | 110 | 272.0 | 120.0 |
| 2024-02-04 | 900 | 277.0 | 125.0 |
| 2024-02-05 | 130 | 281.0 | 130.0 |
| 2024-02-06 | 125 | 286.0 | 135.0 |
| 2024-02-08 | 140 | 132.5 | 132.5 |
| 2024-02-09 | 135 | 133.3 | 135.0 |

- Ngày khuyến mãi (900) đẩy **trung bình trượt** của cả 5 dòng lên gần 300, còn **trung vị trượt** gần như không đổi. Vì vậy trung vị trượt hay được dùng để vẽ "đường xu hướng" và để phát hiện ngoại lai (so mỗi ngày với trung vị trượt của nó).
- "5 dòng" thì đánh số bằng `ROW_NUMBER` và lọc theo `rn`. Ngày 07/02 không có dòng nên không bị tính. Nếu đề nói "5 **ngày**" thì lọc theo `n.sale_date BETWEEN d.sale_date - 2 AND d.sale_date + 2` (giống `RANGE`).
- Cách khác không dùng `LATERAL`: self-join `numbered d JOIN numbered n ON n.rn BETWEEN d.rn - 2 AND d.rn + 2`, rồi `GROUP BY d.sale_date, d.revenue_m`. Với n dòng, cả hai cách đều tốn khoảng 5n phép so sánh.

### 10.6 Bẫy trung vị

1. **NULL**: `PERCENTILE_*` tự bỏ qua NULL. Còn cách `ROW_NUMBER` thì phải lọc NULL **trước khi** đánh số (10.3).
2. **Số phần tử chẵn**: `CONT` lấy trung bình hai giá trị giữa, `DISC` lấy giá trị thấp hơn. Đọc kỹ đề muốn cách nào.
3. **`RANK` / `DENSE_RANK` thay cho `ROW_NUMBER`**: khi có giá trị trùng sẽ không tìm thấy vị trí giữa.
4. **Chia không phải số nguyên**: `(n + 1) / 2` chỉ đúng khi `n` là kiểu số nguyên. Kết quả của `SUM` trên số nguyên là `numeric` (10.4).
5. **`ROUND(double precision, int)` không tồn tại**: ép `::numeric` (9.5).
6. **`PERCENTILE_CONT ... OVER` không tồn tại**: trung vị trượt phải dùng `LATERAL` hoặc self-join (10.5).
7. **Trung vị của các trung vị khác trung vị tổng**: trung vị theo từng phòng ban rồi lấy trung vị của chúng **không bằng** trung vị của toàn công ty. Muốn trung vị tổng thì tính lại trên dữ liệu gốc.

---

## Phần 11. LTV (giá trị vòng đời khách hàng)

### 11.1 Nhận diện nhanh

**Dùng để làm gì:** LTV (Customer Lifetime Value) ước tính **một khách mang về bao nhiêu tiền trong suốt thời gian gắn bó**. Con số này dùng để quyết định được phép chi bao nhiêu để có một khách mới (CAC), và kênh nào mang về khách "đáng tiền" hơn.

Đề nói *"LTV / CLV / giá trị vòng đời"*, *"doanh thu trên mỗi khách theo tuổi"*, *"giá trị N ngày đầu"*. Có ba cách đo, trả lời ba câu hỏi khác nhau:

| Cách đo | Công thức | Ưu / nhược | Mục |
| --- | --- | --- | --- |
| Công thức dự đoán | `AOV × tần suất × vòng đời` | Nhanh, cần giả định về churn; không thấy được đường cong theo thời gian | 11.2 |
| Giá trị N ngày đầu | Doanh thu trong `[ngày đầu, ngày đầu + N − 1]` | So sánh công bằng giữa các tháng thu hút; phải chờ đủ N ngày | 11.3 |
| Đường LTV lũy kế theo cohort | `SUM` lũy kế doanh thu cohort ÷ quy mô cohort theo `month_offset` | Thấy LTV tăng thế nào theo tuổi khách; cần spine | 11.5 |

### 11.2 Công thức `AOV × tần suất × vòng đời` (`ltv/01`)

```
AOV              = doanh thu / số đơn
tần suất (năm)   = số đơn / số khách
vòng đời (năm)   = 1 / tỷ lệ churn năm
LTV              = AOV × tần suất × vòng đời   =  (doanh thu / số khách) × vòng đời
```

```sql
parts AS (
  SELECT channel, customers, orders, revenue,
         revenue::numeric / NULLIF(orders, 0)    AS aov,         -- tỷ số của các TỔNG
         orders::numeric  / NULLIF(customers, 0) AS freq,
         1 / NULLIF(annual_churn_rate, 0)        AS lifespan     -- churn 0 → vòng đời không xác định
  FROM per_channel                                               -- LEFT JOIN từ danh sách kênh, COUNT(DISTINCT customer)
)
SELECT channel, ROUND(aov) AS aov, ROUND(freq, 2) AS annual_frequency,
       ROUND(lifespan, 2) AS lifespan_years,
       ROUND(aov * freq * lifespan) AS ltv                       -- làm tròn MỘT lần, ở cuối
FROM parts;
```

- **AOV = tổng doanh thu ÷ tổng số đơn**, không phải `AVG` của AOV từng khách. Khách mua 1 đơn 1 triệu và khách mua 10 đơn 100 nghìn có AOV trung bình là 550 nghìn, trong khi AOV đúng là 2 triệu ÷ 11 đơn ≈ 182 nghìn.
- **Làm tròn ở cuối**: 333.333 × 1,5 × 3 = 1.499.998,5 nhưng 333.333,33… × 1,5 × 3 = 1.500.000. Hidden test có kiểm tra chỗ này.
- Kênh không có khách vẫn phải hiện (`LEFT JOIN` từ `channel_churn`), với các tỷ số NULL nhờ `NULLIF`. Đếm khách bằng `COUNT(DISTINCT o.customer_id)` (khách không có đơn hợp lệ thì không được tính), không dùng `COUNT(c.customer_id)`.

### 11.3 Giá trị 90 ngày đầu, chỉ khách đã đủ 90 ngày (`ltv/02`)

So sánh LTV giữa các tháng thu hút **không công bằng** nếu khách tháng 1 đã có 12 tháng để mua mà khách tháng 11 mới có 1 tháng. Cách khắc phục là cố định một **cửa sổ chân trời** (90 ngày kể từ lần mua đầu), và chỉ tính những khách đã **đi hết** cửa sổ đó:

```sql
WITH counted AS (
  SELECT customer_id, order_date, amount_vnd,
         MIN(order_date) OVER (PARTITION BY customer_id) AS first_date
  FROM orders
  WHERE status = 'delivered'                          -- lọc TRƯỚC khi tìm lần đầu
),
per_customer AS (
  SELECT customer_id, first_date,
         SUM(amount_vnd) FILTER (WHERE order_date <= first_date + 89) AS value_90d
  FROM counted
  WHERE first_date + 89 <= DATE '2024-12-31'          -- khách "chín": cửa sổ đã kết thúc
  GROUP BY customer_id, first_date
)
SELECT TO_CHAR(first_date, 'YYYY-MM') AS acquisition_month, COUNT(*) AS customers,
       ROUND(AVG(value_90d)) AS avg_value_90d
FROM per_customer GROUP BY 1 ORDER BY 1;
```

- "90 ngày" là **ngày 0 đến ngày 89** (`first_date + 89`). Viết `<= first_date + 90` thì thành 91 ngày. Hidden test có đơn đúng vào ngày 89 và ngày 90.
- `DATE + số nguyên` ra `DATE`. Còn `DATE + INTERVAL '90 days'` ra `timestamp`, so sánh vẫn đúng nhưng kiểu dữ liệu thì đổi.
- Không lọc khách "chín" thì LTV của các tháng gần đây bị **thấp một cách giả tạo** (họ chưa có đủ thời gian để mua).

### 11.4 Tỷ trọng tháng đầu: tỷ số của tổng và trung bình các tỷ số (`ltv/03`)

"Bao nhiêu phần trăm doanh thu vòng đời đến từ tháng đầu?" có **hai đáp án hợp lệ** và thường khác nhau:

| Cách tính | SQL | Ý nghĩa |
| --- | --- | --- |
| Tỷ số của tổng | `SUM(first) / SUM(life)` | Trên **tổng tiền** của cohort: khách chi nhiều có trọng số lớn |
| Trung bình các tỷ số | `AVG(first / life)` | Với **một khách điển hình**: mỗi khách có trọng số bằng nhau |

Ví dụ cohort 01/2024: khách 1 tháng đầu 100k / vòng đời 1 triệu (10%), khách 2 có 500k / 500k (100%). Tỷ số của tổng = 600k / 1,5 triệu = **40%**, còn trung bình các tỷ số = (10 + 100) / 2 = **55%**. Đề phải nói rõ muốn cách nào. Nếu đề không nói, hãy nêu rõ cách mình chọn.

"Tháng đầu" ở đây là **tháng lịch** của lần mua đầu (`DATE_TRUNC('month', ...)`), không phải 30 ngày đầu. Khách mua lần đầu ngày 31/12 thì tháng đầu chỉ có một ngày.

### 11.5 Đường LTV lũy kế theo tuổi cohort (`ltv/04`)

Ghép spine của 8.5 với tổng lũy kế của 5.4: mỗi cohort có một dòng cho **mọi** tháng từ tháng cohort đến cuối kỳ báo cáo, và LTV là tổng lũy kế doanh thu chia quy mô cohort.

```sql
grid AS (                                              -- mỗi cohort: mọi tháng tới cuối kỳ
  SELECT s.cohort, s.cohort_size, g.m::date AS m
  FROM sizes s
  CROSS JOIN LATERAL generate_series(s.cohort, DATE '2024-06-01', INTERVAL '1 month') AS g(m)
)
SELECT TO_CHAR(g.cohort, 'YYYY-MM') AS cohort_month,
       (EXTRACT(YEAR FROM g.m)::int * 12 + EXTRACT(MONTH FROM g.m)::int)
     - (EXTRACT(YEAR FROM g.cohort)::int * 12 + EXTRACT(MONTH FROM g.cohort)::int) AS month_offset,
       g.cohort_size,
       ROUND(SUM(COALESCE(mo.revenue, 0)) OVER (PARTITION BY g.cohort ORDER BY g.m)
             / g.cohort_size::numeric) AS cum_ltv
FROM grid g
LEFT JOIN monthly mo ON mo.cohort = g.cohort AND mo.m = g.m;   -- monthly = doanh thu cohort × tháng
```

| cohort_month | month_offset | cohort_size | cum_ltv |
| --- | --- | --- | --- |
| 2024-03 | 0 | 1 | 200000 |
| 2024-03 | 1 | 1 | 200000 |
| 2024-03 | 2 | 1 | 200000 |
| 2024-03 | 3 | 1 | 200000 |
| 2024-04 | 0 | 2 | 200000 |
| 2024-04 | 1 | 2 | 200000 |
| 2024-04 | 2 | 2 | 300000 |
| 2024-05 | 0 | 3 | 333333 |
| 2024-05 | 1 | 3 | 433333 |
| 2024-06 | 0 | 1 | 50000 |

- **Đường LTV lũy kế không bao giờ đi xuống.** Nếu thấy nó giảm thì chắc chắn là đã chia cho số khách **hoạt động trong tháng** thay vì quy mô cohort.
- Không có spine thì tháng không có doanh thu biến mất (cohort 03 chỉ còn offset 0), và đồ thị bị gãy.
- So sánh các cohort **ở cùng một offset** (cột dọc của ma trận), không so ở cùng tháng lịch.
- Cohort càng mới thì càng có ít offset. Đó là dữ liệu chưa có, không phải giá trị 0. Khi xoay ma trận (3.3), các ô đó nên để NULL.

### 11.6 Bẫy LTV

1. **Trung bình các tỷ số thay vì tỷ số của tổng** (hoặc ngược lại) mà không nói rõ (11.2, 11.4).
2. **So sánh cohort chưa đủ tuổi**: khách mới bị xem là "kém" chỉ vì chưa có thời gian mua (11.3).
3. **Tìm lần mua đầu trước khi lọc đơn hợp lệ**: một đơn bị hủy trở thành "lần đầu", đẩy khách sang sai cohort.
4. **Chia cho số khách hoạt động** thay vì quy mô cohort: đường LTV đi xuống (11.5).
5. **Làm tròn giữa chừng**: sai lệch nhân lên khi nhân AOV × tần suất × vòng đời.
6. **Churn = 0**: `1 / 0` báo lỗi. Dùng `NULLIF` và để vòng đời là NULL (không xác định), không đặt bằng 0.

---

## Phần 12. Khoảng thời gian (intervals) và as-of

### 12.1 Nhận diện nhanh

**Dùng để làm gì:** dữ liệu có **ngày bắt đầu và ngày kết thúc** (đặt phòng, hợp đồng, sự cố, phiên xem) hoặc **giá trị có hiệu lực từ một ngày** (bảng giá, tỷ giá, chức danh nhân viên). Câu hỏi thường gặp: *có trùng lịch không, gộp lại thành bao nhiêu đợt, chia doanh thu theo năm, lúc đông nhất có bao nhiêu người, giá tại ngày X là bao nhiêu*.

**Quyết định đầu tiên: khoảng đóng hay khoảng nửa mở?**

| Kiểu | Ví dụ | Hai khoảng chồng nhau khi | Độ dài |
| --- | --- | --- | --- |
| Nửa mở `[start, end)` | Đặt phòng (ngày trả phòng không tính đêm), phiên xem, thuê bao (8.3) | `a.start < b.end AND b.start < a.end` | `end − start` |
| Đóng `[start, end]` | Hợp đồng, nghỉ phép, sự cố tính theo ngày | `a.start <= b.end AND b.start <= a.end` | `end − start + 1` |

Hai khoảng **không** chồng nhau khi một khoảng kết thúc trước khi khoảng kia bắt đầu. Phủ định điều đó là ra công thức chồng nhau ở trên. Đừng cố liệt kê các trường hợp "A chứa B", "B chứa A", "lệch trái", "lệch phải": công thức hai vế đã bao phủ tất cả.

| Dạng bài | Kỹ thuật | Mục |
| --- | --- | --- |
| Tìm các cặp chồng lịch | Self-join + công thức chồng nhau + `a.id < b.id` | 12.2 |
| Chia giá trị theo năm / tháng | `LATERAL generate_series` các kỳ + cắt bằng `GREATEST` / `LEAST` | 12.3 |
| Gộp khoảng chồng hoặc liền kề | `MAX(end)` của các dòng trước → cờ nhóm mới → `SUM` cờ | 12.4 |
| Số khoảng đồng thời lớn nhất | Sự kiện +1 / −1 → gộp theo thời điểm → `SUM() OVER` | 12.5 |
| Giá trị có hiệu lực tại ngày (as-of) | `LATERAL ... ORDER BY valid_from DESC LIMIT 1` | 12.6 |

### 12.2 Tìm cặp chồng lịch (`intervals/01`)

```sql
SELECT a.room, a.booking_id AS booking_a, b.booking_id AS booking_b,
       GREATEST(a.check_in, b.check_in) AS overlap_start,   -- phần giao: bắt đầu muộn hơn,
       LEAST(a.check_out, b.check_out)  AS overlap_end,     -- kết thúc sớm hơn
       LEAST(a.check_out, b.check_out) - GREATEST(a.check_in, b.check_in) AS overlap_nights
FROM bookings a
JOIN bookings b
  ON b.room = a.room
 AND a.booking_id < b.booking_id                         -- mỗi cặp một lần, không tự ghép với chính mình
 AND a.check_in < b.check_out AND b.check_in < a.check_out;
```

- `a.booking_id < b.booking_id` thay cho `<>`: dùng `<>` thì mỗi cặp ra **hai lần** (A-B và B-A).
- Khoảng nửa mở thì dùng `<` chặt: khách trả phòng ngày 05 và khách nhận phòng ngày 05 **không** trùng nhau. Viết `<=` sẽ báo trùng giả.
- PostgreSQL có sẵn kiểu khoảng: `daterange(check_in, check_out) && daterange(...)` (mặc định nửa mở `[)`) và ràng buộc `EXCLUDE USING gist` để chặn trùng lịch ngay khi ghi dữ liệu. Phỏng vấn thường muốn bạn viết được công thức tay.

### 12.3 Chia giá trị theo năm (`intervals/02`)

Một hợp đồng sinh ra **một dòng cho mỗi năm nó chạm vào**. Sinh các năm bằng `generate_series` trong `LATERAL`, rồi cắt khoảng hợp đồng theo biên năm:

```sql
SELECT c.contract_id, y.yr AS year,
       LEAST(c.end_date, make_date(y.yr, 12, 31)) - GREATEST(c.start_date, make_date(y.yr, 1, 1)) + 1 AS days,
       ROUND(c.value_vnd::numeric
             * (LEAST(c.end_date, make_date(y.yr, 12, 31)) - GREATEST(c.start_date, make_date(y.yr, 1, 1)) + 1)
             / (c.end_date - c.start_date + 1)) AS allocated_vnd
FROM contracts c
CROSS JOIN LATERAL generate_series(EXTRACT(YEAR FROM c.start_date)::int,
                                   EXTRACT(YEAR FROM c.end_date)::int) AS y(yr);
```

- **Nhân trước, chia sau**, và ép `::numeric`. `value * days / total` với số nguyên sẽ bị chia nguyên (A5).
- Làm tròn từng phần thì **tổng có thể lệch 1 đồng** so với giá trị hợp đồng. Nếu đề yêu cầu tổng khớp tuyệt đối thì dồn phần chênh vào kỳ cuối: `value − SUM(các kỳ trước) OVER (...)`.
- Chia theo tháng cũng làm y hệt: `generate_series(DATE_TRUNC('month', start), end, INTERVAL '1 month')`, biên tháng là `m` và `(m + INTERVAL '1 month')::date − 1`.

### 12.4 Gộp khoảng chồng hoặc liền kề (`intervals/03`)

Đây là gaps & islands (Phần 1) áp cho **khoảng**: sắp theo `start`, một khoảng mở đợt mới khi nó bắt đầu **sau điểm kết thúc xa nhất của mọi khoảng trước nó**.

```sql
WITH flagged AS (
  SELECT server, start_date, end_date,
         CASE WHEN start_date <= MAX(end_date) OVER (PARTITION BY server ORDER BY start_date, end_date
                                                     ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) + 1
              THEN 0 ELSE 1 END AS is_new                   -- + 1: liền kề cũng gộp
  FROM incidents
),
grouped AS (
  SELECT *, SUM(is_new) OVER (PARTITION BY server ORDER BY start_date, end_date) AS grp FROM flagged
)
SELECT server, MIN(start_date) AS outage_start, MAX(end_date) AS outage_end, COUNT(*) AS incidents
FROM grouped GROUP BY server, grp;
```

- **So với `MAX(end)` tích lũy, không so với `LAG(end)`**. db-01 có sự cố 01–31/01 rồi 05–07/01 rồi 20–25/01. So với dòng ngay trước (kết thúc 07/01) thì khoảng 20/01 bị tách thành đợt mới, trong khi nó vẫn nằm trong sự cố dài 01–31/01.
- Frame `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING` loại chính dòng hiện tại. Dòng đầu có `MAX` là NULL, so sánh ra NULL nên rơi vào `ELSE 1` (mở đợt mới). Đó đúng là điều mình muốn.
- `ORDER BY start_date, end_date` (có cả `end_date`) để hai sự cố cùng ngày bắt đầu được xếp xác định.
- Bỏ `+ 1` thì chỉ gộp các khoảng **chồng** nhau, không gộp khoảng liền kề. Với khoảng nửa mở thì so `start <= max_end` là đã gộp cả các khoảng chạm nhau.

### 12.5 Số khoảng đồng thời lớn nhất (`intervals/04`)

Biến mỗi khoảng thành **hai sự kiện**: +1 lúc bắt đầu, −1 lúc kết thúc. Tổng lũy kế theo thời gian chính là số khoảng đang mở.

```sql
WITH events AS (
  SELECT joined_at AS ts, 1 AS delta FROM sessions
  UNION ALL
  SELECT left_at, -1 FROM sessions
),
per_ts AS (SELECT ts, SUM(delta) AS delta FROM events GROUP BY ts),   -- gộp các sự kiện cùng thời điểm
running AS (SELECT ts, SUM(delta) OVER (ORDER BY ts) AS viewers FROM per_ts)
SELECT ts, viewers FROM running ORDER BY viewers DESC, ts LIMIT 1;
```

- **Sự kiện cùng thời điểm**: lúc 19:45 Mia rời đi và Paul vào. Nếu xử lý +1 trước −1 thì sẽ có một khoảnh khắc ảo đếm được 4 người. Gộp `SUM(delta)` theo `ts` trước (19:45 ra 0) là cách an toàn nhất. Cách khác là sắp `ORDER BY ts, delta` (−1 trước) với khoảng nửa mở.
- `UNION ALL`, không dùng `UNION`: hai người vào cùng lúc là hai sự kiện +1 giống hệt nhau. `UNION` sẽ khử trùng và làm mất một người (E4).
- Muốn biết đỉnh kéo dài tới khi nào: tìm thời điểm sớm nhất sau đỉnh mà `viewers` nhỏ hơn đỉnh (subquery `MIN(ts)`), như lời giải `intervals/04`.

### 12.6 Giá trị có hiệu lực tại ngày: as-of join (`misc/07`)

Bảng lịch sử chỉ có **ngày bắt đầu hiệu lực**. Giá tại ngày d là dòng có `valid_from` lớn nhất mà vẫn `<= d`:

```sql
SELECT o.order_id, o.product_id, o.order_date, p.price_vnd AS unit_price
FROM order_lines o
LEFT JOIN LATERAL (
  SELECT ph.price_vnd FROM price_history ph
  WHERE ph.product_id = o.product_id AND ph.valid_from <= o.order_date
  ORDER BY ph.valid_from DESC
  LIMIT 1
) p ON TRUE;
```

Cách thứ hai: biến lịch sử thành **khoảng** bằng `LEAD`, rồi join theo khoảng nửa mở:

```sql
WITH ranges AS (
  SELECT product_id, price_vnd, valid_from,
         LEAD(valid_from) OVER (PARTITION BY product_id ORDER BY valid_from) AS valid_to   -- NULL = đang hiệu lực
  FROM price_history
)
SELECT o.order_id, r.price_vnd
FROM order_lines o
LEFT JOIN ranges r
       ON r.product_id = o.product_id
      AND o.order_date >= r.valid_from
      AND (r.valid_to IS NULL OR o.order_date < r.valid_to);
```

- Phải có `product_id` trong điều kiện (cả hai cách). Thiếu nó thì giá mới của **sản phẩm khác** sẽ lọt vào.
- `LEFT` để giữ những đơn đặt **trước khi có giá** (giá NULL). Nếu dùng `CROSS JOIN LATERAL` thì các đơn đó biến mất.
- Cách `LEAD` tiện khi cần dùng lại bảng khoảng nhiều lần (tỷ giá, chức danh). Cách `LATERAL` tiện khi chỉ tra một lần, và chạy nhanh khi có index `(product_id, valid_from)`.

### 12.7 Bẫy khoảng thời gian

1. **Lẫn khoảng đóng và nửa mở**: dùng `<=` thay cho `<` nên báo trùng giả ở các khoảng chạm nhau, hoặc thiếu `+ 1` khi đếm số ngày.
2. **Self-join dùng `<>`**: mỗi cặp ra hai lần.
3. **Gộp khoảng bằng `LAG(end)`** thay vì `MAX(end)` tích lũy (12.4).
4. **Thứ tự sự kiện cùng thời điểm** khi đếm số đồng thời (12.5).
5. **Chia nguyên** khi phân bổ theo tỷ lệ ngày (12.3).
6. **As-of thiếu khóa nối** hoặc dùng `INNER` làm mất các dòng chưa có giá (12.6).

---

## Phần 13. FIFO (nhập trước, xuất trước)

### 13.1 Nhận diện nhanh

**Dùng để làm gì:** phân bổ một lượng (hàng bán ra, tiền khách trả) vào **các lô theo thứ tự cũ nhất trước**: giá trị tồn kho, giá vốn hàng bán, công nợ hóa đơn. Kế toán Việt Nam vẫn dùng FIFO (nhập trước xuất trước) làm phương pháp tính giá xuất kho.

Đề nói *"nhập trước xuất trước"*, *"lô cũ nhất trước"*, *"trả cho hóa đơn cũ nhất"*, *"giá vốn"*. Mẹo cốt lõi: **đừng mô phỏng từng bước bằng vòng lặp**. Hãy biến mỗi lô thành một **khoảng vị trí** trên một trục số bằng tổng lũy kế:

```
lô 1 (100 đv) → (0, 100]     lô 2 (50 đv) → (100, 150]     lô 3 (80 đv) → (150, 230]
đã bán 130 đv → (0, 130]  ⇒  lô 1 hết, lô 2 còn 150 − 130 = 20, lô 3 còn nguyên 80
```

| Câu hỏi | Kỹ thuật | Mục |
| --- | --- | --- |
| Mỗi lô còn lại bao nhiêu (chỉ cần **tổng** đã dùng) | `GREATEST(0, LEAST(qty, cum − tổng_đã_dùng))` | 13.2, 13.3 |
| Lần bán nào lấy từ lô nào (cần **từng** lần dùng) | Hai dãy khoảng `(lo, hi]` → join các khoảng chồng nhau (12.2) | 13.4 |

### 13.2 Giá trị tồn kho (`fifo/01`)

```sql
WITH sold AS (SELECT product, SUM(qty) AS sold_qty FROM sales GROUP BY product),
lots AS (
  SELECT p.product, p.qty, p.unit_cost_vnd,
         SUM(p.qty) OVER (PARTITION BY p.product ORDER BY p.purchase_date, p.lot_id) AS cum_qty,
         COALESCE(s.sold_qty, 0) AS sold_qty
  FROM purchases p LEFT JOIN sold s ON s.product = p.product
)
SELECT product,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)))                 AS remaining_qty,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)) * unit_cost_vnd) AS inventory_value_vnd
FROM lots GROUP BY product;
```

Công thức `GREATEST(0, LEAST(qty, cum − sold))` có ba trường hợp:

| `cum − sold` | Ý nghĩa | Kết quả |
| --- | --- | --- |
| ≤ 0 | Lô đã bị bán hết | 0 |
| từ 0 đến `qty` | Lô đang bán dở | `cum − sold` |
| ≥ `qty` | Chưa đụng tới lô | `qty` |

- `ORDER BY purchase_date, lot_id` trong `OVER`: hai lô cùng ngày phải có thứ tự cố định. Nếu không, frame `RANGE` mặc định sẽ gộp chúng làm một (F2) và cả hai lô có cùng `cum_qty`.
- **Gộp `sales` về một dòng mỗi sản phẩm trước khi nối**, nếu không `purchases` bị nhân lên theo số lần bán (C3).

### 13.3 Trả tiền vào hóa đơn cũ nhất (`fifo/02`)

Y hệt 13.2, chỉ thay "lô hàng" bằng "hóa đơn" và "đã bán" bằng "đã trả". Viết theo dạng **nợ trước hóa đơn này** (`owed_before = cum − amount`) cho dễ đọc:

```sql
GREATEST(0, LEAST(amount_vnd, total_paid - owed_before)) AS paid_vnd
-- owed_before = SUM(amount_vnd) OVER (PARTITION BY customer ORDER BY invoice_date, invoice_id) - amount_vnd
```

- Khách trả **dư** thì mọi hóa đơn đều `paid = amount`, và phần dư không hiện ra ở đâu cả. Nếu đề hỏi số dư có thì tính `total_paid − SUM(amount)` riêng.
- Khách **chưa trả** đồng nào: `LEFT JOIN` + `COALESCE(total_paid, 0)`, nên mọi hóa đơn ra `'Unpaid'`.
- Nhãn trạng thái so sánh `paid = amount` trước, rồi `paid = 0`. Thứ tự này đúng cả với hóa đơn giá trị 0 (được tính là `'Paid'`).

### 13.4 Giá vốn từng lần bán: join hai dãy khoảng (`fifo/03`)

Khi cần biết **lần bán nào lấy hàng từ lô nào**, biến **cả hai phía** thành khoảng `(lo, hi]` rồi join các khoảng chồng nhau. Phần giao `LEAST(hi) − GREATEST(lo)` chính là số đơn vị lần bán đó lấy từ lô đó:

```sql
WITH lots AS (
  SELECT product, unit_cost_vnd,
         SUM(qty) OVER (PARTITION BY product ORDER BY purchase_date, lot_id) - qty AS lo,
         SUM(qty) OVER (PARTITION BY product ORDER BY purchase_date, lot_id)       AS hi
  FROM purchases
),
sold AS (
  SELECT sale_id, product, qty,
         SUM(qty) OVER (PARTITION BY product ORDER BY sale_date, sale_id) - qty AS lo,
         SUM(qty) OVER (PARTITION BY product ORDER BY sale_date, sale_id)       AS hi
  FROM sales
)
SELECT s.sale_id, s.qty,
       SUM((LEAST(s.hi, l.hi) - GREATEST(s.lo, l.lo)) * l.unit_cost_vnd) AS cogs_vnd
FROM sold s
JOIN lots l ON l.product = s.product AND l.lo < s.hi AND s.lo < l.hi
GROUP BY s.sale_id, s.qty;
```

| Lần bán | Khoảng | Lấy từ | Giá vốn |
| --- | --- | --- | --- |
| 1 (60) | (0, 60] | lô 1: 60 × 20.000 | 1.200.000 |
| 2 (70) | (60, 130] | lô 1: 40 × 20.000 + lô 2: 30 × 22.000 | 1.460.000 |
| 3 (40) | (130, 170] | lô 2: 20 × 22.000 + lô 3: 20 × 21.000 | 860.000 |

- Điều kiện chồng nhau phải **chặt** (`<`): lần bán (0, 50] và lô (50, 100] chỉ chạm nhau ở điểm 50, nên không lấy đơn vị nào. Dùng `<=` sẽ thêm một dòng giao bằng 0 đơn vị. Giá vốn không sai, nhưng số lô bị đếm sai.
- Cùng kỹ thuật này dùng được cho: phân bổ ngân sách vào các khoản chi theo thứ tự, ghép lệnh mua với lệnh bán, khấu trừ điểm thưởng theo thứ tự hết hạn.
- Cách này giả định kho **luôn đủ hàng** tại thời điểm bán. Nếu lô về sau ngày bán mà vẫn bị lấy thì phải xử lý theo thời gian thực, tức là vòng lặp (PL/pgSQL) hoặc recursive CTE.

### 13.5 Bẫy FIFO

1. **Thiếu cột tách hòa** trong `ORDER BY` của tổng lũy kế: hai lô cùng ngày có cùng `cum` (F2).
2. **Fan-out** khi nối `purchases` với từng dòng `sales` trước khi gộp (C3).
3. **Nhầm `qty − sold`** (chỉ đúng cho lô đầu tiên) với `cum − sold`.
4. **Quên `GREATEST(0, …)`**: lô đã bán hết ra số âm và kéo tổng tồn kho xuống.
5. **Dùng `<=` khi join khoảng**: thêm các dòng giao 0 đơn vị.

---

## Phần 14. Chuỗi trạng thái (state machine)

### 14.1 Nhận diện nhanh

**Dùng để làm gì:** kiểm tra dữ liệu sự kiện có đi đúng **quy trình** không (đơn hàng, ticket hỗ trợ, hồ sơ vay), tìm các bước bị bỏ qua, bị lặp lại hoặc bị đi ngược.

Đề nói *"chuyển trạng thái hợp lệ / không hợp lệ"*, *"quy trình"*, *"bỏ qua bước"*. Công thức gồm hai bước:

1. `LAG(status) OVER (PARTITION BY id ORDER BY time)` biến mỗi sự kiện thành một **cặp (từ, đến)**.
2. So từng cặp với **bảng các bước hợp lệ** bằng anti-join (E1).

### 14.2 Tìm bước chuyển không hợp lệ (`misc/08`)

```sql
WITH pairs AS (
  SELECT order_id, event_time,
         LAG(status) OVER (PARTITION BY order_id ORDER BY event_time) AS from_status,
         status AS to_status
  FROM order_events
)
SELECT p.*
FROM pairs p
WHERE NOT EXISTS (
  SELECT 1 FROM allowed a
  WHERE a.from_status IS NOT DISTINCT FROM p.from_status       -- NULL khớp với NULL
    AND a.to_status = p.to_status
);
```

- **Trạng thái bắt đầu là bước chuyển từ NULL**. Dùng `a.from_status = p.from_status` thì `NULL = NULL` ra NULL, nên **mọi sự kiện đầu tiên** đều bị báo sai (A2). `IS NOT DISTINCT FROM` so sánh được cả NULL.
- Không dùng `(from_status, to_status) NOT IN (SELECT from_status, to_status FROM allowed)`: vì `allowed` có dòng `(NULL, 'created')`, mọi so sánh chạm tới NULL đều ra NULL thay vì sai. Kết quả là `NOT IN` **bỏ sót không báo lỗi**: chạy trên dữ liệu đề, nó chỉ tìm được 3 trong 5 bước sai, mất đơn 3 (`NULL → paid`) và đơn 5 (`paid → created`) (E1).
- **So với sự kiện ngay trước, kể cả khi sự kiện đó sai**: đơn 2 (created → shipped → delivered) chỉ sai ở bước created → shipped. Bước shipped → delivered vẫn hợp lệ.
- Sắp theo `event_time`, không theo thứ tự dòng: đơn 4 trong dữ liệu có sự kiện `paid` 10:00 nằm **trước** `created` 09:00.

### 14.3 Biến thể hay gặp

- **Thời gian ở mỗi trạng thái**: `LEAD(event_time) OVER (...) − event_time`, rồi `AVG` theo trạng thái để thấy quy trình hay chậm ở đâu.
- **Trạng thái hiện tại** của mỗi đơn: sự kiện cuối, lấy bằng `DISTINCT ON (order_id) ... ORDER BY order_id, event_time DESC`, hoặc top-1 (5.5).
- **Đơn kẹt**: trạng thái hiện tại không phải trạng thái cuối và đã quá N ngày (kết hợp với 8.2).
- **Ma trận chuyển trạng thái**: `GROUP BY from_status, to_status` đếm số lần mỗi bước chuyển, rồi xoay ngang (3.3).
