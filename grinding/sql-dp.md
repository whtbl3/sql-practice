# Quy hoạch động (DP) trong SQL

> Bài liên quan: `dp/01`–`05`. Output và thông báo lỗi đều chạy thật bằng `check.py`.

## Bài toán

Một siêu thị muốn chạy flash sale vào vài ngày trong tuần. Mỗi ngày có một mức doanh thu tăng thêm ước tính. Để khách không bị mệt, **không được chạy flash sale hai ngày liền nhau**. Đề: chọn những ngày nào để tổng doanh thu tăng thêm lớn nhất?

Cách nghĩ đầu tiên là **tham lam**: chọn ngày có doanh thu lớn nhất, bỏ hai ngày bên cạnh, rồi lặp lại. Cách này thường sai, vì chọn một ngày lớn có thể làm mất hai ngày bên cạnh mà tổng của chúng còn lớn hơn.

**Quy hoạch động** (DP) giải bài này bằng cách đi lần lượt từng ngày. Ở mỗi ngày, ta ghi lại **kết quả tốt nhất có thể tính tới ngày đó**, gọi là một **trạng thái**. Trạng thái của ngày i được tính từ trạng thái của các ngày trước nó. Đến ngày cuối cùng, trạng thái chính là đáp án.

## Dữ liệu

`promo_days`: mỗi dòng = 1 ngày, kèm doanh thu tăng thêm (triệu đồng) nếu chạy flash sale ngày đó.

| day | extra_revenue_m |
| --- | --- |
| 2024-05-01 | 8 |
| 2024-05-02 | 10 |
| 2024-05-03 | 8 |
| 2024-05-04 | 3 |
| 2024-05-05 | 7 |
| 2024-05-06 | 9 |

Cách tham lam: chọn ngày 02 (10), bỏ 01 và 03. Rồi chọn ngày 06 (9), bỏ 05. Còn ngày 04 (3). Tổng 22. Nhưng chọn ngày 01, 03, 06 được 8 + 8 + 9 = **25**.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code |
| --- | --- | --- |
| B1 | Định nghĩa trạng thái và công thức chuyển | (trên giấy, trước khi viết SQL) |
| B2 | Đánh chỉ số liên tục | CTE `days` |
| B3 | Chạy vòng lặp, mang theo trạng thái | CTE đệ quy `dp` |
| B4 | Lấy đáp án | query cuối |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Định nghĩa trạng thái và công thức chuyển

**Ý tưởng:** gọi `best(i)` là tổng lớn nhất có thể đạt được nếu chỉ xét các ngày từ 1 đến i. Ở ngày i, ta có hai lựa chọn:
- **Chọn** ngày i: thì không được chọn ngày i − 1, nên tổng là `best(i − 2) + v(i)`.
- **Bỏ** ngày i: tổng giữ nguyên như khi xét tới ngày i − 1, tức `best(i − 1)`.

Lấy lựa chọn lớn hơn:

```text
best(i) = GREATEST(best(i − 1), best(i − 2) + v(i))
```

**Ví dụ nhỏ:** ngày 3 (v = 8).

| option | value |
| --- | --- |
| skip day 3 | best(2) = 10 |
| take day 3 | best(1) + 8 = 8 + 8 = 16 |
| best(3) | **16** |

Mỗi bước chỉ cần **hai kết quả trước đó**, không cần nhớ đã chọn những ngày nào.

## B2. Đánh chỉ số liên tục (CTE `days`)

**Ý tưởng:** vòng lặp ở B3 cần biết "ngày kế tiếp" là ngày nào. Ngày tháng không phải lúc nào cũng liền nhau, nên ta đổi chúng thành chỉ số 1, 2, 3, ... bằng `ROW_NUMBER`. Ngày kế tiếp của ngày `i` là ngày `i + 1`.

```sql
WITH RECURSIVE days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY day) AS i, day, extra_revenue_m AS v
  FROM promo_days
)
```

| i | day | v |
| --- | --- | --- |
| 1 | 2024-05-01 | 8 |
| 2 | 2024-05-02 | 10 |
| 3 | 2024-05-03 | 8 |
| ... | | |

