# Gaps & Islands (chuỗi liên tiếp)

> Bài liên quan: `islands/01`–`05`, `sessions/01`. Output đều chạy thật bằng `check.py`.

## Bài toán

Một app muốn biết **chuỗi ngày đăng nhập liên tiếp dài nhất** của mỗi người dùng, kiểu "streak" trong các app học ngoại ngữ.

Mỗi đoạn các ngày nằm liền nhau gọi là một **đảo** (island). Chỗ đứt giữa hai đảo là một **khoảng trống** (gap). Ví dụ một người đăng nhập ngày 1, 2, 3 rồi ngày 6, 7: họ có hai đảo, dài 3 ngày và 2 ngày, ngăn cách bởi khoảng trống ngày 4–5.

Chỗ khó: SQL xử lý từng dòng riêng lẻ, không có sẵn khái niệm "dòng này nối tiếp dòng trước". Ta phải tự tạo ra một cột **nhãn đảo** sao cho mọi dòng trong cùng một đảo có cùng nhãn. Có nhãn rồi thì chỉ cần `GROUP BY` theo nhãn đó.

## Dữ liệu

`logins`: mỗi dòng = 1 lần đăng nhập. Một ngày có thể có nhiều lần.

| user_id | login_date |
| --- | --- |
| 1 (Alice) | 2024-01-01 |
| 1 (Alice) | 2024-01-02 |
| 1 (Alice) | 2024-01-02 |
| 1 (Alice) | 2024-01-03 |
| 1 (Alice) | 2024-01-06 |
| 1 (Alice) | 2024-01-07 |
| 2 (Ben) | 2024-02-27 |
| 2 (Ben) | 2024-02-28 |
| 2 (Ben) | 2024-02-29 |
| 2 (Ben) | 2024-03-01 |
| 2 (Ben) | 2024-03-04 |
| 3 (Chloe) | 2024-03-10 |

Hai chỗ dễ sai: Alice đăng nhập **2 lần ngày 01-02**, và chuỗi của Ben **vắt qua cuối tháng 2 năm nhuận** (02-28 → 02-29 → 03-01).

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Bỏ trùng ngày | CTE `days` | 1 người × 1 ngày có đăng nhập |
| B2 | Gắn nhãn đảo | CTE `labeled` | như trên, thêm cột `grp` |
| B3 | Gom mỗi đảo thành một dòng | CTE `islands` | **1 đảo** |
| B4 | Chọn chuỗi dài nhất | query cuối | **1 người** |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Bỏ trùng ngày (CTE `days`)

**Ý tưởng:** đăng nhập 2 lần trong một ngày vẫn chỉ là **một ngày**. Cách gắn nhãn ở B2 dựa trên giả định mỗi ngày chỉ có đúng một dòng, nên phải bỏ trùng trước.

**Ví dụ nhỏ:**

| user | login_date | reason |
| --- | --- | --- |
| Alice | 2024-01-01 | kept |
| Alice | 2024-01-02 | kept |
| Alice | 2024-01-02 | <span class="drop">same day, merged</span> |
| Alice | 2024-01-03 | kept |
| ... | | |

```sql
WITH days AS (
  SELECT DISTINCT user_id, login_date
  FROM logins
)
```

## B2. Gắn nhãn đảo (CTE `labeled`)

**Ý tưởng:** đánh số thứ tự các ngày của mỗi người (1, 2, 3, ...), rồi lấy **ngày trừ số thứ tự**. Trong một đảo, ngày tăng 1 và số thứ tự cũng tăng 1, nên hiệu không đổi. Khi gặp chỗ đứt, ngày nhảy xa hơn 1 nhưng số thứ tự vẫn chỉ tăng 1, nên hiệu thay đổi. Hiệu đó chính là nhãn đảo.

**Ví dụ nhỏ:** Alice.

| login_date | rn | grp = login_date − rn |
| --- | --- | --- |
| 2024-01-01 | 1 | 2023-12-31 |
| 2024-01-02 | 2 | 2023-12-31 |
| 2024-01-03 | 3 | 2023-12-31 |
| 2024-01-06 | 4 | **2024-01-02** (jump: 01-04, 01-05 missing) |
| 2024-01-07 | 5 | 2024-01-02 |

