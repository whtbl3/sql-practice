# Gaps & Islands (chuỗi liên tiếp)

> Bài liên quan: `islands/01`–`05`, `sessions/01`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** những giá trị nào nằm liền nhau (ngày liên tiếp, tháng liên tiếp, số liên tiếp)? Mỗi đoạn liền nhau như vậy gọi là một **đảo**; chỗ đứt giữa hai đảo là một **khoảng trống**.

**Vì sao khó:** SQL xử lý từng dòng riêng lẻ, không có sẵn khái niệm "dòng này nối tiếp dòng trước". Ta phải tự tạo ra một cột **nhãn đảo**, sao cho các dòng cùng đảo có cùng nhãn, rồi mới `GROUP BY` theo nhãn đó.

Năm bước:

1. Đưa về đơn vị cần xét và bỏ trùng
2. Biến đơn vị thành số liên tục
3. Gắn nhãn đảo
4. Gom mỗi đảo thành một dòng
5. Chọn đảo hoặc khoảng trống cần trả về

Ví dụ chạy xuyên suốt dùng bảng `logins`:

| user_id | login_date |
| --- | --- |
| 1 | 2024-01-01 |
| 1 | 2024-01-02 |
| 1 | 2024-01-03 |
| 1 | 2024-01-05 |
| 2 | 2024-02-28 |
| 2 | 2024-02-29 |
| 2 | 2024-03-01 |
| 2 | 2024-03-01 |
| 3 | 2024-05-05 |
| 3 | 2024-05-05 |

---

## B1. Đưa về đơn vị cần xét và bỏ trùng

- **Vấn đề:** đăng nhập 2 lần trong cùng một ngày vẫn chỉ tính là 1 ngày. Nếu để dòng trùng, B3 sẽ gắn nhãn sai.
- **Tại sao:** nhãn đảo ở B3 dựa trên giả định mỗi đơn vị chỉ có **một dòng**.

```sql
d AS (SELECT DISTINCT user_id, login_date FROM logins)
```

| user_id | login_date |
| --- | --- |
| 1 | 2024-01-01 |
| 1 | 2024-01-02 |
| 1 | 2024-01-03 |
| 1 | 2024-01-05 |
| 2 | 2024-02-28 |
| 2 | 2024-02-29 |
| 2 | 2024-03-01 |
| 3 | 2024-05-05 |

## B2. Biến đơn vị thành số liên tục

- **Vấn đề:** "liền nhau" phải được hiểu là "hơn kém đúng 1".
- **Tại sao:**
  - **Ngày** (`date`): dùng thẳng được. Phép trừ ngày đã tự xử lý cuối tháng và năm nhuận (02-28 → 02-29 → 03-01).
  - **Tháng**: phải đổi thành `năm*12 + tháng`. Nếu chỉ lấy tháng thì 2023-12 → 2024-01 thành `12 → 1`, không liền nhau.

```sql
EXTRACT(YEAR FROM order_date)::int * 12 + EXTRACT(MONTH FROM order_date)::int AS month_idx
```

| customer_id | tháng | month_idx |
| --- | --- | --- |
| 1 | 2023-11 | 24287 |
| 1 | 2023-12 | 24288 |
| 1 | 2024-01 | 24289 |
| 1 | 2024-02 | 24290 |

## B3. Gắn nhãn đảo

- **Vấn đề:** cần một giá trị giống nhau cho mọi dòng trong cùng một đảo.
- **Tại sao `giá trị − ROW_NUMBER` làm được việc đó:**
  - Trong một đảo, giá trị và số thứ tự cùng tăng 1 mỗi dòng, nên hiệu của chúng không đổi.
  - Khi gặp chỗ đứt, giá trị nhảy xa hơn 1 nhưng số thứ tự vẫn chỉ tăng 1, nên hiệu thay đổi. Đó là lúc sang đảo mới.

```sql
g AS (
  SELECT user_id, login_date,
         login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
  FROM d
)
```

| user_id | login_date | rn | grp |
| --- | --- | --- | --- |
| 1 | 2024-01-01 | 1 | 2023-12-31 |
| 1 | 2024-01-02 | 2 | 2023-12-31 |
| 1 | 2024-01-03 | 3 | 2023-12-31 |
| 1 | 2024-01-05 | 4 | **2024-01-01** |
| 2 | 2024-02-28 | 1 | 2024-02-27 |
| 2 | 2024-02-29 | 2 | 2024-02-27 |
| 2 | 2024-03-01 | 3 | 2024-02-27 |
| 3 | 2024-05-05 | 1 | 2024-05-04 |

- Bản thân giá trị `grp` không có ý nghĩa gì; chỉ cần các dòng cùng đảo có cùng `grp`.
- `::int` là bắt buộc. `ROW_NUMBER` trả về `bigint`, còn PostgreSQL không có phép `date - bigint` (báo lỗi `operator does not exist: date - bigint`).
- Phải có `PARTITION BY user_id`, nếu không chuỗi sẽ chạy xuyên qua user khác.
- Nếu quên B1: user 2 có hai dòng 03-01, dòng thứ hai nhận `rn = 4` và `grp = 02-26`, nên bị tách thành một đảo riêng.

**Khi điều kiện đứt không phải "hơn kém 1"** thì dùng `LAG` + `SUM`. Ví dụ: phiên mới khi cách sự kiện trước hơn 30 phút, hoặc doanh thu tháng này thấp hơn tháng trước.
- `LAG` gắn cờ `is_new = 1` cho dòng bắt đầu đảo mới.
- Cộng dồn cờ đó, ta được số thứ tự đảo.

