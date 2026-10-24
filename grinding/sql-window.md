# Window function

<style>
.markdown-preview tr:has(.drop) td { background: rgba(191, 97, 106, 0.16) !important; }
</style>

> Bài liên quan: `window/01`–`12`. Output đều chạy thật bằng `check.py`.

## Bài toán

Nhiều câu hỏi cần gắn lên **từng dòng** một con số được tính từ **các dòng khác**: tổng tiền của khách đặt cạnh mỗi đơn, tổng cộng dồn tới đơn này, số tiền của đơn ngay trước, đơn này đứng hạng mấy trong các đơn của khách.

`GROUP BY` không làm được việc này, vì nó gộp mỗi nhóm thành **một dòng**, nên mất chi tiết từng đơn. Hàm cửa sổ (window function) tính trên một nhóm dòng nhưng **giữ nguyên số dòng**.

Viết một hàm cửa sổ là trả lời bốn câu hỏi. Sau đó, nếu cần lọc theo kết quả, ta thêm một bước lọc:

```text
<hàm> OVER (PARTITION BY ...   ORDER BY ...   ROWS/RANGE BETWEEN ... AND ...)
 │           └ B1: nhóm nào     └ B2: thứ tự   └ B3: nhìn thấy những dòng nào
 └ B4: tính gì                                    B5: lọc kết quả ở tầng ngoài
```

Thứ tự chạy của một câu `SELECT`: `FROM → WHERE → GROUP BY → HAVING → hàm cửa sổ → SELECT → ORDER BY → LIMIT`. Hàm cửa sổ chạy **sau** `GROUP BY` và **sau** `WHERE`. Điều này giải thích nhiều lỗi ở các bước dưới.

## Dữ liệu

`orders`: mỗi dòng = 1 đơn.

| order_id | customer | order_date | amount |
| --- | --- | --- | --- |
| 1 | Alice | 2024-01-01 | 100 |
| 2 | Alice | 2024-01-03 | 300 |
| 3 | Alice | 2024-01-03 | 200 |
| 4 | Alice | 2024-01-10 | 300 |
| 5 | Ben | 2024-01-02 | 50 |
| 6 | Ben | 2024-01-08 | 150 |

Hai chỗ dễ sai: đơn 2 và đơn 3 **cùng ngày**, và đơn 2 với đơn 4 **cùng số tiền**.

## Lộ trình

| Bước | Câu hỏi | Phần nào của `OVER (...)` |
| --- | --- | --- |
| B1 | Tính trong nhóm nào? | `PARTITION BY` |
| B2 | Xếp các dòng theo thứ tự nào? | `ORDER BY` |
| B3 | Mỗi dòng nhìn thấy những dòng nào? | `ROWS` / `RANGE BETWEEN ...` (khung) |
| B4 | Tính gì? | hàm đứng trước `OVER` |
| B5 | Lọc theo kết quả thế nào? | `WHERE` ở tầng ngoài |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. `PARTITION BY`: tính trong nhóm nào

**Ý tưởng:** `PARTITION BY customer` chia các dòng thành từng nhóm theo khách, và hàm chỉ tính trong nhóm của dòng đang xét. `OVER ()` (không có gì bên trong) nghĩa là cả bảng là một nhóm. Khi không có `ORDER BY`, hàm nhìn thấy cả nhóm, nên mọi dòng trong nhóm nhận **cùng một giá trị**.

**Ví dụ nhỏ:**

| order_id | customer | amount | cust_total | grand_total | pct_of_cust |
| --- | --- | --- | --- | --- | --- |
| 1 | Alice | 100 | 900 | 1100 | 11.1 = 100 / 900 |
| 5 | Ben | 50 | 200 | 1100 | 25.0 = 50 / 200 |
| ... | | | | | |

```sql
SELECT order_id, customer, amount,
       SUM(amount) OVER (PARTITION BY customer) AS cust_total,
       SUM(amount) OVER ()                      AS grand_total,
       ROUND(100.0 * amount / SUM(amount) OVER (PARTITION BY customer), 1) AS pct_of_cust
FROM orders;
```