Ba ngày đầu cùng nhãn 2023-12-31, hai ngày sau cùng nhãn 2024-01-02: đúng hai đảo. Bản thân giá trị `grp` không có ý nghĩa gì. Chỉ cần các dòng cùng đảo có cùng `grp`.

Với Ben, phép trừ ngày tự hiểu tháng 2 năm 2024 có 29 ngày: 02-27, 02-28, 02-29, 03-01 đều cho cùng `grp` là 2024-02-26.

```sql
labeled AS (
  SELECT user_id, login_date,
         login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
  FROM days
)
```

`::int` là bắt buộc. `ROW_NUMBER` trả về kiểu `bigint`, mà PostgreSQL không có phép `date - bigint` (báo lỗi `operator does not exist: date - bigint`).

> [!CAUTION]
> ❌ **Quên bỏ trùng ở B1**
>
> Alice có 2 dòng ngày 01-02. Dòng thứ hai nhận số thứ tự 3, nên `grp` = 01-02 − 3 = 2023-12-30, khác nhãn của ngày 01-01. Chuỗi 3 ngày của Alice bị cắt đôi thành hai đảo, mỗi đảo 2 dòng, và chuỗi dài nhất ra 2 thay vì 3.
>
> → **Sửa:** `SELECT DISTINCT` ở B1, để mỗi ngày đúng một dòng.
>
> ---
>
> ❌ **Quên `PARTITION BY user_id`**
>
> Số thứ tự chạy liên tục qua mọi người. Ngày đầu của Ben nhận số thứ tự 6, nối tiếp Alice, và các nhãn không còn khớp với đảo thật của từng người.
>
> → **Sửa:** `PARTITION BY user_id`, để mỗi người đánh số lại từ 1.

## B3. Gom mỗi đảo thành một dòng (CTE `islands`)

**Ý tưởng:** các dòng cùng đảo đã có cùng `grp`, nên `GROUP BY user_id, grp` gom mỗi đảo thành một dòng: ngày bắt đầu, ngày kết thúc, và số ngày.

**Ví dụ nhỏ:**

| user | grp | days in island | start_date | end_date | days |
| --- | --- | --- | --- | --- | --- |
| Alice | 2023-12-31 | 01-01, 01-02, 01-03 | 2024-01-01 | 2024-01-03 | 3 |
| Alice | 2024-01-02 | 01-06, 01-07 | 2024-01-06 | 2024-01-07 | 2 |
| ... | | | | | |

```sql
islands AS (
  SELECT user_id, MIN(login_date) AS start_date, MAX(login_date) AS end_date, COUNT(*) AS days
  FROM labeled
  GROUP BY user_id, grp
)
```

Đến đây ta đã có danh sách mọi đảo. Nếu đề chỉ hỏi "liệt kê mọi chuỗi liên tiếp", đây đã là đáp án.

## B4. Chọn chuỗi dài nhất (query cuối)

**Ý tưởng:** mỗi người có thể có nhiều đảo. Chuỗi dài nhất là đảo có `days` lớn nhất.

```sql
SELECT user_id, MAX(days) AS longest_streak
FROM islands
GROUP BY user_id
ORDER BY longest_streak DESC, user_id;
```

| user | islands (days) | longest_streak |
| --- | --- | --- |
| Alice | 3, 2 | 3 |
| Ben | 4, 1 | 4 |
| ... | | |

## Tổng kết: query đầy đủ

```sql
WITH days AS (                                     -- B1: bỏ trùng ngày
  SELECT DISTINCT user_id, login_date
  FROM logins
),
labeled AS (                                       -- B2: nhãn đảo = ngày − số thứ tự
  SELECT user_id, login_date,
         login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
  FROM days
),
islands AS (                                       -- B3: mỗi đảo một dòng
  SELECT user_id, MIN(login_date) AS start_date, MAX(login_date) AS end_date, COUNT(*) AS days
  FROM labeled
  GROUP BY user_id, grp
)
SELECT user_id, MAX(days) AS longest_streak        -- B4: chuỗi dài nhất
FROM islands
GROUP BY user_id
ORDER BY longest_streak DESC, user_id;
```

Mọi đảo sau B3:

