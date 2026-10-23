# Khoảng thời gian (intervals) và as-of

> Bài liên quan: `intervals/01`–`04`, `misc/07`. Output đều chạy thật bằng `check.py`. Mỗi bước dùng dữ liệu của bài tương ứng.

**Câu hỏi của chủ đề:** dữ liệu có ngày bắt đầu và ngày kết thúc (đặt phòng, hợp đồng, sự cố, phiên xem) hoặc có ngày bắt đầu hiệu lực (bảng giá). Các câu hỏi thường gặp:
- Có trùng lịch không?
- Chia doanh thu theo năm thế nào?
- Gộp lại thành bao nhiêu đợt?
- Lúc đông nhất có bao nhiêu người?
- Giá tại ngày X là bao nhiêu?

**Vì sao khó:** mỗi dòng là một **đoạn** trên trục thời gian, không phải một điểm. Các phép so sánh quen thuộc (`=`, `GROUP BY` theo ngày) không dùng thẳng được, và chỉ cần sai ở biên (`<` hay `<=`) là kết quả sai.

Năm bước, đi từ một khoảng đơn lẻ đến nhiều khoảng:

1. Chốt kiểu khoảng
2. So hai khoảng: có chồng nhau không, phần giao là gì
3. Cắt khoảng theo kỳ
4. Gộp các khoảng chồng nhau
5. Đếm số khoảng đang mở cùng lúc

---

## B1. Chốt kiểu khoảng

- **Vấn đề:** ngày kết thúc có được tính vào khoảng hay không? Ví dụ khách trả phòng ngày 05 thì đêm 05 đã thuộc về khách sau.
- **Tại sao:** mọi công thức ở các bước sau đều phụ thuộc vào câu trả lời này.

| Kiểu | Ví dụ | Chồng nhau khi | Độ dài |
| --- | --- | --- | --- |
| Nửa mở `[start, end)` | đặt phòng, phiên xem, thuê bao | `a.start < b.end AND b.start < a.end` | `end - start` |
| Đóng `[start, end]` | hợp đồng, sự cố tính theo ngày | `a.start <= b.end AND b.start <= a.end` | `end - start + 1` |

Vì sao công thức chồng nhau chỉ có hai vế: hai khoảng **không** chồng nhau khi một khoảng kết thúc trước khi khoảng kia bắt đầu. Phủ định điều đó là ra công thức trên. Không cần liệt kê các trường hợp "A chứa B", "lệch trái", "lệch phải".

**Khi bảng chỉ có ngày bắt đầu hiệu lực** (bảng giá):
- Tự tạo khoảng bằng `LEAD`: khoảng của một mức giá kết thúc ở ngày bắt đầu của mức giá kế tiếp.
- `valid_to` là `NULL` nghĩa là mức giá đang có hiệu lực.

```sql
SELECT product_id, price_vnd, valid_from,
       LEAD(valid_from) OVER (PARTITION BY product_id ORDER BY valid_from) AS valid_to
FROM price_history
```

| product_id | price_vnd | valid_from | valid_to |
| --- | --- | --- | --- |
| 1 | 50000 | 2024-01-01 | 2024-03-01 |
| 1 | 55000 | 2024-03-01 | 2024-06-15 |
| 1 | 60000 | 2024-06-15 | NULL |
| 2 | 30000 | 2024-02-01 | NULL |

## B2. So hai khoảng: có chồng nhau không, phần giao là gì

- **Vấn đề:** tìm các cặp đặt phòng trùng nhau trong cùng một phòng.
- **Tại sao:**
  - Self-join bảng với chính nó, điều kiện nối là công thức chồng nhau ở B1.
  - Dùng `a.id < b.id` thay vì `<>`. Dùng `<>` thì mỗi cặp ra hai lần (A-B và B-A).
  - Phần giao bắt đầu ở ngày bắt đầu **muộn hơn** (`GREATEST`) và kết thúc ở ngày kết thúc **sớm hơn** (`LEAST`).

