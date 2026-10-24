# Chuỗi trạng thái (state machine)

<style>
.markdown-preview tr:has(.drop) td { background: rgba(191, 97, 106, 0.16) !important; }
</style>

> Bài liên quan: `misc/08`. Output đều chạy thật bằng `check.py`.

## Bài toán

Một đơn hàng phải đi theo quy trình: `created → paid → shipped → delivered`, hoặc dừng ở `paid → cancelled`. Hệ thống ghi lại mỗi lần đơn đổi trạng thái thành một dòng sự kiện. Đề: **tìm các sự kiện đi sai quy trình**, như bỏ qua bước, lặp bước, hay bắt đầu sai chỗ.

Chỗ khó: quy tắc nói về **cặp** sự kiện liền nhau ("sau `paid` thì được `shipped` hoặc `cancelled`"). Nhưng mỗi dòng trong bảng chỉ có một trạng thái, nên không dòng nào chứa sẵn một cặp để so sánh.

## Dữ liệu

`allowed`: mỗi dòng = 1 bước chuyển hợp lệ. `from_status` là `NULL` nghĩa là "sự kiện đầu tiên của đơn".

| from_status | to_status |
| --- | --- |
| NULL | created |
| created | paid |
| paid | shipped |
| shipped | delivered |
| paid | cancelled |

`order_events`: mỗi dòng = 1 lần đơn đổi trạng thái.

| order_id | event_time | status |
| --- | --- | --- |
| 10 | 2024-05-01 09:00 | created |
| 10 | 2024-05-01 09:10 | paid |
| 10 | 2024-05-01 14:00 | shipped |
| 10 | 2024-05-02 10:00 | delivered |
| 11 | 2024-05-01 10:00 | created |
| 11 | 2024-05-01 10:05 | paid |
| 11 | 2024-05-01 12:00 | cancelled |
| 12 | 2024-05-01 11:00 | created |
| 12 | 2024-05-01 15:00 | delivered |
| 13 | 2024-05-02 08:00 | shipped |
| 13 | 2024-05-03 09:00 | delivered |
| 14 | 2024-05-02 09:30 | paid |
| 14 | 2024-05-02 09:00 | created |
| 14 | 2024-05-02 09:31 | paid |

Theo từng đơn: đơn 10 và 11 đi đúng. Đơn 12 **nhảy cóc** từ `created` sang `delivered`. Đơn 13 **bắt đầu** ở `shipped`. Đơn 14 bị ghi `paid` **hai lần**, và dòng `paid 09:30` nằm **trước** dòng `created 09:00` trong bảng.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Biến mỗi sự kiện thành một cặp (từ, đến) | CTE `pairs` | 1 sự kiện, kèm trạng thái trước nó |
| B2 | Giữ cặp không có trong `allowed` | query cuối | **1 sự kiện sai** |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Biến mỗi sự kiện thành một cặp (CTE `pairs`)

**Ý tưởng:** với mỗi sự kiện, lấy thêm trạng thái của **sự kiện ngay trước nó** trong cùng đơn. Hai trạng thái đó tạo thành một cặp (từ, đến) để so với bảng `allowed`. `LAG(status)` lấy trạng thái của dòng trước. Sự kiện đầu tiên của đơn không có dòng trước, nên `from_status` là `NULL`, đúng với cách `allowed` ghi "bắt đầu quy trình".

**Ví dụ nhỏ:** đơn 14, xếp theo thời gian.

| event_time | status | from_status = `LAG(status)` | to_status |
| --- | --- | --- | --- |
| 09:00 | created | NULL | created |
| 09:30 | paid | created | paid |
| 09:31 | paid | paid | paid |

```sql
WITH pairs AS (
  SELECT order_id, event_time,
         LAG(status) OVER (PARTITION BY order_id ORDER BY event_time) AS from_status,
         status AS to_status
  FROM order_events
)
```

> [!CAUTION]
> ❌ **Dựa vào thứ tự dòng trong bảng thay vì `ORDER BY event_time`**
>
> Trong bảng, dòng `paid 09:30` của đơn 14 đứng trước `created 09:00`. Nếu xếp theo thứ tự dòng, đơn 14 sẽ thành `NULL → paid` rồi `paid → created`: hai lỗi giả. Thứ tự dòng trong bảng SQL không được đảm bảo.
>
> → **Sửa:** luôn ghi rõ `ORDER BY event_time` trong `OVER`.

