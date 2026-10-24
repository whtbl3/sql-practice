# Khoảng thời gian (intervals) và as-of

> Bài liên quan: `intervals/01`–`04`, `misc/07`. Output đều chạy thật bằng `check.py`.

## Bài toán

Nhiều loại dữ liệu có **ngày bắt đầu và ngày kết thúc**: đặt phòng, hợp đồng, sự cố máy chủ, phiên xem livestream. Mỗi dòng là một **đoạn** trên trục thời gian, không phải một điểm. Vì vậy các phép quen thuộc như `=` hay `GROUP BY` theo ngày không dùng thẳng được, và chỉ cần nhầm ở biên (`<` hay `<=`) là kết quả sai.

Mạch chính giải bài cơ bản nhất: **một homestay muốn tìm các cặp đặt phòng bị trùng lịch** trong cùng một phòng. Các biến thể dùng lại cùng những công cụ đó cho các câu hỏi khác: giá tại một ngày, chia giá trị hợp đồng theo năm, gộp các sự cố chồng nhau, và lúc đông nhất có bao nhiêu người.

## Dữ liệu

`bookings`: mỗi dòng = 1 lượt đặt phòng. Khách ở các đêm từ `check_in` tới **trước** `check_out`. Ngày `check_out` là ngày trả phòng, đêm đó đã thuộc về khách sau.

| booking_id | room | guest | check_in | check_out |
| --- | --- | --- | --- | --- |
| 1 | 101 | Alice | 2024-06-01 | 2024-06-04 |
| 2 | 101 | Ben | 2024-06-04 | 2024-06-07 |
| 3 | 101 | Chloe | 2024-06-03 | 2024-06-05 |
| 4 | 102 | David | 2024-06-02 | 2024-06-09 |
| 5 | 102 | Emma | 2024-06-05 | 2024-06-06 |
| 6 | 201 | Frank | 2024-06-01 | 2024-06-03 |

Hai chỗ dễ sai: Ben **nhận phòng đúng ngày** Alice trả phòng (06-04), và đợt ở của Emma **nằm gọn bên trong** đợt ở của David.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Chốt kiểu khoảng | (quyết định trước khi viết) | |
| B2 | Nối các cặp chồng nhau | `JOIN ... ON` | **1 cặp đặt phòng trùng** |
| B3 | Tính phần giao | `SELECT` | như trên, thêm ngày giao và số đêm |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Chốt kiểu khoảng

**Ý tưởng:** trước khi viết SQL, phải trả lời: **ngày kết thúc có thuộc khoảng hay không?** Mọi công thức sau đều phụ thuộc vào câu trả lời này.

| Kiểu | Ngày cuối | Ví dụ | Chồng nhau khi | Độ dài |
| --- | --- | --- | --- | --- |
| Nửa mở `[start, end)` | không tính | đặt phòng, phiên xem, thuê bao | `a.start < b.end AND b.start < a.end` | `end − start` |
| Đóng `[start, end]` | có tính | hợp đồng, sự cố tính theo ngày | `a.start <= b.end AND b.start <= a.end` | `end − start + 1` |

Đặt phòng là khoảng nửa mở: Alice ở `[06-01, 06-04)`, tức các đêm 01, 02, 03. Đêm 04 là của Ben.

Vì sao điều kiện chồng nhau chỉ có hai vế? Hai khoảng **không** chồng nhau khi một khoảng kết thúc trước khi khoảng kia bắt đầu: `a.end <= b.start OR b.end <= a.start`. Phủ định điều đó ra đúng công thức trong bảng. Không cần liệt kê các trường hợp "A chứa B", "lệch trái", "lệch phải": công thức hai vế đã bao hết.

## B2. Nối các cặp chồng nhau (`JOIN ... ON`)

**Ý tưởng:** muốn so mọi đặt phòng với mọi đặt phòng khác trong cùng phòng, ta nối bảng với **chính nó** (self-join), đặt tên hai bản là `a` và `b`. Điều kiện nối gồm: cùng phòng, khác lượt đặt, và chồng nhau theo công thức ở B1.

**Ví dụ nhỏ:** phòng 101.