`WITH RECURSIVE` đặt ở đầu danh sách CTE, dù `days` không đệ quy. Chữ `RECURSIVE` áp cho cả danh sách, và CTE đệ quy ở B3 cần nó.

## B3. Chạy vòng lặp, mang theo trạng thái (CTE đệ quy `dp`)

**Ý tưởng:** SQL không có vòng lặp `for`, nhưng recursive CTE làm được việc đó (xem doc recursive-cte). Mỗi vòng xử lý **đúng một ngày**. Mỗi dòng mang theo hai giá trị:
- `best`: tức `best(i)`.
- `best_prev`: tức `best(i − 1)`.

Từ dòng của ngày i, ta tính dòng của ngày i + 1: `best` mới là `GREATEST(best, best_prev + v)`, và `best_prev` mới là `best` cũ.

**Ví dụ nhỏ:**

| i | v | best_prev = best(i − 1) | best = best(i) |
| --- | --- | --- | --- |
| 0 | | 0 | 0 |
| 1 | 8 | 0 | 8 = max(0, 0 + 8) |
| 2 | 10 | 8 | 10 = max(8, 0 + 10) |
| 3 | 8 | 10 | 16 = max(10, 8 + 8) |
| ... | | | |

```sql
dp(i, best, best_prev) AS (
  SELECT 0::bigint, 0::bigint, 0::bigint
  UNION ALL
  SELECT d.i, GREATEST(dp.best, dp.best_prev + d.v), dp.best
  FROM dp
  JOIN days d ON d.i = dp.i + 1
)
```

Đọc từng phần:
- Dòng neo `(0, 0, 0)` là trạng thái "trước ngày 1": chưa chọn ngày nào. Nhờ dòng này, bảng rỗng vẫn cho kết quả 0.
- `JOIN days d ON d.i = dp.i + 1` lấy ngày kế tiếp. Sau ngày cuối không còn ngày nào khớp, nên vòng lặp tự dừng.

> [!CAUTION]
> ❌ **Dùng `LAG` thay cho vòng lặp**
>
> Cách nghĩ nhanh là `GREATEST(LAG(...), ...)` trên bảng gốc. Nhưng `LAG(extra_revenue_m)` chỉ lấy được **giá trị gốc** của ngày trước (`v(i − 1)`), không lấy được **kết quả đã tính** `best(i − 1)`. Công thức cần kết quả của bước trước, nên phải dùng vòng lặp.
>
> → **Sửa:** khi bước i cần kết quả DP của bước trước, dùng recursive CTE và mang trạng thái theo từng dòng.
>
> ---
>
> ❌ **Neo viết `SELECT 0, 0, 0`**
>
> ```text
> ERROR:  recursive query "dp" column 1 has type integer in non-recursive term but type bigint overall
> ```
>
> `ROW_NUMBER` trả về `bigint`, còn `0` viết thẳng là `integer`.
>
> → **Sửa:** `SELECT 0::bigint, 0::bigint, 0::bigint`.

## B4. Lấy đáp án (query cuối)

**Ý tưởng:** CTE sinh ra một dòng cho mỗi ngày. Đáp án là `best` của **ngày cuối cùng**, tức dòng có `i` lớn nhất.

```sql
SELECT best AS max_extra_revenue
FROM dp
ORDER BY i DESC
LIMIT 1;
```

| max_extra_revenue |
| --- |
| 25 |

## Tổng kết: query đầy đủ

```sql
WITH RECURSIVE days AS (                           -- B2: chỉ số liên tục
  SELECT ROW_NUMBER() OVER (ORDER BY day) AS i, day, extra_revenue_m AS v
  FROM promo_days
),
dp(i, best, best_prev) AS (                        -- B3: mỗi vòng một ngày
  SELECT 0::bigint, 0::bigint, 0::bigint
  UNION ALL
  SELECT d.i, GREATEST(dp.best, dp.best_prev + d.v), dp.best    -- B1: công thức chuyển
  FROM dp
  JOIN days d ON d.i = dp.i + 1
)
SELECT best AS max_extra_revenue                   -- B4: dòng cuối
FROM dp
ORDER BY i DESC
LIMIT 1;
```