Mỗi đơn vẫn là một dòng, nhưng có thêm tổng của khách và tổng của cả bảng để tính tỉ trọng.

> [!CAUTION]
> ❌ **Quên `PARTITION BY` khi lấy đơn trước: `LAG(amount) OVER (ORDER BY order_date, order_id)`**
>
> Mọi đơn bị xếp chung một hàng theo ngày. Đơn đầu tiên của Ben (ngày 01-02) nhận "đơn trước" là 100, tức đơn của **Alice** ngày 01-01. Ben chưa từng có đơn trước đó.
>
> → **Sửa:** `LAG(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id)`.

## B2. `ORDER BY`: thứ tự trong nhóm

**Ý tưởng:** tổng cộng dồn, đơn trước, hạng... đều cần một thứ tự. `ORDER BY` trong `OVER` quyết định thứ tự đó. Câu hỏi khó là: **hai đơn cùng ngày thì đơn nào đứng trước?**

**Ví dụ nhỏ:** tổng cộng dồn của Alice.

| order_id | order_date | amount | `ORDER BY order_date` | `ORDER BY order_date, order_id` |
| --- | --- | --- | --- | --- |
| 1 | 01-01 | 100 | 100 | 100 |
| 2 | 01-03 | 300 | **600** | 400 |
| 3 | 01-03 | 200 | 600 | 600 |
| 4 | 01-10 | 300 | 900 | 900 |

```sql
SUM(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id) AS running
```

