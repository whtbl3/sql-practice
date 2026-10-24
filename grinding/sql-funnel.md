# Funnel (phễu chuyển đổi)

> Bài liên quan: `funnel/01`, `02`. Output đều chạy thật bằng `check.py`.

## Bài toán

Một cửa hàng online muốn biết khách đi được tới đâu trong hành trình mua hàng: **xem sản phẩm → bỏ vào giỏ → mua**. Bao nhiêu người tới được từng bước, và rơi rụng nhiều nhất ở bước nào?

Một người chỉ được tính ở một bước khi đã đi qua **mọi bước trước đó, theo đúng thứ tự thời gian**. Người bỏ vào giỏ trước khi xem sản phẩm (ví dụ vào từ một đường link lạ) thì chưa đi đúng phễu.

## Dữ liệu

`events`: mỗi dòng = 1 lần người dùng làm một bước. Một bước có thể lặp lại nhiều lần.

| user_id | step | event_time |
| --- | --- | --- |
| 1 (Alice) | view | 2024-01-01 10:00 |
| 1 (Alice) | cart | 2024-01-01 10:05 |
| 1 (Alice) | purchase | 2024-01-01 10:20 |
| 1 (Alice) | view | 2024-01-01 10:30 |
| 2 (Ben) | view | 2024-01-01 11:00 |
| 2 (Ben) | view | 2024-01-01 11:02 |
| 2 (Ben) | cart | 2024-01-01 11:10 |
| 3 (Chloe) | view | 2024-01-02 09:00 |
| 4 (David) | cart | 2024-01-02 08:00 |
| 4 (David) | view | 2024-01-02 08:30 |
| 5 (Emma) | view | 2024-01-03 12:00 |
| 5 (Emma) | purchase | 2024-01-03 12:30 |

Bốn chỗ dễ sai: Alice **xem lại** sau khi đã mua, Ben xem **2 lần**, David bỏ vào giỏ **trước** khi xem, và Emma mua mà **không qua giỏ**.

Vì vậy không đếm thẳng theo bước được:

| step | events | users |
| --- | --- | --- |
| view | 7 | 5 |
| cart | 3 | 3 |
| purchase | 2 | 2 |

Cột `events` đếm số lần bấm, không phải số người. Cột `users` đếm số người, nhưng vẫn tính David ở bước `cart` và Emma ở bước `purchase`, dù cả hai đều không đi đúng phễu.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Lấy lần đầu làm từng bước của mỗi người | CTE `firsts` | **1 người** |
| B2 | Tìm bước xa nhất mỗi người đạt đúng thứ tự | CTE `reached` | 1 người |
| B3 | Đếm số người ở mỗi bước | CTE `steps`, `counts` | **1 bước** |
| B4 | Tính tỉ lệ chuyển đổi | query cuối | 1 bước, thêm % |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Lấy lần đầu làm từng bước của mỗi người (CTE `firsts`)

**Ý tưởng:** phễu đếm **người**, nên trước tiên gom về một dòng mỗi người. Với mỗi bước, ghi lại **lần đầu tiên** người đó làm bước ấy. B2 cần những thời điểm này để kiểm tra thứ tự.

**Ví dụ nhỏ:** Ben xem 2 lần, ta chỉ giữ lần đầu.

| user | step | event_time | reason |
| --- | --- | --- | --- |
| Ben | view | 11:00 | first view, kept |
| Ben | view | 11:02 | <span class="drop">later view, ignored</span> |
| Ben | cart | 11:10 | first cart, kept |

→

| user | t_view | t_cart | t_purchase |
| --- | --- | --- | --- |
| Ben | 11:00 | 11:10 | NULL |
| ... | | | |

```sql
WITH firsts AS (
  SELECT user_id,
         MIN(event_time) FILTER (WHERE step = 'view')     AS t_view,
         MIN(event_time) FILTER (WHERE step = 'cart')     AS t_cart,
         MIN(event_time) FILTER (WHERE step = 'purchase') AS t_purchase
  FROM events
  GROUP BY user_id
)
```

`MIN(event_time) FILTER (WHERE step = 'cart')` nghĩa là: trong các dòng của người này, chỉ xét dòng `cart`, rồi lấy thời điểm nhỏ nhất. Người chưa bỏ vào giỏ lần nào thì nhận `NULL`.

> [!CAUTION]
> ❌ **Dùng `MAX(event_time)` thay cho `MIN`**
>
> Alice xem lúc 10:00, bỏ vào giỏ 10:05, mua 10:20, rồi quay lại xem lúc 10:30. `MAX` lấy lần xem **cuối**, tức 10:30, muộn hơn lúc bỏ giỏ 10:05. Đến B2, Alice bị coi là bỏ giỏ trước khi xem, và rớt khỏi phễu dù đã đi đúng thứ tự.
>
> → **Sửa:** dùng `MIN` để so sánh **lần đầu** của mỗi bước.

