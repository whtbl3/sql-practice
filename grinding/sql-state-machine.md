# Chuỗi trạng thái (state machine)

> Bài liên quan: `misc/08`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** dữ liệu sự kiện có đi đúng quy trình không? Ví dụ đơn hàng phải đi `created → paid → shipped → delivered`. Bước nào bị bỏ qua, bị lặp lại, hoặc bị đi ngược?

**Vì sao khó:** quy tắc nói về **cặp** sự kiện liền nhau ("sau `paid` thì phải là `shipped`"). Nhưng mỗi dòng trong bảng chỉ có một trạng thái, nên không có dòng nào chứa sẵn một cặp để so sánh.

Ba bước:

1. Biến mỗi sự kiện thành một cặp (từ, đến)
2. So cặp với bảng bước hợp lệ
3. Tổng hợp thêm (nếu đề hỏi)

Ví dụ chạy xuyên suốt:

`allowed`:

| from_status | to_status |
| --- | --- |
| NULL | created |
| created | paid |
| paid | shipped |
| shipped | delivered |

`order_events`: 5 đơn hàng. Đơn 4 có dòng `paid 10:00` nằm **trước** dòng `created 09:00` trong bảng.

---

## B1. Biến mỗi sự kiện thành một cặp (từ, đến)

- **Vấn đề:** mỗi dòng cần biết trạng thái ngay trước nó.
- **Tại sao:**
  - `LAG(status)` lấy trạng thái của dòng trước.
  - Phải sắp theo `event_time` trong `OVER`, không dựa vào thứ tự dòng trong bảng.
  - Sự kiện đầu tiên của mỗi đơn không có dòng trước, nên `from_status` là `NULL`. Ý nghĩa của nó là "bắt đầu quy trình".

```sql
pairs AS (
  SELECT order_id, event_time,
         LAG(status) OVER (PARTITION BY order_id ORDER BY event_time) AS from_status,
         status AS to_status
  FROM order_events
)
```

| order_id | event_time | from_status | to_status |
| --- | --- | --- | --- |
| 1 | 05-01 08:00 | NULL | created |
| 1 | 05-01 08:05 | created | paid |
| 1 | 05-01 10:00 | paid | shipped |
| 1 | 05-02 09:00 | shipped | delivered |
| 2 | 05-01 09:00 | NULL | created |
| 2 | 05-01 11:00 | created | shipped |
| 2 | 05-03 15:00 | shipped | delivered |
| 3 | 05-02 07:00 | NULL | paid |
| 3 | 05-02 08:00 | paid | shipped |
| 4 | 05-02 09:00 | NULL | created |
| 4 | 05-02 10:00 | created | paid |
| 4 | 05-02 10:01 | paid | paid |
| 4 | 05-04 12:00 | paid | delivered |
| 5 | 05-03 08:00 | NULL | created |
| 5 | 05-03 08:10 | created | paid |
| 5 | 05-03 08:20 | paid | created |

## B2. So cặp với bảng bước hợp lệ

- **Vấn đề:** cần giữ lại những cặp **không có** trong bảng `allowed`.
- **Tại sao:** đây là anti-join (`NOT EXISTS`), nhưng cột `from_status` có `NULL`, nên cách so sánh rất quan trọng:
  - `a.from_status = p.from_status`: `NULL = NULL` không ra `true`, nên **mọi sự kiện đầu tiên** đều bị báo sai. Chạy thử ra 9 dòng thay vì 5.
  - `(from, to) NOT IN (SELECT ...)`: `allowed` có dòng chứa `NULL`, nên nhiều phép so sánh ra `NULL` thay vì `false`, và bỏ sót lỗi mà không báo gì. Chạy thử chỉ ra 3 dòng, mất đơn 3 (`NULL → paid`) và đơn 5 (`paid → created`).
  - `IS NOT DISTINCT FROM` coi hai `NULL` là bằng nhau, nên cho kết quả đúng.

```sql
SELECT p.*
FROM pairs p
WHERE NOT EXISTS (
  SELECT 1 FROM allowed a
  WHERE a.from_status IS NOT DISTINCT FROM p.from_status
    AND a.to_status = p.to_status
);
```

| order_id | event_time | from_status | to_status |
| --- | --- | --- | --- |
| 2 | 05-01 11:00 | created | shipped |
| 3 | 05-02 07:00 | NULL | paid |
| 4 | 05-02 10:01 | paid | paid |
| 4 | 05-04 12:00 | paid | delivered |
| 5 | 05-03 08:20 | paid | created |

Mỗi sự kiện được so với sự kiện ngay trước nó, kể cả khi sự kiện trước đã sai. Ví dụ đơn 2 chỉ sai ở bước `created → shipped`, còn bước `shipped → delivered` vẫn hợp lệ.

## B3. Tổng hợp thêm

- **Vấn đề:** ngoài câu hỏi đúng hay sai, đề có thể hỏi quy trình hay bị chậm ở bước nào.
- **Tại sao:** `LEAD(event_time) - event_time` là thời gian một đơn nằm ở trạng thái đó, cho tới khi có sự kiện kế tiếp. Lấy trung bình theo trạng thái là ra bước chậm.

```sql
SELECT status, AVG(LEAD(event_time) OVER (PARTITION BY order_id ORDER BY event_time) - event_time) ...
-- window function không lồng được trong AVG: tính ở CTE trước, AVG ở tầng ngoài
```

| status | avg_time |
| --- | --- |
| created | 0:48:45 |
| paid | 10:37:00 |
| shipped | 1 day, 13:30:00 |

Một số câu hỏi khác dùng cùng bảng `pairs`:
- **Trạng thái hiện tại** của mỗi đơn: lấy sự kiện cuối, bằng `DISTINCT ON (order_id) ... ORDER BY order_id, event_time DESC`.
- **Ma trận chuyển trạng thái:** `GROUP BY from_status, to_status`, rồi `COUNT(*)`.

---

## Tổng kết: query đầy đủ

Ghép B1 → B2 thành một câu:

```sql
WITH pairs AS (                                    -- B1: mỗi sự kiện thành cặp (từ, đến)
  SELECT order_id, event_time,
         LAG(status) OVER (PARTITION BY order_id ORDER BY event_time) AS from_status,
         status AS to_status
  FROM order_events
)
SELECT p.order_id, p.event_time, p.from_status, p.to_status   -- B2: cặp không có trong allowed
FROM pairs p
WHERE NOT EXISTS (
  SELECT 1 FROM allowed a
  WHERE a.from_status IS NOT DISTINCT FROM p.from_status
    AND a.to_status = p.to_status
)
ORDER BY p.order_id, p.event_time;
```

| order_id | event_time | from_status | to_status |
| --- | --- | --- | --- |
| 2 | 2024-05-01 11:00:00 | created | shipped |
| 3 | 2024-05-02 07:00:00 | NULL | paid |
| 4 | 2024-05-02 10:01:00 | paid | paid |
| 4 | 2024-05-04 12:00:00 | paid | delivered |
| 5 | 2024-05-03 08:20:00 | paid | created |
