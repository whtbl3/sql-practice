# Funnel (phễu chuyển đổi)

> Bài liên quan: `funnel/01`, `02`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** bao nhiêu người đi tới từng bước (xem → giỏ hàng → mua), và người dùng rơi rụng nhiều nhất ở bước nào?

**Vì sao không đếm sự kiện theo bước được:**

| step | events | users |
| --- | --- | --- |
| view | 6 | 5 |
| cart | 3 | 3 |
| purchase | 2 | 2 |

Bảng này có ba chỗ sai:
- Đếm số **lần bấm** thay vì số **người**.
- Không đòi hỏi người đó đã qua các bước trước. User 5 mua mà chưa bỏ vào giỏ vẫn được tính ở bước `purchase`.
- Không xét thứ tự thời gian. User 4 bỏ vào giỏ **trước** khi xem vẫn được tính ở bước `cart`.

Bốn bước:

1. Mỗi user một dòng, ghi lại từng bước của họ
2. Tìm bước xa nhất user đạt được
3. Đếm số user ở mỗi bước
4. Tính tỷ lệ chuyển đổi

Ví dụ chạy xuyên suốt dùng bảng `events`:

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

---

## B1. Mỗi user một dòng, ghi lại từng bước của họ

- **Vấn đề:** phễu đếm **người**, nhưng mỗi người có nhiều dòng sự kiện, và một bước có thể lặp lại nhiều lần.
- **Tại sao:**
  - `GROUP BY user_id` gom về một dòng mỗi người.
  - Với mỗi bước, `MIN(event_time) FILTER (WHERE step = ...)` lấy **lần đầu tiên** user làm bước đó. Ta cần thời điểm để so sánh thứ tự ở B2.
  - Nếu user chưa làm bước nào thì ô đó là `NULL`.

```sql
firsts AS (
  SELECT user_id,
         MIN(event_time) FILTER (WHERE step = 'view')     AS t_view,
         MIN(event_time) FILTER (WHERE step = 'cart')     AS t_cart,
         MIN(event_time) FILTER (WHERE step = 'purchase') AS t_purchase
  FROM events
  GROUP BY user_id
)
```

| user_id | t_view | t_cart | t_purchase |
| --- | --- | --- | --- |
| 1 | 10:00 | 10:05 | 10:20 |
| 2 | 11:00 | 11:10 | NULL |
| 3 | 09:00 | NULL | NULL |
| 4 | **08:30** | **08:00** | NULL |
| 5 | 12:00 | NULL | 12:30 |

**Khi đề nói "không xét thời gian":** chỉ cần biết user có làm bước đó hay không, nên dùng cờ `BOOL_OR(step = 'cart') AS did_cart`. `BOOL_OR` ra `true` nếu ít nhất một dòng thỏa điều kiện.

## B2. Tìm bước xa nhất user đạt được

- **Vấn đề:** user chỉ được tính ở một bước khi đã qua **mọi bước trước** và đúng thứ tự thời gian.
- **Tại sao:**
  - Dùng `CASE` kiểm tra từ bước xa nhất xuống. Nhánh đầu tiên khớp chính là bước xa nhất.
  - So sánh với `NULL` không ra `true`, nên user thiếu bước nào tự rơi xuống nhánh dưới. Không cần viết `IS NOT NULL` cho từng bước.

```sql
reached AS (
  SELECT user_id,
         CASE WHEN t_purchase >= t_cart AND t_cart >= t_view THEN 3
              WHEN t_cart >= t_view                          THEN 2
              WHEN t_view IS NOT NULL                        THEN 1
              ELSE 0 END AS stage
  FROM firsts
)
```

| user_id | stage |
| --- | --- |
| 1 | 3 |
| 2 | 2 |
| 3 | 1 |
| 4 | 1 |
| 5 | 1 |

- User 4: bỏ vào giỏ trước khi xem, nên chỉ dừng ở bước 1.
- User 5: chưa có `cart`, nên `purchase` không được tính.

**Với cờ (không xét thời gian):** điều kiện của mỗi bước là `AND` cờ của mọi bước trước, ví dụ `did_view AND did_cart AND did_purchase`.

## B3. Đếm số user ở mỗi bước

- **Vấn đề:** cần đếm số user ở mỗi bước, kể cả bước không có ai.
- **Tại sao:**
  - User đạt bước 3 thì cũng đã qua bước 1 và 2, nên điều kiện nối là `stage >= step_no`.
  - Tạo danh sách bước bằng `VALUES` rồi `LEFT JOIN` user vào, để bước không ai đạt vẫn hiện ra.
  - Đếm bằng `COUNT(r.user_id)` để bước trống ra 0. `COUNT(*)` sẽ ra 1, vì dòng không khớp vẫn có một dòng `NULL`.