## B2. Tìm bước xa nhất mỗi người đạt đúng thứ tự (CTE `reached`)

**Ý tưởng:** kiểm tra từ bước xa nhất trở xuống. Người đã mua, mà mua sau khi bỏ giỏ, và bỏ giỏ sau khi xem, thì đạt bước 3. Nếu không, xét tiếp bước 2, rồi bước 1. Nhánh đầu tiên khớp chính là bước xa nhất.

**Ví dụ nhỏ:**

| user | t_view | t_cart | t_purchase | stage |
| --- | --- | --- | --- | --- |
| Alice | 10:00 | 10:05 | 10:20 | 3 (all 3 steps, in order) |
| David | **08:30** | **08:00** | NULL | 1 (cart before view) |
| Emma | 12:00 | NULL | 12:30 | 1 (no cart) |
| ... | | | | |

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

Không cần viết `IS NOT NULL` cho từng bước. Emma có `t_cart` là `NULL`, nên `t_purchase >= NULL` không ra `true`, và Emma tự rơi xuống nhánh dưới.

> [!CAUTION]
> ❌ **Chỉ kiểm tra người đó có làm bước hay không: `WHEN t_purchase IS NOT NULL THEN 3`**
>
> Emma có `t_purchase`, nên bị tính là đạt bước 3, dù chưa từng bỏ vào giỏ. David có `t_cart`, nên bị tính đạt bước 2, dù bỏ giỏ trước khi xem.
>
> → **Sửa:** mỗi nhánh so thời điểm của **mọi bước trước** theo thứ tự: `t_purchase >= t_cart AND t_cart >= t_view`.

## B3. Đếm số người ở mỗi bước (CTE `steps`, `counts`)

**Ý tưởng:** người đạt bước 3 thì cũng đã qua bước 1 và bước 2. Vì vậy bước `k` đếm mọi người có `stage >= k`. Danh sách bước được viết tay bằng `VALUES`, để bước không ai đạt tới vẫn hiện ra với số 0.

**Ví dụ nhỏ:**

| step_no | step | users with stage ≥ step_no | users |
| --- | --- | --- | --- |
| 1 | view | Alice, Ben, Chloe, David, Emma | 5 |
| 2 | cart | Alice, Ben | 2 |
| 3 | purchase | Alice | 1 |

```sql
steps (step_no, step) AS (
  VALUES (1, 'view'), (2, 'cart'), (3, 'purchase')
),
counts AS (
  SELECT s.step_no, s.step, COUNT(r.user_id) AS users
  FROM steps s
  LEFT JOIN reached r ON r.stage >= s.step_no
  GROUP BY s.step_no, s.step
)
```

Đếm bằng `COUNT(r.user_id)` chứ không dùng `COUNT(*)`. Nếu một bước không ai đạt, `LEFT JOIN` vẫn tạo một dòng `NULL` cho bước đó: `COUNT(*)` sẽ đếm ra 1, còn `COUNT(r.user_id)` ra 0.

> [!CAUTION]
> ❌ **Nối bằng `r.stage = s.step_no` thay vì `>=`**
>
> Cách này đếm người **dừng lại** ở mỗi bước, không phải người **tới được** bước đó. Kết quả ra view 3 (Chloe, David, Emma), cart 1 (Ben), purchase 1 (Alice). Alice đã đi qua bước view, nhưng không được đếm ở đó.
>
> → **Sửa:** `r.stage >= s.step_no`, vì ai tới bước sau thì cũng đã qua bước trước.

## B4. Tính tỉ lệ chuyển đổi (query cuối)

**Ý tưởng:** có hai loại tỉ lệ, đề thường chỉ hỏi một trong hai:
- **So với bước đầu** (`pct_of_first`): bao nhiêu phần trăm người xem đi được tới đây. Đây là tỉ lệ chuyển đổi tổng.
- **So với bước liền trước** (`pct_of_prev`): ở bước này rơi rụng bao nhiêu. Tỉ lệ này cho biết phễu "thủng" ở đâu.

**Ví dụ nhỏ:** bước `cart` có 2 người, bước đầu có 5, bước trước cũng là 5.

| step | users | pct_of_first | pct_of_prev |
| --- | --- | --- | --- |
| cart | 2 | 40.0 = 2 / 5 | 40.0 = 2 / 5 |
| purchase | 1 | 20.0 = 1 / 5 | 50.0 = 1 / 2 |
| ... | | | |