| user_id | start_date | end_date | days |
| --- | --- | --- | --- |
| 1 | 2024-01-01 | 2024-01-03 | 3 |
| 1 | 2024-01-06 | 2024-01-07 | 2 |
| 2 | 2024-02-27 | 2024-03-01 | 4 |
| 2 | 2024-03-04 | 2024-03-04 | 1 |
| 3 | 2024-03-10 | 2024-03-10 | 1 |

Kết quả cuối:

| user_id | longest_streak |
| --- | --- |
| 2 | 4 |
| 1 | 3 |
| 3 | 1 |

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính: đơn vị là tháng thay vì ngày, hỏi chuỗi hiện tại thay vì chuỗi dài nhất, hỏi chỗ trống thay vì chuỗi, hoặc "liền nhau" được định nghĩa bằng khoảng thời gian. Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi đơn vị là tháng

Đề: **mỗi khách có chuỗi tháng liên tiếp có mua hàng dài nhất là bao nhiêu?** Dữ liệu là đơn hàng:

```text
orders (order_id, customer_id, order_date)   -- mới
```

| customer | order_date |
| --- | --- |
| Alice | 2023-11-20 |
| Alice | 2023-12-05 |
| Alice | 2024-01-08 |
| Alice | 2024-01-25 |
| Alice | 2024-03-14 |
| Ben | 2024-02-10 |

Alice mua liên tiếp tháng 11, 12/2023 và tháng 1/2024 (vắt qua năm mới), rồi bỏ tháng 2 và mua lại tháng 3. Chuỗi dài nhất là 3 tháng.

### Thử cách tự nhiên nhất

Với ngày, ta lấy `ngày − số thứ tự`. Với tháng, cách nghĩ nhanh là lấy số tháng (`EXTRACT(MONTH ...)`) trừ số thứ tự:

| month | `EXTRACT(MONTH)` | rn | grp |
| --- | --- | --- | --- |
| 2023-11 | 11 | 1 | 10 |
| 2023-12 | 12 | 2 | 10 |
| 2024-01 | **1** | 3 | **−2** |
| 2024-03 | 3 | 4 | −1 |

Tháng 1/2024 rơi ra một nhãn riêng, nên chuỗi dài nhất ra 2 thay vì 3. Lý do là số tháng quay về 1 khi sang năm mới, nên với cách đếm này, tháng 12 và tháng 1 không liền nhau.

### Cách sửa: đổi tháng thành một con số đếm liên tục

Đổi mỗi tháng thành `năm × 12 + tháng`. Con số này tăng đúng 1 mỗi tháng, kể cả khi sang năm mới: 2023-12 là 24288, 2024-01 là 24289. Phần còn lại giống hệt mạch chính:

```sql
WITH months AS (
  SELECT DISTINCT customer_id,
         EXTRACT(YEAR FROM order_date)::int * 12 + EXTRACT(MONTH FROM order_date)::int AS month_idx
  FROM orders
),
labeled AS (
  SELECT customer_id, month_idx,
         month_idx - ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month_idx) AS grp
  FROM months
),
islands AS (
  SELECT customer_id, COUNT(*) AS months
  FROM labeled
  GROUP BY customer_id, grp
)
SELECT customer_id, MAX(months) AS longest_streak
FROM islands
GROUP BY customer_id
ORDER BY longest_streak DESC, customer_id;
```

| month | month_idx | rn | grp |
| --- | --- | --- | --- |
| 2023-11 | 24287 | 1 | 24286 |
| 2023-12 | 24288 | 2 | 24286 |
| 2024-01 | 24289 | 3 | 24286 |
| 2024-03 | 24291 | 4 | 24287 |

| customer_id | longest_streak |
| --- | --- |
| 1 | 3 |
| 2 | 1 |

`DISTINCT` trong `months` cũng làm luôn việc bỏ trùng của B1: Alice có 2 đơn trong tháng 1, chỉ còn một dòng 24289. `month_idx` là số nguyên, nên trừ thẳng `ROW_NUMBER` được, không cần `::int` như với ngày.

> [!TIP]
> **Ghi nhớ:** đơn vị không phải ngày thì đổi nó thành một số nguyên tăng đúng 1 mỗi đơn vị (tháng: `năm × 12 + tháng`), rồi dùng lại công thức `giá trị − ROW_NUMBER`.

## V2. Khi hỏi chuỗi hiện tại

Đề: **chuỗi hiện tại của mỗi người dài bao nhiêu?** "Chuỗi hiện tại" là đảo kết thúc ở lần đăng nhập **gần nhất** của người đó, không phải đảo dài nhất.