```sql
SELECT a.room, a.booking_id AS booking_a, b.booking_id AS booking_b,
       GREATEST(a.check_in, b.check_in) AS overlap_start,
       LEAST(a.check_out, b.check_out)  AS overlap_end,
       LEAST(a.check_out, b.check_out) - GREATEST(a.check_in, b.check_in) AS overlap_nights
FROM bookings a
JOIN bookings b
  ON b.room = a.room AND a.booking_id < b.booking_id
 AND a.check_in < b.check_out AND b.check_in < a.check_out
```

| room | booking_a | booking_b | overlap_start | overlap_end | overlap_nights |
| --- | --- | --- | --- | --- | --- |
| 101 | 1 | 3 | 2024-06-04 | 2024-06-05 | 1 |
| 101 | 2 | 3 | 2024-06-05 | 2024-06-06 | 1 |
| 102 | 4 | 5 | 2024-06-03 | 2024-06-04 | 1 |
| 102 | 4 | 6 | 2024-06-09 | 2024-06-10 | 1 |

Nếu viết `<=` (coi như khoảng đóng), sẽ xuất hiện thêm cặp `101 | 1 | 2`. Booking 1 trả phòng ngày 06-05 đúng lúc booking 2 nhận phòng, nên đây là trùng giả.

**Khi so một điểm với một khoảng** (as-of: giá tại ngày đặt hàng):
- Điều kiện là `ngày >= valid_from AND (valid_to IS NULL OR ngày < valid_to)`.
- Dùng `LEFT JOIN` để giữ đơn đặt trước khi có giá (giá ra `NULL`).
- Điều kiện nối phải có cả `product_id`, nếu không giá của sản phẩm khác sẽ lọt vào.

```sql
LEFT JOIN ranges r
       ON r.product_id = o.product_id
      AND o.order_date >= r.valid_from
      AND (r.valid_to IS NULL OR o.order_date < r.valid_to)
```

| order_id | product_id | order_date | unit_price |
| --- | --- | --- | --- |
| 1 | 1 | 2024-01-15 | 50000 |
| 2 | 1 | 2024-03-01 | 55000 |
| 2 | 2 | 2024-03-01 | 30000 |
| 3 | 1 | 2024-06-14 | 55000 |
| 4 | 1 | 2024-06-15 | 60000 |
| 5 | 2 | 2024-01-20 | NULL |

Cách khác, không cần tạo khoảng trước: `LEFT JOIN LATERAL (... WHERE valid_from <= o.order_date ORDER BY valid_from DESC LIMIT 1) p ON TRUE`.

## B3. Cắt khoảng theo kỳ

- **Vấn đề:** một hợp đồng kéo dài qua nhiều năm. Cần chia giá trị hợp đồng cho từng năm theo số ngày.
- **Tại sao:**
  - Sinh các năm mà khoảng chạm vào bằng `LATERAL generate_series`, để mỗi hợp đồng có một dòng cho mỗi năm.
  - Mỗi phần là **phần giao** giữa hợp đồng và năm đó, tính bằng `GREATEST` và `LEAST` như B2.
  - Nhân trước, chia sau, và ép `::numeric`, để không bị chia số nguyên.

```sql
SELECT c.contract_id, y.yr AS year,
       GREATEST(c.start_date, make_date(y.yr, 1, 1)) AS part_start,
       LEAST(c.end_date, make_date(y.yr, 12, 31))    AS part_end,
       LEAST(c.end_date, make_date(y.yr, 12, 31)) - GREATEST(c.start_date, make_date(y.yr, 1, 1)) + 1 AS days,
       ROUND(c.value_vnd::numeric * <days> / (c.end_date - c.start_date + 1)) AS allocated_vnd
FROM contracts c
CROSS JOIN LATERAL generate_series(EXTRACT(YEAR FROM c.start_date)::int,
                                   EXTRACT(YEAR FROM c.end_date)::int) AS y(yr)
```