| a | b | a.check_in < b.check_out? | b.check_in < a.check_out? | overlap? |
| --- | --- | --- | --- | --- |
| Alice [06-01, 06-04) | Ben [06-04, 06-07) | 06-01 < 06-07 yes | 06-04 < 06-04 **no** | no |
| Alice [06-01, 06-04) | Chloe [06-03, 06-05) | yes | 06-03 < 06-04 yes | **yes** |
| Ben [06-04, 06-07) | Chloe [06-03, 06-05) | yes | 06-03 < 06-07 yes | **yes** |

```sql
FROM bookings a
JOIN bookings b
  ON b.room = a.room
 AND a.booking_id < b.booking_id
 AND a.check_in < b.check_out
 AND b.check_in < a.check_out
```

`a.booking_id < b.booking_id` có hai tác dụng: không so một lượt đặt với chính nó, và mỗi cặp chỉ xuất hiện một lần.

> [!CAUTION]
> ❌ **Dùng `<=` (coi như khoảng đóng)**
>
> Ben nhận phòng đúng ngày Alice trả phòng. Với `<=`, `06-04 <= 06-04` đúng, nên cặp (Alice, Ben) bị báo trùng. Thực tế hai người không ở chung đêm nào.
>
> → **Sửa:** khoảng nửa mở dùng `<` ở cả hai vế.
>
> ---
>
> ❌ **Dùng `a.booking_id <> b.booking_id`**
>
> Mỗi cặp hiện ra hai lần: (Alice, Chloe) và (Chloe, Alice). Phòng 101 ra 4 dòng thay vì 2.
>
> → **Sửa:** `a.booking_id < b.booking_id` để giữ mỗi cặp một lần.

## B3. Tính phần giao (`SELECT`)

**Ý tưởng:** phần trùng của hai khoảng bắt đầu ở ngày bắt đầu **muộn hơn** (`GREATEST`), và kết thúc ở ngày kết thúc **sớm hơn** (`LEAST`). Với khoảng nửa mở, số đêm trùng là hiệu hai ngày đó.

**Ví dụ nhỏ:**

| a | b | overlap_start = GREATEST(check_in) | overlap_end = LEAST(check_out) | nights |
| --- | --- | --- | --- | --- |
| Alice [06-01, 06-04) | Chloe [06-03, 06-05) | 06-03 | 06-04 | 1 |
| David [06-02, 06-09) | Emma [06-05, 06-06) | 06-05 | 06-06 | 1 |
| ... | | | | |

Emma nằm gọn trong David, nhưng công thức vẫn đúng: phần giao chính là đợt ở của Emma.

```sql
SELECT a.room, a.booking_id AS booking_a, b.booking_id AS booking_b,
       GREATEST(a.check_in, b.check_in) AS overlap_start,
       LEAST(a.check_out, b.check_out)  AS overlap_end,
       LEAST(a.check_out, b.check_out) - GREATEST(a.check_in, b.check_in) AS overlap_nights
```

## Tổng kết: query đầy đủ

```sql
SELECT a.room, a.booking_id AS booking_a, b.booking_id AS booking_b,      -- B3: phần giao
       GREATEST(a.check_in, b.check_in) AS overlap_start,
       LEAST(a.check_out, b.check_out)  AS overlap_end,
       LEAST(a.check_out, b.check_out) - GREATEST(a.check_in, b.check_in) AS overlap_nights
FROM bookings a
JOIN bookings b                                                          -- B2: self-join
  ON b.room = a.room
 AND a.booking_id < b.booking_id
 AND a.check_in < b.check_out                                            -- B1: khoảng nửa mở
 AND b.check_in < a.check_out
ORDER BY a.room, booking_a, booking_b;
```

| room | booking_a | booking_b | overlap_start | overlap_end | overlap_nights |
| --- | --- | --- | --- | --- | --- |
| 101 | 1 | 3 | 2024-06-03 | 2024-06-04 | 1 |
| 101 | 2 | 3 | 2024-06-04 | 2024-06-05 | 1 |
| 102 | 4 | 5 | 2024-06-05 | 2024-06-06 | 1 |

---

# Phần 2: Biến thể