Trạng thái sau mỗi ngày:

| i | v | best | best_prev |
| --- | --- | --- | --- |
| 0 | | 0 | 0 |
| 1 | 8 | 8 | 0 |
| 2 | 10 | 10 | 8 |
| 3 | 8 | 16 | 10 |
| 4 | 3 | 16 | 16 |
| 5 | 7 | 23 | 16 |
| 6 | 9 | 25 | 23 |

Kết quả cuối:

| max_extra_revenue |
| --- |
| 25 |

---

# Phần 2: Biến thể

Không phải bài DP nào cũng cần recursive CTE. Trước khi viết, hãy hỏi: **giá trị ở bước i có tính được bằng `MAX` / `MIN` / `SUM ... OVER (...)` trên dữ liệu gốc không?**
- Nếu có, dùng hàm cửa sổ (V1, V2). Nhanh và gọn.
- Nếu bước i cần **kết quả DP** của bước trước, dùng recursive CTE làm vòng lặp (mạch chính).
- Nếu số trạng thái nhỏ và cần thử mọi khả năng, dùng recursive CTE để liệt kê trạng thái, rồi `MIN` / `MAX` ở ngoài (V3, V4).

Mỗi mục dưới đây kể một tình huống, thử cách làm quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Nước mưa đọng giữa các bậc ruộng

Một mặt cắt ruộng bậc thang cho biết độ cao ở mỗi vị trí. Sau trận mưa lớn, nước đọng ở những chỗ trũng. Đề: mỗi vị trí đọng bao nhiêu nước?

```text
terrain (pos, height)   -- mới
```

| pos | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| height | 2 | 0 | 1 | 3 | 0 | 0 | 2 | 1 | 0 | 1 |

**Ý tưởng:** nước ở vị trí i dâng lên tới mức của **bờ thấp hơn** trong hai bờ: điểm cao nhất bên trái (tính cả i) và điểm cao nhất bên phải (tính cả i). Lượng nước là mức đó trừ đi độ cao của i.

### Thử chỉ nhìn bên trái

Cách nghĩ nhanh là chỉ dùng điểm cao nhất bên trái: `MAX(height) OVER (ORDER BY pos) − height`. Vị trí 5 và 6 ra 3, vị trí 8 ra 2, vị trí 9 ra 3. Nhưng bên phải của vị trí 8 không có bờ nào cao hơn 1, nên nước sẽ chảy tràn ra, không đọng lại được 2.

### Cách sửa: hai running `MAX` theo hai chiều

Cả "cao nhất bên trái" và "cao nhất bên phải" đều là `MAX` chạy trên **dữ liệu gốc**, chỉ khác chiều. Không cần vòng lặp:

```sql
SELECT pos, height,
       MAX(height) OVER (ORDER BY pos ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS left_max,
       MAX(height) OVER (ORDER BY pos ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS right_max,
       LEAST(MAX(height) OVER (ORDER BY pos ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
             MAX(height) OVER (ORDER BY pos ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)) - height AS water
FROM terrain
ORDER BY pos;
```

| pos | height | left_max | right_max | water | left only |
| --- | --- | --- | --- | --- | --- |
| 1 | 2 | 2 | 3 | 0 | 0 |
| 2 | 0 | 2 | 3 | 2 | 2 |
| 3 | 1 | 2 | 3 | 1 | 1 |
| 4 | 3 | 3 | 3 | 0 | 0 |
| 5 | 0 | 3 | 2 | 2 | <span class="drop">3</span> |
| 6 | 0 | 3 | 2 | 2 | <span class="drop">3</span> |
| 7 | 2 | 3 | 2 | 0 | <span class="drop">1</span> |
| 8 | 1 | 3 | 1 | 0 | <span class="drop">2</span> |
| 9 | 0 | 3 | 1 | 1 | <span class="drop">3</span> |
| 10 | 1 | 3 | 1 | 0 | <span class="drop">2</span> |

`ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` là khung từ dòng hiện tại tới **cuối** bảng, tức nhìn sang bên phải.

> [!TIP]
> **Ghi nhớ:** nếu trạng thái ở bước i chỉ cần một phép gộp trên dữ liệu gốc (như "cao nhất bên trái"), dùng hàm cửa sổ thay vì vòng lặp.

## V2. Đoạn ngày liên tiếp có tổng lợi nhuận lớn nhất

Một quầy ăn ghi lợi nhuận mỗi ngày, có ngày lỗ. Đề: tìm **đoạn ngày liên tiếp** (ít nhất một ngày) có tổng lợi nhuận lớn nhất, kèm ngày bắt đầu và ngày kết thúc.

```text
daily_profit (day, profit_m)   -- mới
```

| day | 03-01 | 03-02 | 03-03 | 03-04 | 03-05 | 03-06 | 03-07 | 03-08 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| profit_m | 4 | −1 | 3 | −6 | 2 | 1 | −3 | 2 |

**Ý tưởng:** gọi `prefix(j)` là tổng cộng dồn từ ngày đầu tới ngày j. Tổng của đoạn từ ngày i tới ngày j bằng `prefix(j) − prefix(i − 1)`. Muốn đoạn kết thúc tại j có tổng lớn nhất, ta trừ đi `prefix` **nhỏ nhất** đứng trước j. Cả hai đều là hàm cửa sổ trên tổng cộng dồn: không cần vòng lặp.

### Chỗ dễ sai: thiếu `prefix = 0` ở vị trí 0

Đoạn bắt đầu từ ngày đầu tiên (i = 1) có tổng là `prefix(j) − prefix(0)`, với `prefix(0) = 0` là "tổng trước ngày đầu". Nếu bảng `prefix` không có dòng vị trí 0, không đoạn nào bắt đầu được từ ngày 1. Với dữ liệu này, đáp án ra 3 thay vì 6, vì đoạn tốt nhất (03-01 → 03-03 = 4 − 1 + 3) bắt đầu đúng ngày đầu tiên.

### Cách đúng

Thêm dòng `(0, 0)` vào trước bằng `UNION ALL`:

```sql
WITH numbered AS (
  SELECT ROW_NUMBER() OVER (ORDER BY day) AS i, day, profit_m FROM daily_profit
),
prefixes AS (
  SELECT 0::bigint AS i, NULL::date AS day, 0::bigint AS prefix
  UNION ALL
  SELECT i, day, SUM(profit_m) OVER (ORDER BY i) FROM numbered
)
SELECT i, day, prefix,
       prefix - MIN(prefix) OVER (ORDER BY i ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS best_ending_here
FROM prefixes
ORDER BY i;
```

| i | day | profit_m | prefix | smallest prefix before | best_ending_here |
| --- | --- | --- | --- | --- | --- |
| 0 | | | 0 | | |
| 1 | 03-01 | 4 | 4 | 0 | 4 |
| 2 | 03-02 | −1 | 3 | 0 | 3 |
| 3 | 03-03 | 3 | 6 | 0 | **6** |
| 4 | 03-04 | −6 | 0 | 0 | 0 |
| ... | | | | | |

Đáp án là 6, kết thúc ngày 03-03. Đoạn bắt đầu ngay sau vị trí có `prefix` nhỏ nhất (vị trí 0), tức ngày 03-01.

Muốn lấy luôn ngày bắt đầu và ngày kết thúc, ghép từng cặp `prefix` với nhau, vị trí đầu nhỏ hơn hẳn vị trí cuối (để đoạn có ít nhất một ngày), rồi lấy cặp có hiệu lớn nhất:

```sql
SELECT n.day AS start_day, e.day AS end_day, e.prefix - s.prefix AS total_profit
FROM prefixes s
JOIN prefixes e ON s.i < e.i
JOIN numbered n ON n.i = s.i + 1
ORDER BY total_profit DESC, start_day, end_day
LIMIT 1;
```

| start_day | end_day | total_profit |
| --- | --- | --- |
| 2024-03-01 | 2024-03-03 | 6 |