> [!CAUTION]
> ❌ **`ORDER BY` không phân biệt được các dòng bằng nhau**
>
> Với `ORDER BY order_date`, đơn 2 ra tổng cộng dồn 600 thay vì 400. Khi có `ORDER BY`, khung mặc định là `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, và `RANGE` coi các dòng **cùng giá trị** `ORDER BY` là ngang hàng, nên cộng chúng vào cùng một lúc. Đơn 2 và đơn 3 cùng ngày, nên cả hai cùng nhận 100 + 300 + 200.
>
> → **Sửa:** thêm một cột phân định thứ tự để mỗi dòng có vị trí riêng: `ORDER BY order_date, order_id`. Hoặc ghi rõ khung `ROWS` (xem B3).

## B3. Khung: mỗi dòng nhìn thấy những dòng nào

**Ý tưởng:** khung (frame) chọn ra **tập dòng** mà hàm tính trên đó, tính từ dòng đang xét:
- `ROWS` đếm theo **số dòng**.
- `RANGE` lọc theo **giá trị** của cột `ORDER BY` (xem V2).
- `UNBOUNDED PRECEDING` là từ đầu nhóm, `CURRENT ROW` là dòng hiện tại, `1 PRECEDING` là dòng ngay trước.

Một vài khung hay dùng:
- Tổng cộng dồn: `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
- Các dòng **trước**, không tính dòng này: `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING`.
- Cửa sổ trượt 5 dòng, dòng hiện tại ở giữa: `ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING`.
- Cả nhóm (khi đã có `ORDER BY`): `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

**Ví dụ nhỏ:** đơn trung bình của các đơn **trước** đơn này.

| order_id | amount | earlier orders | avg_before |
| --- | --- | --- | --- |
| 1 | 100 | (none) | NULL |
| 2 | 300 | 100 | 100 |
| 3 | 200 | 100, 300 | 200 |
| 4 | 300 | 100, 300, 200 | 200 |

```sql
AVG(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id
                  ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS avg_before
```

Dòng đầu tiên có khung rỗng (không có dòng nào trước nó), nên `AVG` ra `NULL`.

> [!CAUTION]
> ❌ **Để khung mặc định khi cần "các đơn trước"**
>
> `AVG(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id)` dùng khung mặc định, kéo tới **chính dòng hiện tại**. Đơn 1 ra 100 thay vì `NULL`, đơn 4 ra 225 thay vì 200: mỗi đơn bị trung bình cùng với chính nó.
>
> → **Sửa:** ghi rõ khung `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING`.

## B4. Hàm: tính gì

**Ý tưởng:** có ba loại hàm:
- **Xếp hạng**: `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, `PERCENT_RANK`, `CUME_DIST`. Trả lời "dòng này đứng thứ mấy".
- **Lấy giá trị ở dòng khác**: `LAG` (dòng trước), `LEAD` (dòng sau), `FIRST_VALUE`, `LAST_VALUE`.
- **Tổng hợp trên khung**: `SUM`, `AVG`, `COUNT`, `MIN`, `MAX`.

**Ví dụ nhỏ:** các đơn của Alice, xếp hạng theo số tiền giảm dần.

| order_id | amount | `ROW_NUMBER` | `RANK` | `DENSE_RANK` |
| --- | --- | --- | --- | --- |
| 2 | 300 | 1 | 1 | 1 |
| 4 | 300 | 2 | 1 | 1 |
| 3 | 200 | 3 | **3** | **2** |
| 1 | 100 | 4 | 4 | 3 |

Đơn 2 và 4 cùng 300: `ROW_NUMBER` vẫn cho hai số khác nhau, `RANK` cho cùng hạng rồi bỏ qua hạng 2, `DENSE_RANK` cho cùng hạng và không bỏ hạng nào. Doc top-n giải thích khi nào dùng hàm nào.

```sql
SELECT order_id, customer, amount,
       ROW_NUMBER() OVER w AS rn, RANK() OVER w AS rnk, DENSE_RANK() OVER w AS drnk,
       LAG(amount)  OVER (PARTITION BY customer ORDER BY order_date, order_id) AS prev_amount,
       LEAD(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id) AS next_amount
FROM orders
WINDOW w AS (PARTITION BY customer ORDER BY amount DESC);
```

`WINDOW w AS (...)` đặt tên cho một cửa sổ để dùng lại nhiều lần. `LAG` ở dòng đầu và `LEAD` ở dòng cuối của nhóm ra `NULL`.

Hai hàm phân phối hay gặp:
- `NTILE(3) OVER (ORDER BY amount DESC, order_id)` chia các dòng thành 3 phần gần bằng nhau về số dòng, đánh số 1, 2, 3.
- `PERCENT_RANK() OVER (ORDER BY amount DESC)` là `(rank − 1) / (số dòng − 1)`, từ 0 (đầu) tới 1 (cuối).

> [!CAUTION]
> ❌ **`ROUND(PERCENT_RANK() OVER (...), 2)`**
>
> ```text
> ERROR:  function round(double precision, integer) does not exist
> ```
>
> `PERCENT_RANK` và `CUME_DIST` trả về kiểu `double precision`, còn `ROUND(x, số_chữ_số)` chỉ nhận `numeric`.
>
> → **Sửa:** `ROUND((PERCENT_RANK() OVER (...))::numeric, 2)`.

## B5. Lọc kết quả ở tầng ngoài

**Ý tưởng:** muốn giữ **đơn lớn nhất của mỗi khách** (`rn = 1`), ta phải lọc theo kết quả của hàm cửa sổ. Hàm cửa sổ chạy **sau** `WHERE`, nên không lọc được trong cùng câu. Tính ở truy vấn con hoặc CTE, rồi lọc ở tầng ngoài.

```sql
SELECT order_id, customer, amount
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer ORDER BY amount DESC, order_id) AS rn
  FROM orders
) t
WHERE rn = 1;
```

| order_id | customer | amount |
| --- | --- | --- |
| 2 | Alice | 300 |
| 6 | Ben | 150 |

Alice có hai đơn 300 (đơn 2 và 4). `order_id` trong `ORDER BY` quyết định đơn 2 đứng trước.

> [!CAUTION]
> ❌ **Lọc thẳng: `WHERE ROW_NUMBER() OVER (...) = 1`**
>
> ```text
> ERROR:  window functions are not allowed in WHERE
> ```
>
> `HAVING` cũng không dùng được, vì nó cũng chạy trước hàm cửa sổ.
>
> → **Sửa:** tính hàm cửa sổ trong truy vấn con hoặc CTE, rồi `WHERE rn = 1` ở tầng ngoài.

## Tổng kết: query đầy đủ

Một câu dùng cả 5 bước: tổng của khách, tổng cộng dồn, đơn trước, rồi giữ đơn lớn nhất của mỗi khách.

```sql
WITH per_order AS (
  SELECT order_id, customer, order_date, amount,
         SUM(amount) OVER (PARTITION BY customer) AS cust_total,                  -- B1
         SUM(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id    -- B2
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running,   -- B3
         LAG(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id) AS prev_amount,   -- B4
         ROW_NUMBER() OVER (PARTITION BY customer ORDER BY amount DESC, order_id) AS rn
  FROM orders
)
SELECT order_id, customer, amount, cust_total, running, prev_amount           -- B5: lọc ở tầng ngoài
FROM per_order
WHERE rn = 1
ORDER BY customer;
```

| order_id | customer | amount | cust_total | running | prev_amount |
| --- | --- | --- | --- | --- | --- |
| 2 | Alice | 300 | 900 | 400 | 100 |
| 6 | Ben | 150 | 200 | 200 | 50 |

---

# Phần 2: Biến thể

Mỗi biến thể dưới đây là một dạng bài hay gặp, dùng một trong năm bước ở Phần 1 theo cách dễ sai. Mỗi mục kể một tình huống, thử cách làm quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi lấy giá trị đầu và cuối của nhóm

Đề: với mỗi nhân viên, cho biết **ai lương cao nhất** và **ai lương thấp nhất** trong phòng. Nếu bằng lương, lấy tên đứng trước theo bảng chữ cái.

```text
employees (name, department, salary)   -- mới
```

| name | department | salary |
| --- | --- | --- |
| Alice | Engineering | 90 |
| Ben | Engineering | 70 |
| Chloe | Engineering | 90 |
| David | Engineering | 60 |
| Emma | Sales | 50 |
| Frank | Sales | 65 |

### Thử cách tự nhiên nhất

Xếp theo lương giảm dần: người đầu là cao nhất, người cuối là thấp nhất. Dùng `FIRST_VALUE` và `LAST_VALUE` trên cùng một thứ tự:

```sql
FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name) AS top_earner,
LAST_VALUE(name)  OVER (PARTITION BY department ORDER BY salary DESC, name) AS lowest_earner
```

| name | salary | top_earner | lowest_earner |
| --- | --- | --- | --- |
| Alice | 90 | Alice | <span class="drop">Alice</span> |
| Chloe | 90 | Alice | <span class="drop">Chloe</span> |
| Ben | 70 | Alice | <span class="drop">Ben</span> |
| David | 60 | Alice | David |

`top_earner` đúng, nhưng `lowest_earner` luôn là **chính người đang xét**. Lý do nằm ở khung mặc định (B3): khi có `ORDER BY`, khung chỉ chạy **từ đầu nhóm tới dòng hiện tại**. Với Alice, khung chỉ có mỗi Alice, nên "người cuối" là Alice. `FIRST_VALUE` không bị ảnh hưởng, vì đầu khung luôn là đầu nhóm.

### Cách sửa

Có hai cách. Cách thứ nhất là mở khung ra cả nhóm:

```sql
LAST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name
                       ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS lowest_earner
```

Cách thứ hai đơn giản hơn: đảo chiều sắp xếp, rồi dùng `FIRST_VALUE`. Người thấp nhất là người đầu tiên khi xếp tăng dần:

```sql
FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary ASC, name) AS lowest_earner
```

| name | department | salary | top_earner | lowest_earner |
| --- | --- | --- | --- | --- |
| Alice | Engineering | 90 | Alice | David |
| Chloe | Engineering | 90 | Alice | David |
| Ben | Engineering | 70 | Alice | David |
| David | Engineering | 60 | Alice | David |
| Frank | Sales | 65 | Frank | Emma |
| Emma | Sales | 50 | Frank | Emma |

Alice và Chloe cùng 90: `name` trong `ORDER BY` đưa Alice lên trước.

> [!TIP]
> **Ghi nhớ:** `LAST_VALUE` với khung mặc định luôn trả về dòng hiện tại. Mở khung `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, hoặc đảo chiều rồi dùng `FIRST_VALUE`.

## V2. Khi cửa sổ tính theo ngày lịch

Đề: với mỗi ngày có bán, tổng doanh thu của **7 ngày lịch** tính tới ngày đó (ngày đó và 6 ngày trước). Bảng chỉ có dòng cho ngày có bán, ngày không bán thì không có dòng.

```text
daily_sales (sale_date, revenue)   -- mới
```

| sale_date | revenue |
| --- | --- |
| 2024-03-01 | 10 |
| 2024-03-02 | 20 |
| 2024-03-05 | 30 |
| 2024-03-09 | 40 |
| 2024-03-10 | 50 |
| 2024-03-20 | 5 |

### Thử `ROWS 6 PRECEDING`

`SUM(revenue) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` cộng 6 **dòng** trước. Ngày 03-09 ra 100 (10 + 20 + 30 + 40), dù 03-01 và 03-02 đã cách hơn 6 ngày. Ngày 03-20 ra 155, trong khi 7 ngày trước nó (03-14 → 03-20) chỉ có đúng ngày 03-20. Dữ liệu thiếu ngày, nên "6 dòng trước" không phải "6 ngày trước".

### Cách sửa: `RANGE` với `INTERVAL`

`RANGE` lọc theo **giá trị** của cột `ORDER BY`. `RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW` lấy mọi dòng có `sale_date` nằm trong khoảng từ 6 ngày trước tới ngày hiện tại, bất kể có bao nhiêu dòng:

```sql
SELECT sale_date, revenue,
       SUM(revenue) OVER (ORDER BY sale_date
                          RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW) AS rolling_7d
FROM daily_sales
ORDER BY sale_date;
```

| sale_date | revenue | `ROWS 6 PRECEDING` | rolling_7d | days in window |
| --- | --- | --- | --- | --- |
| 2024-03-01 | 10 | 10 | 10 | 03-01 |
| 2024-03-02 | 20 | 30 | 30 | 03-01, 03-02 |
| 2024-03-05 | 30 | 60 | 60 | 03-01, 03-02, 03-05 |
| 2024-03-09 | 40 | <span class="drop">100</span> | 70 | 03-05, 03-09 |
| 2024-03-10 | 50 | <span class="drop">150</span> | 120 | 03-05, 03-09, 03-10 |
| 2024-03-20 | 5 | <span class="drop">155</span> | 5 | 03-20 |

> [!TIP]
> **Ghi nhớ:** "N dòng" thì dùng `ROWS`. "N ngày" (hay N tháng) khi dữ liệu có thể thiếu ngày thì dùng `RANGE BETWEEN INTERVAL '...' PRECEDING AND CURRENT ROW`.

## V3. Khi phát hiện giá trị thay đổi

Mỗi ngày hệ thống chụp lại giá của từng sản phẩm, và phần lớn các ngày giá không đổi. Có ngày giá bị trống (`NULL`) do lỗi đồng bộ. Đề: chỉ giữ những ngày giá **khác** ngày trước (`NULL` cũng tính là một giá trị), cộng với ngày đầu tiên của mỗi sản phẩm.

```text
price_snapshots (product, snap_date, price)   -- mới
```

| product | snap_date | price |
| --- | --- | --- |
| Latte | 2024-01-01 | 45 |
| Latte | 2024-01-02 | 45 |
| Latte | 2024-01-03 | NULL |
| Latte | 2024-01-04 | 48 |
| Latte | 2024-01-05 | 48 |
| Mocha | 2024-01-01 | 50 |
| Mocha | 2024-01-02 | 52 |

### Thử cách tự nhiên nhất

So giá hôm nay với giá hôm trước: `price <> LAG(price) OVER (PARTITION BY product ORDER BY snap_date)`.

| product | snap_date | old_price | new_price | `<>` |
| --- | --- | --- | --- | --- |
| Latte | 01-03 | 45 | NULL | <span class="drop">NULL</span> |
| Latte | 01-04 | NULL | 48 | <span class="drop">NULL</span> |
| Mocha | 01-02 | 50 | 52 | true |
| ... | | | | |

Giá Latte đổi từ 45 sang `NULL`, rồi từ `NULL` sang 48. Nhưng so sánh với `NULL` bằng `<>` cho ra `NULL`, không phải `true`, nên hai thay đổi này bị bỏ qua.

### Cách sửa: `IS DISTINCT FROM`

`a IS DISTINCT FROM b` giống `a <> b`, nhưng coi `NULL` là một giá trị bình thường: `45 IS DISTINCT FROM NULL` là `true`, `NULL IS DISTINCT FROM NULL` là `false`.

```sql
SELECT product, snap_date AS changed_on, old_price, new_price
FROM (
  SELECT product, snap_date, price AS new_price,
         LAG(price) OVER (PARTITION BY product ORDER BY snap_date) AS old_price,
         ROW_NUMBER() OVER (PARTITION BY product ORDER BY snap_date) AS rn
  FROM price_snapshots
) t
WHERE rn = 1 OR new_price IS DISTINCT FROM old_price
ORDER BY product, changed_on;
```

| product | changed_on | old_price | new_price |
| --- | --- | --- | --- |
| Latte | 2024-01-01 | NULL | 45 |
| Latte | 2024-01-03 | 45 | NULL |
| Latte | 2024-01-04 | NULL | 48 |
| Mocha | 2024-01-01 | NULL | 50 |
| Mocha | 2024-01-02 | 50 | 52 |

`rn = 1` giữ ngày đầu của mỗi sản phẩm một cách rõ ràng. Lọc phải đặt ở tầng ngoài, như B5.

> [!TIP]
> **Ghi nhớ:** so với dòng trước mà có thể có `NULL` thì dùng `x IS DISTINCT FROM LAG(x) OVER (...)`, không dùng `<>`.

## V4. Khi đếm số khách khác nhau cộng dồn

Đề: với mỗi ngày có đơn, có bao nhiêu **khách mới** (đơn đầu tiên rơi vào ngày đó), và tính tới ngày đó đã có bao nhiêu **khách khác nhau**?

```text
visits (order_date, customer)   -- mới
```

| order_date | customer |
| --- | --- |
| 2024-01-01 | Alice |
| 2024-01-01 | Alice |
| 2024-01-02 | Ben |
| 2024-01-02 | Alice |
| 2024-01-03 | Ben |
| 2024-01-04 | Chloe |
| 2024-01-04 | David |
| 2024-01-04 | Alice |

### Thử cách tự nhiên nhất

```sql
SELECT order_date, COUNT(DISTINCT customer) OVER (ORDER BY order_date) FROM visits;
```

```text
ERROR:  DISTINCT is not implemented for window functions
```

PostgreSQL không hỗ trợ `DISTINCT` bên trong hàm cửa sổ. Một cách vòng khác là đếm số khách khác nhau **mỗi ngày** rồi cộng dồn: ngày 01-04 ra 7. Nhưng Alice được đếm lại ở ngày 01-02 và 01-04, Ben được đếm lại ở ngày 01-03, trong khi thực tế chỉ có 4 khách.

### Cách sửa: chỉ đếm mỗi khách một lần, ở ngày đầu tiên

Mỗi khách chỉ "mới" đúng một lần, vào ngày mua đầu tiên. Đếm số khách có **ngày đầu tiên** rơi vào mỗi ngày, rồi cộng dồn con số đó. Tổng cộng dồn chính là số khách khác nhau tính tới ngày đó:

```sql
WITH firsts AS (                                   -- ngày đầu tiên của mỗi khách
  SELECT customer, MIN(order_date) AS first_date
  FROM visits
  GROUP BY customer
),
days AS (                                          -- mọi ngày có đơn
  SELECT DISTINCT order_date FROM visits
),
per_day AS (                                       -- số khách mới mỗi ngày
  SELECT d.order_date, COUNT(f.customer) AS new_customers
  FROM days d
  LEFT JOIN firsts f ON f.first_date = d.order_date
  GROUP BY d.order_date
)
SELECT order_date, new_customers,
       SUM(new_customers) OVER (ORDER BY order_date) AS cumulative_customers
FROM per_day
ORDER BY order_date;
```

| order_date | first-time customers | new_customers | cumulative_customers |
| --- | --- | --- | --- |
| 2024-01-01 | Alice | 1 | 1 |
| 2024-01-02 | Ben | 1 | 2 |
| 2024-01-03 | (none) | 0 | 2 |
| 2024-01-04 | Chloe, David | 2 | 4 |

`days` + `LEFT JOIN` giữ cả ngày 01-03, ngày không có khách mới nào.

> [!TIP]
> **Ghi nhớ:** `COUNT(DISTINCT ...) OVER` không chạy được. Số khách khác nhau cộng dồn = cộng dồn số khách **mới** (theo ngày đầu tiên của mỗi khách).

## V5. Khi so với tất cả các dòng trước

Hai đề hay gặp cùng cần nhìn **mọi dòng trước** dòng hiện tại, mà không tính chính nó.

### Tháng kỷ lục

Đề: một tháng là **kỷ lục** nếu doanh thu cao hơn **mọi tháng trước đó** (tháng đầu tiên luôn là kỷ lục).

```text
monthly_revenue (month, revenue)   -- mới
```

| month | revenue |
| --- | --- |
| 2024-01 | 200 |
| 2024-02 | 150 |
| 2024-03 | 250 |
| 2024-04 | 250 |
| 2024-05 | 300 |
| 2024-06 | 100 |

Cách nghĩ nhanh là so với `MAX(revenue) OVER (ORDER BY month)`. Nhưng khung mặc định gồm cả **chính tháng đó**, nên mức cao nhất luôn ≥ doanh thu tháng này, và `revenue > max` không bao giờ đúng. Phải loại dòng hiện tại khỏi khung:

```sql
SELECT month, revenue, previous_best
FROM (
  SELECT month, revenue,
         MAX(revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS previous_best
  FROM monthly_revenue
) t
WHERE previous_best IS NULL OR revenue > previous_best
ORDER BY month;
```

| month | revenue | previous_best | record? |
| --- | --- | --- | --- |
| 2024-01 | 200 | NULL | yes (first month) |
| 2024-02 | 150 | 200 | no |
| 2024-03 | 250 | 200 | **yes** |
| 2024-04 | 250 | 250 | no (equal, not higher) |
| 2024-05 | 300 | 250 | **yes** |
| 2024-06 | 100 | 300 | no |

### Những sản phẩm tạo ra 80% doanh thu

Đề: xếp sản phẩm theo doanh thu giảm dần. Cần những sản phẩm nào để đạt 80% tổng doanh thu?

| product | revenue | cumulative % (incl. this) | cumulative % before this |
| --- | --- | --- | --- |
| P | 400 | 40.0 | 0.0 |
| Q | 300 | 70.0 | 40.0 |
| R | 150 | 85.0 | 70.0 |
| S | 100 | 95.0 | 85.0 |
| T | 50 | 100.0 | 95.0 |

Cách nghĩ nhanh là giữ sản phẩm có tỉ lệ cộng dồn `<= 80`. Kết quả chỉ có P và Q, tổng mới 70%, chưa đạt 80%. Cần cả R: trước khi thêm R, mới có 70%, chưa đủ. Điều kiện đúng là: tỉ lệ cộng dồn **trước khi thêm sản phẩm này** còn dưới 80. Tỉ lệ đó tính bằng khung `... AND 1 PRECEDING`, giống tháng kỷ lục:

```sql
SELECT product, revenue, cumulative_pct
FROM (
  SELECT product, revenue,
         ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, product) / SUM(revenue) OVER (), 1) AS cumulative_pct,
         100.0 * COALESCE(SUM(revenue) OVER (ORDER BY revenue DESC, product
                                             ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0)
               / SUM(revenue) OVER () AS pct_before
  FROM product_sales
) t
WHERE pct_before < 80
ORDER BY revenue DESC, product;
```

Kết quả: P, Q, R. `COALESCE(..., 0)` cho sản phẩm đầu tiên, vì khung rỗng làm `SUM` ra `NULL`.

> [!TIP]
> **Ghi nhớ:** "so với mọi dòng trước, không tính dòng này" thì dùng khung `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING`. Dòng đầu có khung rỗng, nên nhớ xử lý `NULL`.

## V6. Khi xếp hạng trên kết quả đã gộp

Đề: tổng số lượng bán của mỗi sản phẩm **theo từng tháng**, rồi xếp hạng trong tháng bằng `DENSE_RANK`. Chỉ giữ hạng 1 và 2.

```text
sales (sale_date, product, qty)   -- mới
```

| sale_date | product | qty |
| --- | --- | --- |
| 2024-01-03 | Tea | 4 |
| 2024-01-15 | Tea | 6 |
| 2024-01-05 | Coffee | 10 |
| 2024-01-07 | Cocoa | 7 |
| 2024-02-01 | Tea | 3 |
| 2024-02-02 | Coffee | 5 |
| 2024-02-10 | Coffee | 4 |
| 2024-02-11 | Cocoa | 3 |

### Thử cách tự nhiên nhất

Xếp hạng thẳng trên từng dòng bán: `DENSE_RANK() OVER (PARTITION BY tháng ORDER BY qty DESC)`. Tháng 1, Tea có hai dòng (4 và 6) nên bị xếp riêng từng dòng: hạng 3 và hạng 4. Nhưng tổng của Tea là 10, bằng Coffee, nên lẽ ra phải đồng hạng 1.

### Cách sửa: hàm cửa sổ trên `GROUP BY`

Hàm cửa sổ chạy **sau** `GROUP BY`, nên có thể đặt một hàm gộp ngay bên trong nó: `ORDER BY SUM(qty) DESC`. `SUM(qty)` là tổng của mỗi (tháng, sản phẩm) sau khi gộp, và hàm cửa sổ xếp hạng các tổng đó:

```sql
SELECT month, product, total_qty, rank_in_month
FROM (
  SELECT TO_CHAR(DATE_TRUNC('month', sale_date), 'YYYY-MM') AS month, product,
         SUM(qty) AS total_qty,
         DENSE_RANK() OVER (PARTITION BY DATE_TRUNC('month', sale_date) ORDER BY SUM(qty) DESC) AS rank_in_month
  FROM sales
  GROUP BY DATE_TRUNC('month', sale_date), product
) t
WHERE rank_in_month <= 2
ORDER BY month, rank_in_month, product;
```

| month | product | total_qty | rank_in_month |
| --- | --- | --- | --- |
| 2024-01 | Coffee | 10 | 1 |
| 2024-01 | Tea | 10 | 1 |
| 2024-01 | Cocoa | 7 | 2 |
| 2024-02 | Coffee | 9 | 1 |
| 2024-02 | Cocoa | 3 | 2 |
| 2024-02 | Tea | 3 | 2 |

Cùng cách đó, `SUM(SUM(qty)) OVER (PARTITION BY ...)` cộng các tổng đã gộp lại thành tổng của nhóm lớn hơn (xem V2 của doc kpi-report).

> [!TIP]
> **Ghi nhớ:** muốn xếp hạng các nhóm thì `GROUP BY` trước, và đặt hàm gộp bên trong cửa sổ: `RANK() OVER (ORDER BY SUM(x) DESC)`.