Các biến thể dưới đây dùng lại những gì ở Phần 1 (kiểu khoảng, điều kiện chồng nhau, `GREATEST` / `LEAST`) cho các câu hỏi khác. Mỗi mục kể một tình huống, thử cách làm quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi tra giá tại một ngày (as-of)

Một quán cà phê đổi giá theo thời gian. Bảng giá chỉ lưu **ngày bắt đầu hiệu lực** của mỗi mức giá. Mức giá giữ nguyên cho tới lần đổi tiếp theo của cùng sản phẩm:

```text
price_history (product_id, valid_from, price)        -- mới; các dòng không theo thứ tự
order_lines   (order_id, order_date, product_id, qty) -- mới
```

| product_id | valid_from | price |
| --- | --- | --- |
| 1 | 2024-04-01 | 48000 |
| 1 | 2024-01-01 | 45000 |
| 2 | 2024-03-01 | 50000 |
| 1 | 2024-08-10 | 52000 |

| order_id | order_date | product_id | qty |
| --- | --- | --- | --- |
| 1 | 2024-02-10 | 1 | 2 |
| 2 | 2024-04-01 | 1 | 1 |
| 2 | 2024-04-01 | 2 | 1 |
| 3 | 2024-08-09 | 1 | 1 |
| 4 | 2024-02-15 | 2 | 2 |

Đề: với mỗi dòng đơn hàng, giá áp dụng vào ngày đặt là bao nhiêu?

### Tự tạo khoảng cho mỗi mức giá

Bảng giá chỉ có điểm bắt đầu. Ta tự tạo điểm kết thúc: mỗi mức giá hết hiệu lực đúng ngày mức giá kế tiếp bắt đầu. `LEAD(valid_from)` lấy ngày bắt đầu của mức giá kế tiếp, trong cùng sản phẩm:

```sql
WITH ranges AS (
  SELECT product_id, price, valid_from,
         LEAD(valid_from) OVER (PARTITION BY product_id ORDER BY valid_from) AS valid_to
  FROM price_history
)
```

| product_id | price | valid_from | valid_to |
| --- | --- | --- | --- |
| 1 | 45000 | 2024-01-01 | 2024-04-01 |
| 1 | 48000 | 2024-04-01 | 2024-08-10 |
| 1 | 52000 | 2024-08-10 | NULL |
| 2 | 50000 | 2024-03-01 | NULL |

Đây là khoảng nửa mở `[valid_from, valid_to)`. `valid_to` là `NULL` nghĩa là mức giá vẫn đang áp dụng.

### Thử cách tự nhiên nhất

So ngày đặt hàng với khoảng bằng `BETWEEN`:

```sql
LEFT JOIN ranges r
       ON r.product_id = o.product_id
      AND o.order_date BETWEEN r.valid_from AND COALESCE(r.valid_to, DATE '9999-12-31')
```

| order_id | product_id | order_date | price |
| --- | --- | --- | --- |
| 2 | 1 | 2024-04-01 | 45000 |
| 2 | 1 | 2024-04-01 | 48000 |
| ... | | | |

Đơn 2 đặt đúng ngày 04-01, ngày giá đổi từ 45000 sang 48000. `BETWEEN` tính cả hai đầu, nên ngày 04-01 khớp **cả hai** mức giá, và dòng đơn bị nhân đôi.

### Cách sửa: so như một khoảng nửa mở

Ngày đặt phải `>=` ngày bắt đầu và `<` ngày kết thúc. Thêm `IS NULL` cho mức giá đang hiệu lực. `LEFT JOIN` giữ cả đơn đặt khi sản phẩm chưa có giá:

```sql
SELECT o.order_id, o.product_id, o.order_date, r.price AS unit_price, r.price * o.qty AS line_total
FROM order_lines o
LEFT JOIN ranges r
       ON r.product_id = o.product_id
      AND o.order_date >= r.valid_from
      AND (r.valid_to IS NULL OR o.order_date < r.valid_to)
ORDER BY o.order_id, o.product_id;
```