## B2. Giữ cặp không có trong `allowed` (query cuối)

**Ý tưởng:** đây là bài "giữ những dòng **không** khớp với bảng kia" (anti-join), viết bằng `NOT EXISTS`. Cột `from_status` có thể là `NULL`, nên phải so bằng `IS NOT DISTINCT FROM`. Phép này coi hai `NULL` là bằng nhau, khác với `=`.

**Ví dụ nhỏ:**

| order | pair | in `allowed`? |
| --- | --- | --- |
| 10 | NULL → created | yes |
| 12 | created → delivered | **no** (skipped paid, shipped) |
| 13 | NULL → shipped | **no** (wrong start) |
| 14 | paid → paid | **no** (repeated) |
| ... | | |

```sql
SELECT p.order_id, p.event_time, p.from_status, p.to_status
FROM pairs p
WHERE NOT EXISTS (
  SELECT 1 FROM allowed a
  WHERE a.from_status IS NOT DISTINCT FROM p.from_status
    AND a.to_status = p.to_status
)
ORDER BY p.order_id, p.event_time;
```

Mỗi sự kiện chỉ được so với sự kiện ngay trước nó. Đơn 13 sai ở sự kiện đầu (`NULL → shipped`), nhưng bước sau (`shipped → delivered`) vẫn hợp lệ nên không bị báo.

> [!CAUTION]
> ❌ **So bằng `a.from_status = p.from_status`**
>
> `NULL = NULL` không ra `true`. Vì vậy sự kiện đầu tiên của **mọi** đơn đều không khớp dòng `NULL → created` của `allowed`, và bị báo sai. Kết quả ra 7 dòng thay vì 3, gồm cả sự kiện `created` hoàn toàn hợp lệ của đơn 10, 11, 12, 14.
>
> → **Sửa:** `a.from_status IS NOT DISTINCT FROM p.from_status`.
>
> ---
>
> ❌ **Viết `(from_status, to_status) NOT IN (SELECT from_status, to_status FROM allowed)`**
>
> `allowed` có một dòng chứa `NULL`. Khi so cặp `(NULL, shipped)` của đơn 13 với từng dòng của `allowed`, có phép so ra `NULL` thay vì `false`, và `NOT IN` khi gặp `NULL` thì trả về `NULL`, không phải `true`. Đơn 13 bị **bỏ sót** mà không có thông báo gì: kết quả chỉ còn 2 dòng.
>
> → **Sửa:** dùng `NOT EXISTS` với `IS NOT DISTINCT FROM`. Tránh `NOT IN` khi một trong hai phía có thể có `NULL`.

## Tổng kết: query đầy đủ

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

Mọi cặp sau B1:

| order_id | event_time | from_status | to_status |
| --- | --- | --- | --- |
| 10 | 05-01 09:00 | NULL | created |
| 10 | 05-01 09:10 | created | paid |
| 10 | 05-01 14:00 | paid | shipped |
| 10 | 05-02 10:00 | shipped | delivered |
| 11 | 05-01 10:00 | NULL | created |
| 11 | 05-01 10:05 | created | paid |
| 11 | 05-01 12:00 | paid | cancelled |
| 12 | 05-01 11:00 | NULL | created |
| 12 | 05-01 15:00 | created | delivered |
| 13 | 05-02 08:00 | NULL | shipped |
| 13 | 05-03 09:00 | shipped | delivered |
| 14 | 05-02 09:00 | NULL | created |
| 14 | 05-02 09:30 | created | paid |
| 14 | 05-02 09:31 | paid | paid |

Kết quả cuối:

| order_id | event_time | from_status | to_status |
| --- | --- | --- | --- |
| 12 | 2024-05-01 15:00:00 | created | delivered |
| 13 | 2024-05-02 08:00:00 | NULL | shipped |
| 14 | 2024-05-02 09:31:00 | paid | paid |

---

# Phần 2: Biến thể

Cùng dữ liệu sự kiện đó, đề có thể hỏi những câu khác ngoài "đúng hay sai". Mỗi mục dưới đây là một câu hỏi như vậy.

## V1. Khi hỏi đơn hàng hay bị chậm ở bước nào

Đề: **trung bình một đơn nằm ở mỗi trạng thái bao lâu?** Thời gian ở một trạng thái là khoảng từ sự kiện đó tới sự kiện **kế tiếp** của cùng đơn. `LEAD(event_time)` lấy thời điểm của sự kiện kế tiếp:

| order | status | event_time | `LEAD(event_time)` − event_time |
| --- | --- | --- | --- |
| 10 | created | 05-01 09:00 | 0:10:00 |
| 10 | paid | 05-01 09:10 | 4:50:00 |
| 10 | shipped | 05-01 14:00 | 20:00:00 |
| 10 | delivered | 05-02 10:00 | NULL (last event) |
| ... | | | |

Cách viết nghĩ tới đầu tiên là `AVG(LEAD(event_time) OVER (...) - event_time)`. Nhưng PostgreSQL không cho đặt một hàm cửa sổ bên trong một hàm gộp như `AVG`. Phải tính thời gian ở một CTE trước, rồi `AVG` ở tầng ngoài:

```sql
WITH durations AS (
  SELECT order_id, status, event_time,
         LEAD(event_time) OVER (PARTITION BY order_id ORDER BY event_time) - event_time AS time_in_status
  FROM order_events
)
SELECT status, COUNT(time_in_status) AS n, AVG(time_in_status) AS avg_time
FROM durations
GROUP BY status;
```

| status | n | avg_time |
| --- | --- | --- |
| created | 4 | 1:11:15 |
| paid | 3 | 2:15:20 |
| shipped | 2 | 22:30:00 |
| delivered | 0 | NULL |
| cancelled | 0 | NULL |

Đơn hàng nằm lâu nhất ở trạng thái `shipped`, trung bình gần một ngày. Trạng thái cuối của mỗi đơn (`delivered`, `cancelled`) không có sự kiện kế tiếp, nên thời gian là `NULL`, và `AVG` tự bỏ qua.

> [!TIP]
> **Ghi nhớ:** thời gian ở mỗi trạng thái là `LEAD(event_time) − event_time`. Hàm cửa sổ không lồng được trong hàm gộp, nên tính nó ở CTE trước rồi mới `AVG`.

## V2. Khi hỏi trạng thái hiện tại, hoặc ma trận chuyển trạng thái

**Trạng thái hiện tại** của mỗi đơn là trạng thái của sự kiện **cuối cùng**. Đây là bài "mỗi đơn lấy một dòng", và PostgreSQL có cách viết gọn là `DISTINCT ON`: giữ dòng đầu tiên của mỗi `order_id` theo thứ tự `ORDER BY`. Xếp `event_time DESC` thì dòng đầu là sự kiện mới nhất:

```sql
SELECT DISTINCT ON (order_id) order_id, status AS current_status, event_time
FROM order_events
ORDER BY order_id, event_time DESC;
```

| order_id | current_status | event_time |
| --- | --- | --- |
| 10 | delivered | 2024-05-02 10:00:00 |
| 11 | cancelled | 2024-05-01 12:00:00 |
| 12 | delivered | 2024-05-01 15:00:00 |
| 13 | delivered | 2024-05-03 09:00:00 |
| 14 | paid | 2024-05-02 09:31:00 |

`ORDER BY` phải bắt đầu bằng đúng các cột trong `DISTINCT ON`, rồi mới tới cột quyết định dòng nào được giữ.

**Ma trận chuyển trạng thái** đếm mỗi cặp (từ, đến) xuất hiện bao nhiêu lần. Dùng lại `pairs` của B1, rồi `GROUP BY`:

```sql
SELECT COALESCE(from_status, '(start)') AS from_status, to_status, COUNT(*) AS n
FROM pairs
GROUP BY 1, 2
ORDER BY 1, 2;
```

| from_status | to_status | n |
| --- | --- | --- |
| (start) | created | 4 |
| (start) | shipped | 1 |
| created | delivered | 1 |
| created | paid | 3 |
| paid | cancelled | 1 |
| paid | paid | 1 |
| paid | shipped | 1 |
| shipped | delivered | 2 |

`COALESCE(from_status, '(start)')` đổi `NULL` thành một nhãn dễ đọc. Các cặp không có trong `allowed` (ví dụ `created → delivered`) cũng hiện ra ở đây, kèm số lần xảy ra.

> [!TIP]
> **Ghi nhớ:** trạng thái hiện tại thì dùng `DISTINCT ON (id) ... ORDER BY id, time DESC`. Ma trận chuyển trạng thái thì `GROUP BY from_status, to_status` trên các cặp của B1.