Alice có hai đảo: 01-01 → 01-03 (3 ngày) và 01-06 → 01-07 (2 ngày). Lần đăng nhập gần nhất là 01-07, nên chuỗi hiện tại là 2, dù chuỗi dài nhất là 3. Nếu viết `MAX(days)` như B4, ta sẽ trả về 3, tức là trả lời sai câu hỏi.

Câu hỏi đúng là: trong các đảo của mỗi người, **đảo nào có `end_date` muộn nhất?** Đây là bài "mỗi người lấy một dòng tốt nhất". Đánh số các đảo theo `end_date` giảm dần, rồi giữ dòng số 1:

```sql
-- days, labeled, islands: giữ nguyên như Phần 1
SELECT user_id, days AS current_streak
FROM (
  SELECT user_id, days,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY end_date DESC) AS r
  FROM islands
) x
WHERE r = 1
ORDER BY user_id;
```

| user | start_date | end_date | days | r |
| --- | --- | --- | --- | --- |
| Alice | 2024-01-06 | 2024-01-07 | 2 | **1** |
| Alice | 2024-01-01 | 2024-01-03 | 3 | 2 |
| Ben | 2024-03-04 | 2024-03-04 | 1 | **1** |
| Ben | 2024-02-27 | 2024-03-01 | 4 | 2 |
| Chloe | 2024-03-10 | 2024-03-10 | 1 | **1** |

| user_id | current_streak |
| --- | --- |
| 1 | 2 |
| 2 | 1 |
| 3 | 1 |

Ben có chuỗi dài nhất là 4 ngày, nhưng chuỗi hiện tại chỉ 1 ngày, vì Ben đã đứt chuỗi sau 03-01. Bộ lọc `r = 1` phải đặt ở tầng ngoài, vì hàm cửa sổ không dùng được trong `WHERE` của cùng tầng `SELECT`.

> [!TIP]
> **Ghi nhớ:** chuỗi dài nhất là `MAX(days)`. Chuỗi hiện tại là đảo có `end_date` lớn nhất: dùng `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY end_date DESC)` rồi lấy `r = 1`.

## V3. Khi hỏi các khoảng trống

Đề không hỏi chuỗi mà hỏi **chỗ thiếu**: số hóa đơn phải liên tục, hãy liệt kê mọi đoạn số bị thiếu nằm giữa số nhỏ nhất và số lớn nhất.

```text
invoices (invoice_no)   -- mới
```

Các số hiện có: 101, 102, 103, 106, 107, 110. Đáp án mong đợi: thiếu 104–105 và 108–109.

Bài này không cần đi qua các bước gắn nhãn đảo. Một khoảng trống nằm ngay giữa **hai số liền nhau trong danh sách**. Nếu số kế tiếp lớn hơn số hiện tại quá 1, thì các số ở giữa bị thiếu. `LEAD(invoice_no)` đặt số kế tiếp lên cùng dòng:

| invoice_no | `LEAD(invoice_no)` | next − current | missing |
| --- | --- | --- | --- |
| 101 | 102 | 1 | |
| 102 | 103 | 1 | |
| 103 | 106 | **3** | 104 – 105 |
| 106 | 107 | 1 | |
| 107 | 110 | **3** | 108 – 109 |
| 110 | NULL | NULL | (last number) |

Khoảng trống bắt đầu ở số hiện tại + 1 và kết thúc ở số kế tiếp − 1:

```sql
SELECT invoice_no + 1 AS gap_start, next_no - 1 AS gap_end
FROM (
  SELECT invoice_no, LEAD(invoice_no) OVER (ORDER BY invoice_no) AS next_no
  FROM invoices
) t
WHERE next_no - invoice_no > 1
ORDER BY gap_start;
```

| gap_start | gap_end |
| --- | --- |
| 104 | 105 |
| 108 | 109 |

Ở số lớn nhất (110), `next_no` là `NULL`, nên `next_no − invoice_no > 1` không ra `true` và dòng tự bị loại. Đó cũng là lý do đáp án chỉ xét các số nằm **giữa** số nhỏ nhất và số lớn nhất.