| order_id | product_id | order_date | unit_price | line_total |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-02-10 | 45000 | 90000 |
| 2 | 1 | 2024-04-01 | 48000 | 48000 |
| 2 | 2 | 2024-04-01 | 50000 | 50000 |
| 3 | 1 | 2024-08-09 | 48000 | 48000 |
| 4 | 2 | 2024-02-15 | NULL | NULL |

Đơn 3 đặt ngày 08-09, một ngày trước khi giá lên 52000, nên vẫn là 48000. Đơn 4 đặt sản phẩm 2 trước khi nó có giá (03-01), nên giá là `NULL`. Điều kiện `r.product_id = o.product_id` cũng không được thiếu: không có nó, giá của sản phẩm khác sẽ lọt vào.

Cũng có thể không tạo khoảng, mà với mỗi dòng đơn, tìm thẳng **mức giá mới nhất có `valid_from <= order_date`**:

```sql
LEFT JOIN LATERAL (
  SELECT ph.price FROM price_history ph
  WHERE ph.product_id = o.product_id AND ph.valid_from <= o.order_date
  ORDER BY ph.valid_from DESC
  LIMIT 1
) p ON TRUE
```

Cách này cho cùng kết quả.

> [!TIP]
> **Ghi nhớ:** bảng chỉ có ngày bắt đầu thì tạo `valid_to` bằng `LEAD`. So một ngày với khoảng nửa mở bằng `>= valid_from AND (valid_to IS NULL OR < valid_to)`, không dùng `BETWEEN`.

## V2. Khi chia một khoảng theo từng năm

Một công ty ghi nhận doanh thu hợp đồng **đều theo từng ngày**. Một hợp đồng kéo dài qua nhiều năm thì phải chia giá trị cho từng năm, theo số ngày rơi vào năm đó. Hợp đồng tính cả ngày đầu lẫn ngày cuối (khoảng đóng):

```text
contracts (contract_id, start_date, end_date, value_k)   -- mới
```

| contract_id | start_date | end_date | value_k |
| --- | --- | --- | --- |
| 1 | 2023-10-01 | 2024-03-31 | 18300 |
| 2 | 2024-05-01 | 2024-05-31 | 3100 |
| 3 | 2024-12-31 | 2025-01-02 | 900 |

### Một dòng thành nhiều dòng

Mỗi hợp đồng cần **một dòng cho mỗi năm nó chạm tới**. `generate_series(năm_đầu, năm_cuối)` sinh ra các năm đó. `CROSS JOIN LATERAL` cho phép `generate_series` dùng cột của từng hợp đồng:

```sql
FROM contracts c
CROSS JOIN LATERAL generate_series(EXTRACT(YEAR FROM c.start_date)::int,
                                   EXTRACT(YEAR FROM c.end_date)::int) AS y(yr)
```

Hợp đồng 1 (2023 → 2024) thành 2 dòng, hợp đồng 2 vẫn 1 dòng, hợp đồng 3 (2024 → 2025) thành 2 dòng.

### Phần của mỗi năm là phần giao

Phần của hợp đồng trong một năm chính là **phần giao** giữa hợp đồng và năm đó, giống B3. Năm `yr` là khoảng đóng `[yr-01-01, yr-12-31]`, nên bắt đầu ở ngày muộn hơn, kết thúc ở ngày sớm hơn:

```sql
SELECT c.contract_id, y.yr AS year,
       GREATEST(c.start_date, make_date(y.yr, 1, 1)) AS part_start,
       LEAST(c.end_date, make_date(y.yr, 12, 31))    AS part_end,
       LEAST(c.end_date, make_date(y.yr, 12, 31)) - GREATEST(c.start_date, make_date(y.yr, 1, 1)) + 1 AS days,
       ROUND(c.value_k::numeric
             * (LEAST(c.end_date, make_date(y.yr, 12, 31)) - GREATEST(c.start_date, make_date(y.yr, 1, 1)) + 1)
             / (c.end_date - c.start_date + 1)) AS allocated_k
FROM contracts c
CROSS JOIN LATERAL generate_series(EXTRACT(YEAR FROM c.start_date)::int,
                                   EXTRACT(YEAR FROM c.end_date)::int) AS y(yr)
ORDER BY c.contract_id, year;
```