```sql
SELECT step, users,
       ROUND(100.0 * users / NULLIF(FIRST_VALUE(users) OVER (ORDER BY step_no), 0), 1) AS pct_of_first,
       ROUND(100.0 * users / NULLIF(LAG(users) OVER (ORDER BY step_no), 0), 1)         AS pct_of_prev
FROM counts
ORDER BY step_no;
```

`FIRST_VALUE(users) OVER (ORDER BY step_no)` lấy số người của bước đầu tiên. `LAG(users)` lấy số người của bước liền trước. `NULLIF(..., 0)` tránh lỗi chia cho 0 khi bước trước không có ai.

## Tổng kết: query đầy đủ

```sql
WITH firsts AS (                                   -- B1: lần đầu làm từng bước
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
steps (step_no, step) AS (                         -- B3: danh sách bước
  VALUES (1, 'view'), (2, 'cart'), (3, 'purchase')
),
counts AS (                                        -- B3: số người mỗi bước
  SELECT s.step_no, s.step, COUNT(r.user_id) AS users
  FROM steps s
  LEFT JOIN reached r ON r.stage >= s.step_no
  GROUP BY s.step_no, s.step
)
SELECT step, users,                                -- B4: tỉ lệ
       ROUND(100.0 * users / NULLIF(FIRST_VALUE(users) OVER (ORDER BY step_no), 0), 1) AS pct_of_first,
       ROUND(100.0 * users / NULLIF(LAG(users) OVER (ORDER BY step_no), 0), 1)         AS pct_of_prev
FROM counts
ORDER BY step_no;
```

Bước xa nhất của từng người sau B2:

| user | t_view | t_cart | t_purchase | stage |
| --- | --- | --- | --- | --- |
| Alice | 10:00 | 10:05 | 10:20 | 3 |
| Ben | 11:00 | 11:10 | NULL | 2 |
| Chloe | 09:00 | NULL | NULL | 1 |
| David | 08:30 | 08:00 | NULL | 1 |
| Emma | 12:00 | NULL | 12:30 | 1 |

Kết quả cuối:

| step | users | pct_of_first | pct_of_prev |
| --- | --- | --- | --- |
| view | 5 | 100.0 | NULL |
| cart | 2 | 40.0 | 40.0 |
| purchase | 1 | 20.0 | 50.0 |

Phễu rơi rụng nhiều nhất ở bước `view → cart`: chỉ 40% người xem bỏ vào giỏ.

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính: không xét thứ tự thời gian, muốn kết quả là một dòng ngang, hoặc không có phễu cho sẵn mà phải tự tìm đường đi phổ biến. Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi không xét thời gian, kết quả là một dòng ngang

Nhiều đề đơn giản hơn: **chỉ cần biết người đó có làm bước hay không, không quan tâm thứ tự**, và muốn kết quả là một dòng, mỗi bước một cột:

| viewed | carted | purchased | purchase_rate |
| --- | --- | --- | --- |

Luật vẫn giữ: một người chỉ được tính ở một bước khi đã làm **mọi bước trước**. Chỉ là giờ không so thời gian nữa.

Không cần thời điểm thì không cần `MIN(event_time)`. Với mỗi người, ta chỉ cần một cờ đúng/sai cho từng bước. `BOOL_OR(điều kiện)` trả về `true` nếu **ít nhất một dòng** trong nhóm thỏa điều kiện:

```sql
WITH flags AS (
  SELECT user_id,
         BOOL_OR(step = 'view')     AS did_view,
         BOOL_OR(step = 'cart')     AS did_cart,
         BOOL_OR(step = 'purchase') AS did_purchase
  FROM events
  GROUP BY user_id
)
```

| user | did_view | did_cart | did_purchase |
| --- | --- | --- | --- |
| Alice | true | true | true |
| Ben | true | true | false |
| Chloe | true | false | false |
| David | true | true | false |
| Emma | true | false | true |

### Thử cách tự nhiên nhất

Có cờ rồi, cách nghĩ nhanh nhất là đếm từng cờ:

```sql
SELECT COUNT(*) FILTER (WHERE did_view)     AS viewed,
       COUNT(*) FILTER (WHERE did_cart)     AS carted,
       COUNT(*) FILTER (WHERE did_purchase) AS purchased
FROM flags;
```

Ra `purchased` = 2. Con số này tính cả Emma, người mua mà chưa bỏ vào giỏ. Mỗi cột đang được đếm độc lập, chưa đòi hỏi các bước trước.

### Cách sửa: mỗi bước `AND` với mọi bước trước

Điều kiện của bước `k` là cờ của bước đó **cộng với** cờ của mọi bước trước:

```sql
SELECT COUNT(*) FILTER (WHERE did_view)                              AS viewed,
       COUNT(*) FILTER (WHERE did_view AND did_cart)                 AS carted,
       COUNT(*) FILTER (WHERE did_view AND did_cart AND did_purchase) AS purchased,
       ROUND(100.0 * COUNT(*) FILTER (WHERE did_view AND did_cart AND did_purchase)
             / NULLIF(COUNT(*) FILTER (WHERE did_view), 0), 1) AS purchase_rate
FROM flags;
```

| viewed | carted | purchased | purchase_rate |
| --- | --- | --- | --- |
| 5 | 3 | 1 | 20.0 |

Emma giờ không còn ở `purchased`. Để ý `carted` là 3, không phải 2 như ở Phần 1: David được tính, vì đề này không xét David bỏ giỏ trước hay sau khi xem.

> [!TIP]
> **Ghi nhớ:** không xét thời gian thì dùng cờ `BOOL_OR(step = ...)`. Điều kiện mỗi bước là `AND` cờ của mọi bước trước nó.

## V2. Khi phải tự tìm đường đi phổ biến nhất

Có đề không cho phễu sẵn. Đề hỏi: **trong các chuỗi 3 trang liên tiếp mà người dùng đi qua, chuỗi nào xuất hiện nhiều nhất?** Nếu nhiều chuỗi bằng số lần, lấy chuỗi đứng trước theo bảng chữ cái.

```text
page_views (user_id, seq, page)   -- mới; seq = thứ tự trang trong phiên của người đó
```

| user_id | pages in `seq` order |
| --- | --- |
| 1 (Alice) | home → search → product → cart → checkout |
| 2 (Ben) | home → product → cart → checkout |
| 3 (Chloe) | search → product → cart |
| 4 (David) | home → search |

Bảng thật có mỗi lần xem trang một dòng. Bảng trên gom lại cho dễ nhìn.

### Ý tưởng: đặt 3 trang liên tiếp lên cùng một dòng

Với mỗi dòng, ta cần trang hiện tại, trang kế tiếp, và trang kế tiếp nữa. `LEAD(page, 1)` lấy giá trị `page` của dòng **sau** 1 dòng, `LEAD(page, 2)` lấy của dòng sau 2 dòng, trong cùng một người, xếp theo `seq`:

```sql
WITH p AS (
  SELECT page || ' > ' || LEAD(page, 1) OVER w || ' > ' || LEAD(page, 2) OVER w AS path
  FROM page_views
  WINDOW w AS (PARTITION BY user_id ORDER BY seq)
)
SELECT path, COUNT(*) AS occurrences
FROM p
WHERE path IS NOT NULL
GROUP BY path
ORDER BY occurrences DESC, path
LIMIT 1;
```

Xem Alice:

| seq | page | `LEAD(page, 1)` | `LEAD(page, 2)` | path |
| --- | --- | --- | --- | --- |
| 1 | home | search | product | home > search > product |
| 2 | search | product | cart | search > product > cart |
| 3 | product | cart | checkout | product > cart > checkout |
| 4 | cart | checkout | NULL | NULL |
| 5 | checkout | NULL | NULL | NULL |

Hai dòng cuối không đủ 3 trang, `LEAD` ra `NULL`. Nối chuỗi với `NULL` bằng `||` thì cả chuỗi thành `NULL`, nên chỉ cần lọc `path IS NOT NULL`. David chỉ có 2 trang, nên không đóng góp chuỗi nào.

Đếm các chuỗi:

| path | occurrences |
| --- | --- |
| product > cart > checkout | 2 |
| search > product > cart | 2 |
| home > product > cart | 1 |
| home > search > product | 1 |

Có hai chuỗi cùng 2 lần. `ORDER BY occurrences DESC, path` xếp chuỗi nhiều nhất lên đầu, và khi bằng nhau thì xếp theo bảng chữ cái. `LIMIT 1` giữ `product > cart > checkout`.

### Chỗ dễ sai: quên `PARTITION BY user_id`

Nếu cửa sổ chỉ có `ORDER BY user_id, seq`, mọi người bị xếp thành một hàng dài, và `LEAD` đi xuyên qua ranh giới giữa hai người:

| user | seq | path |
| --- | --- | --- |
| Alice | 4 | <span class="drop">cart > checkout > home</span> |
| Alice | 5 | <span class="drop">checkout > home > product</span> |
| ... | | |

Trang `home` và `product` ở đây là của Ben, không phải của Alice. Những chuỗi này chưa từng có ai đi qua. `PARTITION BY user_id` giữ cho `LEAD` chỉ nhìn trong các trang của cùng một người.

> [!TIP]
> **Ghi nhớ:** chuỗi k bước liên tiếp thì dùng `LEAD(x, 1)`, ..., `LEAD(x, k−1)` trong `PARTITION BY` người dùng, rồi lọc `IS NOT NULL` để bỏ chuỗi thiếu.