| contract_id | year | part_start | part_end | days | allocated_vnd |
| --- | --- | --- | --- | --- | --- |
| 1 | 2023 | 2023-07-01 | 2023-12-31 | 184 | 18400000 |
| 1 | 2024 | 2024-01-01 | 2024-06-30 | 182 | 18200000 |
| 4 | 2024 | 2024-12-30 | 2024-12-31 | 2 | 666667 |
| 4 | 2025 | 2025-01-01 | 2025-01-01 | 1 | 333333 |

- Hợp đồng 4: 666667 + 333333 = 1.000.000, khớp giá trị hợp đồng. Nhưng làm tròn từng phần có thể khiến tổng lệch 1 đồng. Nếu đề yêu cầu tổng khớp tuyệt đối, dồn phần chênh lệch vào kỳ cuối.
- Muốn cắt theo tháng thì làm y hệt, với biên tháng là `m` và `(m + INTERVAL '1 month')::date - 1`.

## B4. Gộp các khoảng chồng nhau

- **Vấn đề:** nhiều sự cố chồng lên nhau hoặc nối tiếp nhau cần được gộp thành một đợt.
- **Tại sao:**
  - Đây là Gaps & Islands áp cho khoảng: sắp xếp theo ngày bắt đầu, gắn cờ khi bắt đầu một đợt mới, rồi cộng dồn cờ để ra số thứ tự đợt.
  - Một khoảng mở đợt mới khi nó bắt đầu **sau điểm kết thúc xa nhất của mọi khoảng trước nó**, chứ không phải sau điểm kết thúc của dòng ngay trước.

```sql
CASE WHEN start_date <= MAX(end_date) OVER (PARTITION BY server ORDER BY start_date, end_date
                                            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) + 1
     THEN 0 ELSE 1 END AS is_new        -- + 1: liền kề cũng gộp
```

| server | start_date | end_date | prev_end | max_prev_end | is_new |
| --- | --- | --- | --- | --- | --- |
| db-01 | 2024-01-01 | 2024-01-31 | NULL | NULL | 1 |
| db-01 | 2024-01-05 | 2024-01-07 | 2024-01-31 | 2024-01-31 | 0 |
| db-01 | 2024-01-20 | 2024-01-25 | **2024-01-07** | 2024-01-31 | 0 |
| db-01 | 2024-02-02 | 2024-02-03 | 2024-01-25 | 2024-01-31 | 1 |

- Dòng 01-20: nếu so với `LAG(end_date)` (07/01) thì dòng này bị tách thành đợt mới, trong khi nó vẫn nằm trong sự cố dài 01–31/01.
- Frame `... AND 1 PRECEDING` loại chính dòng hiện tại. Dòng đầu có `MAX` là `NULL`, nên rơi vào `ELSE 1`, tức là mở đợt mới.

Tiếp theo: `SUM(is_new) OVER (...) AS grp`, rồi `GROUP BY server, grp`.

| server | outage_start | outage_end | days | incidents |
| --- | --- | --- | --- | --- |
| db-01 | 2024-01-01 | 2024-01-31 | 31 | 3 |
| db-01 | 2024-02-02 | 2024-02-03 | 2 | 1 |
| web-01 | 2024-01-01 | 2024-01-06 | 6 | 3 |
| web-01 | 2024-01-10 | 2024-01-12 | 3 | 2 |

## B5. Đếm số khoảng đang mở cùng lúc

- **Vấn đề:** lúc đông nhất có bao nhiêu người cùng xem?
- **Tại sao:**
  - Biến mỗi khoảng thành hai sự kiện: +1 lúc bắt đầu, −1 lúc kết thúc. Cộng dồn theo thời gian ra số khoảng đang mở tại mỗi thời điểm.
  - Phải gộp `SUM(delta)` theo thời điểm **trước** khi cộng dồn. Lúc 19:45 có một người rời đi và một người vào. Nếu tính +1 trước −1 thì sẽ có một khoảnh khắc ảo đếm được 4 người.
  - Dùng `UNION ALL`, không dùng `UNION`. Hai người vào cùng lúc là hai dòng giống hệt nhau, `UNION` sẽ bỏ mất một dòng.