| contract_id | year | part_start | part_end | days | allocated_k |
| --- | --- | --- | --- | --- | --- |
| 1 | 2023 | 2023-10-01 | 2023-12-31 | 92 | 9200 |
| 1 | 2024 | 2024-01-01 | 2024-03-31 | 91 | 9100 |
| 2 | 2024 | 2024-05-01 | 2024-05-31 | 31 | 3100 |
| 3 | 2024 | 2024-12-31 | 2024-12-31 | 1 | 300 |
| 3 | 2025 | 2025-01-01 | 2025-01-02 | 2 | 600 |

Hợp đồng 1 có 183 ngày (92 + 91), nên mỗi ngày đáng 18300 / 183 = 100. `value_k::numeric` và "nhân trước, chia sau" để phép chia không bị chia số nguyên.

### Chỗ dễ sai: quên `+ 1`

Hợp đồng là khoảng đóng, nên số ngày là `end − start + 1`. Hợp đồng 3 chạy từ 12-31 tới 01-02: đó là 3 ngày (31/12, 1/1, 2/1). Nếu quên `+ 1`:

| contract_id | year | days | total | allocated_k |
| --- | --- | --- | --- | --- |
| 3 | 2024 | <span class="drop">0</span> | <span class="drop">2</span> | <span class="drop">0</span> |
| 3 | 2025 | <span class="drop">1</span> | <span class="drop">2</span> | <span class="drop">450</span> |

Năm 2024 được 0 dù hợp đồng có chạy ngày 31/12, và tổng chỉ còn 450 thay vì 900.

Làm tròn từng phần có thể khiến tổng các phần lệch 1 đơn vị so với giá trị hợp đồng. Nếu đề yêu cầu tổng khớp tuyệt đối, dồn phần chênh lệch vào năm cuối. Muốn chia theo tháng thì làm y hệt, với biên tháng là ngày đầu tháng và `(ngày đầu tháng + INTERVAL '1 month')::date − 1`.

> [!TIP]
> **Ghi nhớ:** chia khoảng theo kỳ thì sinh các kỳ bằng `CROSS JOIN LATERAL generate_series`, rồi lấy phần giao bằng `GREATEST(start)` / `LEAST(end)`. Khoảng đóng thì độ dài là `end − start + 1`.

## V3. Khi gộp các khoảng chồng nhau

Một công ty hosting ghi lại các sự cố máy chủ. Nhiều sự cố chồng lên nhau hoặc nối tiếp nhau thực chất là **một đợt gián đoạn**. Đề: gộp các sự cố chồng nhau **hoặc liền kề** (sự cố bắt đầu ngay ngày sau khi sự cố khác kết thúc) thành từng đợt. Sự cố tính cả ngày đầu và ngày cuối:

```text
incidents (incident_id, server, start_date, end_date)   -- mới
```

| incident_id | server | start_date | end_date |
| --- | --- | --- | --- |
| 1 | api-01 | 2024-03-01 | 2024-03-20 |
| 2 | api-01 | 2024-03-02 | 2024-03-04 |
| 3 | api-01 | 2024-03-10 | 2024-03-12 |
| 4 | api-01 | 2024-03-21 | 2024-03-22 |
| 5 | api-01 | 2024-03-25 | 2024-03-26 |
| 6 | db-02 | 2024-03-05 | 2024-03-06 |
| 7 | db-02 | 2024-03-08 | 2024-03-09 |

Với api-01: sự cố 1 kéo dài cả 03-01 → 03-20, sự cố 2 và 3 nằm bên trong nó, sự cố 4 bắt đầu ngay ngày sau (03-21). Bốn sự cố này là một đợt, 03-01 → 03-22. Sự cố 5 cách 2 ngày, là đợt riêng.

### Ý tưởng: gaps & islands trên khoảng

Đây là cách làm của V4 trong doc gaps-islands, áp cho khoảng: xếp các sự cố theo ngày bắt đầu, gắn cờ `is_new = 1` cho sự cố **mở đầu một đợt mới**, rồi cộng dồn cờ để ra số thứ tự đợt.

### Thử cách tự nhiên nhất