> [!TIP]
> **Ghi nhớ:** tổng một đoạn liên tiếp = hiệu hai tổng cộng dồn. Nhớ thêm `prefix = 0` ở vị trí 0 để đoạn được phép bắt đầu từ dòng đầu tiên.

## V3. Dùng ít voucher nhất để trả đúng một số tiền

Một app tích điểm cho đổi voucher có mệnh giá 2, 5 và 6 điểm. Mỗi mệnh giá dùng bao nhiêu lần cũng được. Đề: với mỗi khoản thanh toán, cần **ít voucher nhất** là bao nhiêu để cộng lại **đúng** số tiền đó? Không trả được thì để `NULL`.

```text
vouchers (value)               -- mới: 2, 5, 6
payments (payment_id, amount)  -- mới: 10, 7, 3, 0, 13
```

Tham lam thất bại ở đây theo hai cách. Trả 10: lấy 6 trước, còn 4 = 2 + 2, tổng 3 voucher, trong khi 5 + 5 chỉ cần 2. Trả 7: lấy 6 trước, còn 1, không voucher nào trả được 1, trong khi 5 + 2 trả được.

### Liệt kê mọi trạng thái

Số tiền nhỏ, nên ta liệt kê **mọi trạng thái** (số tiền đã đạt, số voucher đã dùng). Bắt đầu từ (0, 0). Từ mỗi trạng thái, thêm một voucher bất kỳ để ra trạng thái mới. Đây là bài "tới được những đâu" của doc recursive-cte, nên dùng `UNION` để mỗi trạng thái chỉ xuất hiện một lần:

```sql
WITH RECURSIVE reach(amount, n) AS (
  SELECT 0::bigint, 0::bigint
  UNION
  SELECT r.amount + v.value, r.n + 1
  FROM reach r
  CROSS JOIN vouchers v
  WHERE r.amount + v.value <= (SELECT MAX(amount) FROM payments)
),
best AS (
  SELECT amount, MIN(n) AS min_vouchers FROM reach GROUP BY amount
)
SELECT p.payment_id, p.amount, b.min_vouchers
FROM payments p
LEFT JOIN best b ON b.amount = p.amount
ORDER BY p.payment_id;
```

Một số tiền có thể đạt được bằng nhiều số voucher khác nhau. `MIN` ở ngoài chọn số nhỏ nhất:

| amount | ways to reach it (vouchers used) | min |
| --- | --- | --- |
| 7 | 2 (5 + 2) | 2 |
| 10 | 2 (5 + 5), 3 (6 + 2 + 2), 5 (2 × 5) | 2 |
| 13 | 3 (6 + 5 + 2), 5 | 3 |

| payment_id | amount | min_vouchers |
| --- | --- | --- |
| 1 | 10 | 2 |
| 2 | 7 | 2 |
| 3 | 3 | NULL |
| 4 | 0 | 0 |
| 5 | 13 | 3 |

Số tiền 3 không đạt được (2 + 2 = 4, quá 3), nên không có trạng thái nào. `LEFT JOIN` từ `payments` giữ khoản đó lại với `NULL`. Số tiền 0 khớp đúng dòng neo (0, 0).

> [!CAUTION]
> ❌ **Không chặn số tiền: bỏ `WHERE r.amount + v.value <= ...`**
>
> Số tiền cứ tăng mãi, mỗi vòng luôn có trạng thái mới, nên đệ quy không bao giờ dừng. `check.py` báo `Time Limit Exceeded`.
>
> → **Sửa:** chặn ở số tiền lớn nhất cần trả, vì vượt quá thì trạng thái đó không bao giờ hữu ích.

> [!TIP]
> **Ghi nhớ:** khi tham lam sai và không gian trạng thái nhỏ, liệt kê mọi trạng thái bằng recursive CTE (`UNION`, có chặn trên), rồi `MIN` / `MAX` ở ngoài.

## V4. Xếp đồ vào ba lô (lấy hoặc bỏ mỗi món)