```sql
WITH e AS (
  SELECT joined_at AS ts, 1 AS delta FROM sessions
  UNION ALL
  SELECT left_at, -1 FROM sessions
),
p AS (SELECT ts, SUM(delta) AS delta FROM e GROUP BY ts)
SELECT ts, delta, SUM(delta) OVER (ORDER BY ts) AS viewers FROM p
```

| ts | delta | viewers |
| --- | --- | --- |
| 19:00 | 1 | 1 |
| 19:30 | 1 | 2 |
| 19:40 | 1 | **3** |
| 19:45 | 0 | 3 |
| 19:50 | -1 | 2 |
| 20:00 | -1 | 1 |
| 20:30 | -1 | 0 |
| 21:00 | 1 | 1 |
| 21:10 | -1 | 0 |

Đỉnh là 3 người, bắt đầu lúc 19:40. Đỉnh kết thúc ở thời điểm sớm nhất sau 19:40 mà `viewers` nhỏ hơn 3, tức 19:50.

---

## Tổng kết: query đầy đủ

Các bước dùng dữ liệu khác nhau, nên tổng kết là hai câu đầy đủ cho hai dạng nhiều bước nhất: gộp khoảng (B1 → B4) và đếm đồng thời (B1 → B5):

```sql
WITH flagged AS (                                  -- 1 = sự cố này mở một đợt mới
  SELECT server, start_date, end_date,
         CASE WHEN start_date <= MAX(end_date) OVER (PARTITION BY server ORDER BY start_date, end_date
                                                     ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) + 1
              THEN 0 ELSE 1 END AS is_new
  FROM incidents
),
grouped AS (                                       -- cộng dồn cờ = số thứ tự đợt
  SELECT *, SUM(is_new) OVER (PARTITION BY server ORDER BY start_date, end_date) AS grp
  FROM flagged
)
SELECT server, MIN(start_date) AS outage_start, MAX(end_date) AS outage_end,
       MAX(end_date) - MIN(start_date) + 1 AS days, COUNT(*) AS incidents
FROM grouped
GROUP BY server, grp
ORDER BY server, outage_start;
```

| server | outage_start | outage_end | days | incidents |
| --- | --- | --- | --- | --- |
| db-01 | 2024-01-01 | 2024-01-31 | 31 | 3 |
| db-01 | 2024-02-02 | 2024-02-03 | 2 | 1 |
| web-01 | 2024-01-01 | 2024-01-06 | 6 | 3 |
| web-01 | 2024-01-10 | 2024-01-12 | 3 | 2 |

```sql
WITH events AS (                                   -- +1 lúc vào, -1 lúc ra
  SELECT joined_at AS ts, 1 AS delta FROM sessions
  UNION ALL
  SELECT left_at, -1 FROM sessions
),
per_ts AS (SELECT ts, SUM(delta) AS delta FROM events GROUP BY ts),   -- gộp cùng thời điểm
running AS (SELECT ts, SUM(delta) OVER (ORDER BY ts) AS viewers FROM per_ts),
peak AS (SELECT ts, viewers FROM running ORDER BY viewers DESC, ts LIMIT 1)
SELECT COALESCE((SELECT viewers FROM peak), 0) AS max_concurrent,
       (SELECT ts FROM peak) AS peak_start,
       (SELECT MIN(r.ts) FROM running r, peak p WHERE r.ts > p.ts AND r.viewers < p.viewers) AS peak_end;
```

| max_concurrent | peak_start | peak_end |
| --- | --- | --- |
| 3 | 2024-05-10 19:40:00 | 2024-05-10 19:50:00 |