```sql
f AS (
  SELECT user_id, event_time,
         CASE WHEN event_time - LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time)
                   > INTERVAL '30 minutes' THEN 1 ELSE 0 END AS is_new
  FROM events
)
SELECT user_id, event_time, is_new,
       1 + SUM(is_new) OVER (PARTITION BY user_id ORDER BY event_time) AS session_no
FROM f
```

| user_id | event_time | is_new | session_no |
| --- | --- | --- | --- |
| 1 | 2024-01-01 09:00:00 | 0 | 1 |
| 1 | 2024-01-01 09:10:00 | 0 | 1 |
| 1 | 2024-01-01 09:35:00 | 0 | 1 |
| 1 | 2024-01-01 10:30:00 | 1 | 2 |
| 1 | 2024-01-01 10:31:00 | 0 | 2 |
| 2 | 2024-01-01 12:00:00 | 0 | 1 |

Ở dòng đầu, `LAG` là `NULL` nên phép so sánh không ra `true` và rơi vào `ELSE 0`. Vì vậy phải `1 +` để phiên đầu tiên là số 1.

## B4. Gom mỗi đảo thành một dòng

- **Vấn đề:** cần biết mỗi đảo bắt đầu khi nào, kết thúc khi nào và dài bao nhiêu.
- **Tại sao:** các dòng cùng đảo đã có cùng `grp`, nên chỉ cần `GROUP BY user_id, grp`.

```sql
isl AS (
  SELECT user_id, MIN(login_date) AS start_date, MAX(login_date) AS end_date, COUNT(*) AS days
  FROM g
  GROUP BY user_id, grp
)
```

| user_id | start_date | end_date | days |
| --- | --- | --- | --- |
| 1 | 2024-01-01 | 2024-01-03 | 3 |
| 1 | 2024-01-05 | 2024-01-05 | 1 |
| 2 | 2024-02-28 | 2024-03-01 | 3 |
| 3 | 2024-05-05 | 2024-05-05 | 1 |

## B5. Chọn đảo hoặc khoảng trống cần trả về

- **Vấn đề:** mỗi đề hỏi một thứ khác nhau trên cùng bảng đảo ở B4.
- **Tại sao:** đã có mỗi đảo một dòng thì mọi câu hỏi chỉ còn là lọc hoặc tổng hợp thêm một lần nữa.

| Đề hỏi | Làm gì trên `isl` |
| --- | --- |
| Liệt kê mọi đảo | dùng thẳng `isl` |
| Chuỗi dài nhất | `MAX(days) ... GROUP BY user_id` |
| Chuỗi hiện tại | đảo có `end_date` lớn nhất của mỗi user |
| Chuỗi ít nhất N | `HAVING COUNT(*) >= N` ngay ở B4 |
| Khoảng trống | `LEAD(start_date)` của đảo kế tiếp: khoảng trống chạy từ `end_date + 1` đến `next_start - 1` |

Chuỗi dài nhất:

```sql
SELECT user_id, MAX(days) AS longest_streak FROM isl GROUP BY user_id ORDER BY 2 DESC, 1;
```

| user_id | longest_streak |
| --- | --- |
| 1 | 3 |
| 2 | 3 |
| 3 | 1 |

Chuỗi hiện tại. Với user 1, chuỗi hiện tại dài 1 (chỉ ngày 01-05), dù chuỗi dài nhất của user này là 3:

```sql
SELECT user_id, days AS current_streak
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY end_date DESC) AS r FROM isl) x
WHERE r = 1;
```

| user_id | current_streak |
| --- | --- |
| 1 | 1 |
| 2 | 3 |
| 3 | 1 |

**Khoảng trống giữa các số nguyên** (ví dụ số hóa đơn bị thiếu): không cần đi qua B3–B4. Chỉ cần `LEAD` ngay trên từng dòng, chỗ nào số kế tiếp hơn số hiện tại quá 1 là có khoảng trống.

```sql
SELECT no + 1 AS gap_start, next_no - 1 AS gap_end
FROM (SELECT invoice_no AS no, LEAD(invoice_no) OVER (ORDER BY invoice_no) AS next_no FROM invoices) t
WHERE next_no - no > 1;
```

Với các số `1, 2, 3, 7, 8, 10, 15`, kết quả là các khoảng `4–6`, `9–9`, `11–14`.

---

## Tổng kết: query đầy đủ

Ghép B1 → B5 thành một câu (đề hỏi chuỗi dài nhất):

```sql
WITH d AS (                                        -- B1: bỏ trùng
  SELECT DISTINCT user_id, login_date FROM logins
),
g AS (                                             -- B2 + B3: ngày dùng thẳng, gắn nhãn đảo
  SELECT user_id, login_date,
         login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
  FROM d
),
isl AS (                                           -- B4: mỗi đảo một dòng
  SELECT user_id, MIN(login_date) AS start_date, MAX(login_date) AS end_date, COUNT(*) AS days
  FROM g
  GROUP BY user_id, grp
)
SELECT user_id, MAX(days) AS longest_streak        -- B5: chuỗi dài nhất
FROM isl
GROUP BY user_id
ORDER BY longest_streak DESC, user_id;
```

| user_id | longest_streak |
| --- | --- |
| 1 | 3 |
| 2 | 3 |
| 3 | 1 |