> [!TIP]
> **Ghi nhớ:** tìm chỗ thiếu thì không cần gắn nhãn đảo. `LEAD` lấy giá trị kế tiếp, chỗ nào chênh quá 1 là có khoảng trống từ `current + 1` đến `next − 1`.

## V4. Khi "liền nhau" được định nghĩa bằng khoảng thời gian

Đề: **chia các sự kiện của mỗi người thành phiên làm việc (session).** Một phiên mới bắt đầu khi sự kiện cách sự kiện trước của cùng người **hơn 30 phút**. Trả về mỗi phiên: bắt đầu, kết thúc, số sự kiện.

```text
events (user_id, event_time)   -- mới
```

| user | event_time |
| --- | --- |
| Alice | 08:00 |
| Alice | 08:20 |
| Alice | 08:45 |
| Alice | 09:30 |
| Alice | 09:31 |
| Ben | 14:00 |
| Ben | 14:30 |

Công thức `giá trị − ROW_NUMBER` không dùng được ở đây. Nó chỉ đúng khi "liền nhau" nghĩa là "hơn kém đúng 1 đơn vị". Ở đây hai sự kiện cách nhau 20 phút hay 25 phút đều là liền nhau.

### Cách làm: đánh dấu điểm bắt đầu phiên, rồi cộng dồn

Làm hai bước:
1. Với mỗi sự kiện, so với sự kiện trước bằng `LAG`. Cách hơn 30 phút thì gắn cờ `is_new = 1`: đây là sự kiện mở đầu một phiên mới.
2. Cộng dồn cờ đó theo thời gian. Mỗi lần gặp cờ 1, tổng tăng thêm 1, nên tổng cộng dồn chính là số thứ tự của phiên.

```sql
WITH flagged AS (
  SELECT user_id, event_time,
         CASE WHEN event_time - LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time)
                   > INTERVAL '30 minutes' THEN 1 ELSE 0 END AS is_new
  FROM events
),
numbered AS (
  SELECT user_id, event_time,
         1 + SUM(is_new) OVER (PARTITION BY user_id ORDER BY event_time) AS session_no
  FROM flagged
)
SELECT user_id, session_no, MIN(event_time) AS session_start, MAX(event_time) AS session_end, COUNT(*) AS events
FROM numbered
GROUP BY user_id, session_no
ORDER BY user_id, session_no;
```

| user | event_time | since previous | is_new | session_no |
| --- | --- | --- | --- | --- |
| Alice | 08:00 | NULL | 0 | 1 |
| Alice | 08:20 | 20 min | 0 | 1 |
| Alice | 08:45 | 25 min | 0 | 1 |
| Alice | 09:30 | **45 min** | **1** | 2 |
| Alice | 09:31 | 1 min | 0 | 2 |
| Ben | 14:00 | NULL | 0 | 1 |
| Ben | 14:30 | 30 min | 0 | 1 |

| user_id | session_no | session_start | session_end | events |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-01 08:00:00 | 2024-01-01 08:45:00 | 3 |
| 1 | 2 | 2024-01-01 09:30:00 | 2024-01-01 09:31:00 | 2 |
| 2 | 1 | 2024-01-01 14:00:00 | 2024-01-01 14:30:00 | 2 |

Hai điểm cần để ý:
- Ben có hai sự kiện cách nhau **đúng** 30 phút. Đề nói "hơn 30 phút" mới là phiên mới, nên dùng `>` chứ không phải `>=`, và Ben chỉ có một phiên.
- Ở sự kiện đầu tiên của mỗi người, `LAG` là `NULL`. Phép so sánh không ra `true`, nên rơi vào `ELSE 0`. Vì vậy tổng cộng dồn bắt đầu từ 0, và phải cộng thêm `1 +` để phiên đầu tiên mang số 1. Thiếu `1 +` thì các phiên đánh số 0, 1, 2...

Đây cũng là cách nhãn đảo được tạo ra trong mạch chính, chỉ là theo một đường khác: thay vì tìm một hiệu số không đổi trong đảo, ta đánh dấu chỗ bắt đầu mỗi đảo rồi đếm.

> [!TIP]
> **Ghi nhớ:** khi "liền nhau" không phải "hơn kém đúng 1", hãy gắn cờ điểm bắt đầu bằng `LAG` + `CASE`, rồi `1 + SUM(cờ) OVER (... ORDER BY ...)` để ra số thứ tự đảo.