Một nhóm leo núi mang tối đa 10 kg đồ chung. Mỗi món mang **nhiều nhất một lần**. Đề: chọn những món nào để tổng giá trị lớn nhất mà không quá 10 kg?

```text
items (item_id, name, weight_kg, value)   -- mới
```

| item_id | name | weight_kg | value | value per kg |
| --- | --- | --- | --- | --- |
| 1 | Tent | 6 | 66 | 11.0 |
| 2 | Stove | 5 | 52 | 10.4 |
| 3 | Water | 5 | 52 | 10.4 |
| 4 | Lamp | 1 | 8 | 8.0 |
| 5 | Bag | 3 | 27 | 9.0 |
| 6 | Camera | 2 | 14 | 7.0 |

### Thử tham lam theo giá trị mỗi kg

Lấy món có giá trị mỗi kg cao nhất trước: Tent (6 kg). Stove và Water không còn vừa (6 + 5 = 11). Lấy Bag (9 kg), rồi Lamp (10 kg). Tổng giá trị 66 + 27 + 8 = **101**. Nhưng bỏ Tent, lấy Stove + Water thì được 52 + 52 = **104**, cũng đúng 10 kg.

### Cách sửa: thử hai nhánh lấy hoặc bỏ cho từng món

Đi lần lượt từng món (theo `item_id`), mỗi bước tách thành **hai nhánh**: lấy món này, hoặc bỏ. Mỗi dòng mang theo món vừa xét, tổng cân nặng, tổng giá trị, và danh sách tên.

Phần đệ quy chỉ được nhắc tới tên CTE **một lần**, nên không viết hai nhánh bằng `UNION ALL` hai câu `SELECT` được (PostgreSQL báo lỗi). Thay vào đó, nhân mỗi dòng thành hai bằng `CROSS JOIN (VALUES (TRUE), (FALSE)) AS t(take)`, rồi dùng `CASE` theo `take`. Nhánh nào quá 10 kg thì cắt ngay bằng `WHERE`:

```sql
WITH RECURSIVE packs(last_id, weight, value, names) AS (
  SELECT 0::bigint, 0::bigint, 0::bigint, ''::text
  UNION ALL
  SELECT i.item_id,
         p.weight + CASE WHEN t.take THEN i.weight_kg ELSE 0 END,
         p.value  + CASE WHEN t.take THEN i.value     ELSE 0 END,
         p.names  || CASE WHEN t.take THEN ', ' || i.name ELSE '' END
  FROM packs p
  JOIN items i ON i.item_id = p.last_id + 1
  CROSS JOIN (VALUES (TRUE), (FALSE)) AS t(take)
  WHERE p.weight + CASE WHEN t.take THEN i.weight_kg ELSE 0 END <= 10
)
SELECT value AS best_value, weight AS total_weight, SUBSTRING(names FROM 3) AS items
FROM packs
WHERE last_id = (SELECT MAX(item_id) FROM items)
ORDER BY value DESC, weight, names
LIMIT 1;
```

Số nhánh sau mỗi món (đã cắt nhánh quá tải):

| after item | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| branches | 1 | 2 | 3 | 5 | 9 | 17 | 29 |

Ba phương án tốt nhất ở bước cuối:

| best_value | total_weight | items |
| --- | --- | --- |
| **104** | 10 | Stove, Water |
| 101 | 10 | Tent, Lamp, Bag |
| 93 | 9 | Tent, Bag |

Chỉ những dòng đã xét **hết mọi món** (`last_id` = món cuối) mới là phương án hoàn chỉnh. `SUBSTRING(names FROM 3)` bỏ dấu `', '` thừa ở đầu chuỗi tên.

Số nhánh tăng gấp đôi sau mỗi món nếu không bị cắt, nên cách này chỉ dùng được khi số món nhỏ (cỡ vài chục).

> [!TIP]
> **Ghi nhớ:** mỗi món lấy hoặc bỏ thì tách nhánh bằng `CROSS JOIN (VALUES (TRUE), (FALSE))` trong phần đệ quy, cắt nhánh vi phạm ngay bằng `WHERE`, rồi chọn phương án tốt nhất ở ngoài.