Một sự cố mở đợt mới khi nó bắt đầu sau khi sự cố **ngay trước** kết thúc (cộng 1 ngày để liền kề cũng gộp): `start_date > LAG(end_date) + 1`.

| incident | start | end | `LAG(end_date)` | is_new |
| --- | --- | --- | --- | --- |
| 1 | 03-01 | 03-20 | NULL | 1 |
| 2 | 03-02 | 03-04 | 03-20 | 0 |
| 3 | 03-10 | 03-12 | **03-04** | <span class="drop">1</span> |
| 4 | 03-21 | 03-22 | 03-12 | <span class="drop">1</span> |
| ... | | | | |

Sự cố 3 bị tách thành đợt mới, vì nó bắt đầu sau ngày kết thúc của sự cố 2 (03-04). Nhưng sự cố 3 vẫn nằm trong sự cố 1, vốn còn kéo dài tới 03-20. `LAG` chỉ nhìn được dòng ngay trước, mà dòng đó lại là một sự cố ngắn nằm bên trong sự cố dài. Kết quả: api-01 bị chia thành 4 đợt thay vì 2.

### Cách sửa: so với điểm kết thúc xa nhất từ trước tới giờ

Một sự cố mở đợt mới khi nó bắt đầu sau **ngày kết thúc xa nhất của mọi sự cố trước nó**. `MAX(end_date) OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)` lấy ngày kết thúc lớn nhất trong tất cả các dòng trước, không tính chính dòng hiện tại:

| incident | start | end | max end before | is_new |
| --- | --- | --- | --- | --- |
| 1 | 03-01 | 03-20 | NULL | 1 |
| 2 | 03-02 | 03-04 | 03-20 | 0 |
| 3 | 03-10 | 03-12 | **03-20** | 0 |
| 4 | 03-21 | 03-22 | 03-20 | 0 (03-21 = 03-20 + 1, adjacent) |
| 5 | 03-25 | 03-26 | 03-22 | 1 |