```sql
steps (step_no, step) AS (VALUES (1, 'view'), (2, 'cart'), (3, 'purchase')),
counts AS (
  SELECT s.step_no, s.step, COUNT(r.user_id) AS users
  FROM steps s
  LEFT JOIN reached r ON r.stage >= s.step_no
  GROUP BY s.step_no, s.step
)
```

| step_no | step | users |
| --- | --- | --- |
| 1 | view | 5 |
| 2 | cart | 2 |
| 3 | purchase | 1 |

**Khi đề muốn kết quả là một dòng ngang** (mỗi bước một cột): dùng `COUNT(*) FILTER (WHERE did_view AND did_cart) AS carted`. Không xét thời gian thì `cart` ra 3, vì user 4 vẫn được tính.

## B4. Tính tỷ lệ chuyển đổi

- **Vấn đề:** có hai loại tỷ lệ, và đề thường chỉ hỏi một trong hai:
  - So với bước đầu: tỷ lệ chuyển đổi tổng.
  - So với bước liền trước: rơi rụng ở từng bước.
- **Tại sao:**
  - `FIRST_VALUE` lấy số user ở bước đầu, `LAG` lấy số user ở bước liền trước.
  - `NULLIF(..., 0)` để không bị lỗi chia cho 0 khi không ai vào bước đầu.

```sql
SELECT step, users,
       ROUND(100.0 * users / NULLIF(FIRST_VALUE(users) OVER (ORDER BY step_no), 0), 1) AS pct_of_first,
       ROUND(100.0 * users / NULLIF(LAG(users) OVER (ORDER BY step_no), 0), 1)         AS pct_of_prev
FROM counts
ORDER BY step_no;
```

| step | users | pct_of_first | pct_of_prev |
| --- | --- | --- | --- |
| view | 5 | 100.0 | NULL |
| cart | 2 | 40.0 | 40.0 |
| purchase | 1 | 20.0 | 50.0 |

Rơi rụng nhiều nhất ở bước `view → cart`: chỉ còn 40%.

## Tổng kết: query đầy đủ

Ghép B1 → B4 thành một câu:

```sql
WITH firsts AS (                                   -- B1: mỗi user một dòng, lần đầu của từng bước
  SELECT user_id,
         MIN(event_time) FILTER (WHERE step = 'view')     AS t_view,
         MIN(event_time) FILTER (WHERE step = 'cart')     AS t_cart,
         MIN(event_time) FILTER (WHERE step = 'purchase') AS t_purchase
  FROM events
  GROUP BY user_id
),
reached AS (                                       -- B2: bước xa nhất đạt đúng thứ tự
  SELECT user_id,
         CASE WHEN t_purchase >= t_cart AND t_cart >= t_view THEN 3
              WHEN t_cart >= t_view                          THEN 2
              WHEN t_view IS NOT NULL                        THEN 1
              ELSE 0 END AS stage
  FROM firsts
),
steps (step_no, step) AS (VALUES (1, 'view'), (2, 'cart'), (3, 'purchase')),
counts AS (                                        -- B3: số user mỗi bước
  SELECT s.step_no, s.step, COUNT(r.user_id) AS users
  FROM steps s
  LEFT JOIN reached r ON r.stage >= s.step_no
  GROUP BY s.step_no, s.step
)
SELECT step, users,                                -- B4: tỷ lệ
       ROUND(100.0 * users / NULLIF(FIRST_VALUE(users) OVER (ORDER BY step_no), 0), 1) AS pct_of_first,
       ROUND(100.0 * users / NULLIF(LAG(users) OVER (ORDER BY step_no), 0), 1)         AS pct_of_prev
FROM counts
ORDER BY step_no;
```

| step | users | pct_of_first | pct_of_prev |
| --- | --- | --- | --- |
| view | 5 | 100.0 | NULL |
| cart | 2 | 40.0 | 40.0 |
| purchase | 1 | 20.0 | 50.0 |


---

## Khi đề hỏi đường đi phổ biến nhất thay vì phễu cố định

- **Vấn đề:** không có danh sách bước cho trước. Cần tìm chuỗi 3 trang liên tiếp nào xuất hiện nhiều nhất.
- **Tại sao:**
  - `LEAD(page, 1)` và `LEAD(page, 2)` đưa 2 trang kế tiếp lên cùng dòng với trang hiện tại.
  - Ở 2 dòng cuối của mỗi user, `LEAD` ra `NULL`. Nối chuỗi với `NULL` bằng `||` thì cả chuỗi thành `NULL`, nên chỉ cần lọc `path IS NOT NULL`.

```sql
WITH p AS (
  SELECT page || ' > ' || LEAD(page, 1) OVER w || ' > ' || LEAD(page, 2) OVER w AS path
  FROM page_views
  WINDOW w AS (PARTITION BY user_id ORDER BY seq)
)
SELECT path, COUNT(*) AS occurrences
FROM p WHERE path IS NOT NULL
GROUP BY path ORDER BY 2 DESC, 1 LIMIT 1;
```

| path | occurrences |
| --- | --- |
| home > search > product | 2 |