```sql
WITH flagged AS (
  SELECT server, start_date, end_date,
         CASE WHEN start_date <= MAX(end_date) OVER (PARTITION BY server ORDER BY start_date, end_date
                                                     ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) + 1
              THEN 0 ELSE 1 END AS is_new
  FROM incidents
),
grouped AS (
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
| api-01 | 2024-03-01 | 2024-03-22 | 22 | 4 |
| api-01 | 2024-03-25 | 2024-03-26 | 2 | 1 |
| db-02 | 2024-03-05 | 2024-03-06 | 2 | 1 |
| db-02 | 2024-03-08 | 2024-03-09 | 2 | 1 |

Ở dòng đầu của mỗi máy chủ, `MAX` của "không dòng nào" là `NULL`. `start_date <= NULL` không ra `true`, nên rơi vào `ELSE 1`: dòng đầu luôn mở đợt mới. Ở db-02, ngày 03-07 trống, nên hai sự cố không liền kề và là hai đợt riêng.

> [!TIP]
> **Ghi nhớ:** gộp khoảng thì so ngày bắt đầu với `MAX(end) OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)`, không so với `LAG(end)`. Sau đó cộng dồn cờ để ra số thứ tự đợt.

## V4. Khi đếm số khoảng đang mở cùng lúc

Một lớp học tiếng Anh online phát trực tiếp. Mỗi người xem có giờ vào và giờ ra, theo khoảng nửa mở: lúc rời đi thì không còn được tính. Đề: **lúc đông nhất có bao nhiêu người cùng xem, bắt đầu từ lúc nào và kéo dài tới lúc nào?**

```text
sessions (session_id, viewer, joined_at, left_at)   -- mới
```

| viewer | joined_at | left_at |
| --- | --- | --- |
| Alice | 20:00 | 21:00 |
| Ben | 20:10 | 20:30 |
| Chloe | 20:30 | 20:50 |
| David | 20:20 | 20:40 |
| Emma | 21:30 | 21:45 |
| Frank | 21:30 | 21:40 |

### Ý tưởng: mỗi khoảng thành hai sự kiện

Biến mỗi phiên thành hai sự kiện: **+1** lúc vào và **−1** lúc ra. Xếp mọi sự kiện theo thời gian rồi cộng dồn, ta được số người đang xem tại mỗi thời điểm. Hai danh sách sự kiện được nối lại bằng `UNION ALL`:

```sql
WITH events AS (
  SELECT joined_at AS ts, 1 AS delta FROM sessions
  UNION ALL
  SELECT left_at, -1 FROM sessions
),
per_ts AS (
  SELECT ts, SUM(delta) AS delta FROM events GROUP BY ts
)
SELECT ts, delta, SUM(delta) OVER (ORDER BY ts) AS viewers
FROM per_ts;
```

| ts | delta | viewers |
| --- | --- | --- |
| 20:00 | 1 | 1 |
| 20:10 | 1 | 2 |
| 20:20 | 1 | **3** |
| 20:30 | 0 | 3 |
| 20:40 | −1 | 2 |
| 20:50 | −1 | 1 |
| 21:00 | −1 | 0 |
| 21:30 | 2 | 2 |
| 21:40 | −1 | 1 |
| 21:45 | −1 | 0 |

Đỉnh là 3 người, bắt đầu lúc 20:20 (Alice, Ben, David). Đỉnh kết thúc ở thời điểm sớm nhất sau 20:20 mà số người giảm xuống dưới 3, tức 20:40, khi David rời đi.

### Hai chỗ dễ sai

**Không gộp các sự kiện cùng thời điểm.** Lúc 20:30, Ben rời đi và Chloe vào. Nếu cộng dồn từng sự kiện riêng lẻ, và +1 của Chloe được xếp trước −1 của Ben, ta có một khoảnh khắc ảo **4 người**:

| ts | delta | viewers |
| --- | --- | --- |
| 20:20 | 1 | 3 |
| 20:30 | +1 (Chloe) | <span class="drop">4</span> |
| 20:30 | −1 (Ben) | 3 |

Ben và Chloe không bao giờ cùng xem: lúc Chloe vào là lúc Ben đã ra. Phải `GROUP BY ts` và cộng `delta` của cùng thời điểm **trước** khi cộng dồn. Lúc 20:30, +1 và −1 triệt tiêu thành 0.

**Dùng `UNION` thay cho `UNION ALL`.** Emma và Frank cùng vào lúc 21:30, nên có hai dòng `(21:30, +1)` giống hệt nhau. `UNION` bỏ các dòng trùng, nên chỉ còn một. Lúc 21:30 chỉ đếm được 1 người, và đến cuối buổi số người xem ra **−1**. `UNION ALL` giữ mọi dòng.

### Lấy đỉnh và khoảng thời gian của đỉnh

```sql
WITH events AS (
  SELECT joined_at AS ts, 1 AS delta FROM sessions
  UNION ALL
  SELECT left_at, -1 FROM sessions
),
per_ts AS (                                        -- gộp các sự kiện cùng thời điểm
  SELECT ts, SUM(delta) AS delta FROM events GROUP BY ts
),
running AS (                                       -- số người đang xem tại mỗi thời điểm
  SELECT ts, SUM(delta) OVER (ORDER BY ts) AS viewers FROM per_ts
),
peak AS (                                          -- thời điểm đầu tiên đạt số lớn nhất
  SELECT ts, viewers FROM running ORDER BY viewers DESC, ts LIMIT 1
)
SELECT COALESCE((SELECT viewers FROM peak), 0) AS max_concurrent,
       (SELECT ts FROM peak) AS peak_start,
       (SELECT MIN(r.ts) FROM running r, peak p WHERE r.ts > p.ts AND r.viewers < p.viewers) AS peak_end;
```

| max_concurrent | peak_start | peak_end |
| --- | --- | --- |
| 3 | 2024-05-10 20:20:00 | 2024-05-10 20:40:00 |

`COALESCE(..., 0)` cho trường hợp bảng trống: không có phiên nào thì đỉnh là 0, còn hai mốc thời gian là `NULL`.

> [!TIP]
> **Ghi nhớ:** đếm số khoảng đang mở thì biến mỗi khoảng thành +1 / −1, nối bằng `UNION ALL`, gộp theo thời điểm, rồi cộng dồn.
