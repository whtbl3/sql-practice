# Cohort / Retention

> Bài liên quan: `cohort/01`, `03`, `04`. Output đều chạy thật bằng `check.py`.

## Bài toán

Cửa hàng muốn biết khách mới có quay lại không. Cụ thể: **khách mua lần đầu trong tháng X, sau 1, 2, 3 tháng còn bao nhiêu phần trăm quay lại mua?**

Nhóm khách cùng bắt đầu trong một tháng gọi là một **cohort**. Ví dụ "cohort 2023-12" là những khách có đơn đầu tiên trong tháng 12/2023. Retention là tỉ lệ khách của cohort còn mua lại ở các tháng sau.

Không đếm thẳng "tháng 3 có bao nhiêu khách mua" được. Lý do là con số đó trộn lẫn khách cũ của nhiều cohort khác nhau, nên không biết khách mới của tháng nào đang ở lại.

## Dữ liệu

Hai bảng, quan hệ **1 khách – nhiều đơn** (`orders.customer_id` → `customers.customer_id`).

`customers`: mỗi dòng = 1 khách. Cột `signup_date` chỉ dùng ở V1.

| customer_id | name | signup_date |
| --- | --- | --- |
| 1 | Alice | 2023-12-01 |
| 2 | Ben | 2024-01-05 |
| 3 | Chloe | 2023-12-15 |
| 4 | David | 2024-01-02 |
| 5 | Emma | 2024-01-10 |
| 6 | Frank | 2024-01-20 |

`orders`: mỗi dòng = 1 đơn.

| order_id | customer_id | order_date |
| --- | --- | --- |
| 1 | 1 | 2023-12-03 |
| 2 | 2 | 2023-12-10 |
| 3 | 1 | 2023-12-20 |
| 4 | 3 | 2023-12-28 |
| 5 | 4 | 2024-01-09 |
| 6 | 1 | 2024-01-15 |
| 7 | 5 | 2024-01-22 |
| 8 | 4 | 2024-01-30 |
| 9 | 4 | 2024-02-14 |
| 10 | 1 | 2024-03-02 |
| 11 | 2 | 2024-03-08 |
| 12 | 5 | 2024-03-18 |

Ba chỗ dễ sai: Alice mua **2 đơn trong cùng tháng 12**, khoảng cách từ tháng 12/2023 sang 2024 **vượt qua năm mới**, và Frank **chưa mua đơn nào**.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Gom đơn về (khách, tháng) | CTE `customer_months` | 1 khách × 1 tháng có mua |
| B2 | Tìm cohort của mỗi khách | CTE `with_cohort` | như trên, thêm cột cohort |
| B3 | Tính tháng thứ mấy kể từ cohort | CTE `with_offset` | như trên, thêm cột offset |
| B4 | Đếm khách theo (cohort, offset) | CTE `activity` | **1 cohort × 1 offset** |
| B5 | Chia cho số khách của cohort | query cuối | 1 cohort × 1 offset, thêm % |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Gom đơn về (khách, tháng) (CTE `customer_months`)

**Ý tưởng:** retention chỉ hỏi khách **có mua** trong một tháng hay không, không quan tâm mua mấy đơn. Vì vậy ta đổi mỗi đơn thành tháng của nó, rồi bỏ các dòng trùng.

**Ví dụ nhỏ:** Alice có 2 đơn trong tháng 12, sau bước này chỉ còn 1 dòng.

| order_id | customer | order_date | order_month | reason |
| --- | --- | --- | --- | --- |
| 1 | Alice | 2023-12-03 | 2023-12-01 | kept |
| 3 | Alice | 2023-12-20 | 2023-12-01 | <span class="drop">same month as order 1, merged</span> |
| 6 | Alice | 2024-01-15 | 2024-01-01 | kept |
| 10 | Alice | 2024-03-02 | 2024-03-01 | kept |

→

| customer_id | order_month |
| --- | --- |
| 1 | 2023-12-01 |
| 1 | 2024-01-01 |
| 1 | 2024-03-01 |
| ... | |

```sql
WITH customer_months AS (
  SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
  FROM orders
)
```

`DATE_TRUNC('month', ...)` đưa mọi ngày về ngày đầu tháng: 2023-12-20 thành 2023-12-01. `::date` giữ kết quả ở kiểu ngày để bước sau còn tính toán được.

> [!CAUTION]
> ❌ **Dùng `TO_CHAR(order_date, 'YYYY-MM')` để lấy tháng**
>
> `TO_CHAR` trả về chuỗi `'2023-12'`, không phải ngày. Bước B3 cần lấy năm và tháng ra để trừ, mà một chuỗi thì không làm vậy được.
>
> → **Sửa:** dùng `DATE_TRUNC` ở các bước tính toán. Chỉ dùng `TO_CHAR` ở `SELECT` cuối cùng, khi cần hiển thị dạng `'YYYY-MM'`.

## B2. Tìm cohort của mỗi khách (CTE `with_cohort`)

**Ý tưởng:** cohort của một khách là tháng mua **đầu tiên**, tức tháng nhỏ nhất trong các dòng của khách đó. Mọi dòng của khách đều cần biết giá trị này, vì B3 sẽ so từng tháng với nó.

**Ví dụ nhỏ:** cả 3 dòng của Alice đều nhận cohort 2023-12.

| customer_id | order_month | cohort_month |
| --- | --- | --- |
| 1 (Alice) | 2023-12-01 | 2023-12-01 |
| 1 (Alice) | 2024-01-01 | 2023-12-01 |
| 1 (Alice) | 2024-03-01 | 2023-12-01 |
| 4 (David) | 2024-01-01 | 2024-01-01 |
| 4 (David) | 2024-02-01 | 2024-01-01 |
| ... | | |

```sql
with_cohort AS (
  SELECT customer_id, order_month,
         MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
  FROM customer_months
)
```

`MIN(...) OVER (PARTITION BY customer_id)` tìm tháng nhỏ nhất trong các dòng của cùng một khách, rồi ghi kết quả lên **từng dòng** của khách đó. Số dòng không đổi.

> [!CAUTION]
> ❌ **Dùng `GROUP BY customer_id` với `MIN(order_month)`**
>
> `GROUP BY` gộp 3 dòng của Alice thành 1 dòng. Ta có được cohort của Alice, nhưng mất các tháng 2024-01 và 2024-03, nên không còn gì để đếm retention.
>
> → **Sửa:** dùng `MIN(...) OVER (PARTITION BY customer_id)`. Hàm này tính giống `MIN` nhưng giữ nguyên mọi dòng.

## B3. Tính tháng thứ mấy kể từ cohort (CTE `with_offset`)

**Ý tưởng:** với mỗi dòng, tính xem tháng mua cách tháng cohort bao nhiêu tháng. Cách tháng cohort 0 tháng là chính tháng cohort, 1 là tháng ngay sau... Số này gọi là `month_offset`. Để trừ hai tháng nằm ở hai năm khác nhau, ta đổi mỗi tháng thành một con số đếm liên tục: `năm × 12 + tháng`.

**Ví dụ nhỏ:**

| customer | cohort_month | order_month | month_offset |
| --- | --- | --- | --- |
| Alice | 2023-12 | 2023-12 | 0 |
| Alice | 2023-12 | 2024-01 | (2024×12 + 1) − (2023×12 + 12) = 1 |
| Alice | 2023-12 | 2024-03 | (2024×12 + 3) − (2023×12 + 12) = 3 |
| ... | | | |

```sql
with_offset AS (
  SELECT customer_id, cohort_month, order_month,
         (EXTRACT(YEAR FROM order_month)::int  * 12 + EXTRACT(MONTH FROM order_month)::int)
       - (EXTRACT(YEAR FROM cohort_month)::int * 12 + EXTRACT(MONTH FROM cohort_month)::int) AS month_offset
  FROM with_cohort
)
```

> [!CAUTION]
> ❌ **Chỉ trừ số tháng: `EXTRACT(MONTH FROM order_month) - EXTRACT(MONTH FROM cohort_month)`**
>
> Alice có cohort tháng 12/2023 và mua lại tháng 1/2024. Phép trừ này ra 1 − 12 = −11, trong khi thực ra chỉ cách nhau 1 tháng. Lỗi xảy ra vì cách tính này bỏ qua năm.
>
> → **Sửa:** đổi cả hai tháng thành `năm × 12 + tháng` rồi mới trừ.

## B4. Đếm khách theo (cohort, offset) (CTE `activity`)

**Ý tưởng:** gom các dòng cùng cohort và cùng offset lại, rồi đếm xem có bao nhiêu khách.

**Ví dụ nhỏ:** cohort 2023-12 có 3 khách (Alice, Ben, Chloe).

| cohort_month | month_offset | customers who bought | active_customers |
| --- | --- | --- | --- |
| 2023-12 | 0 | Alice, Ben, Chloe | 3 |
| 2023-12 | 1 | Alice | 1 |
| 2023-12 | 3 | Alice, Ben | 2 |
| ... | | | |

Cohort 2023-12 không có dòng offset 2, vì trong tháng 2/2024 không ai của cohort này mua. `GROUP BY` chỉ tạo ra nhóm có dữ liệu.

```sql
activity AS (
  SELECT cohort_month, month_offset, COUNT(DISTINCT customer_id) AS active_customers
  FROM with_offset
  GROUP BY cohort_month, month_offset
)
```

> [!CAUTION]
> ❌ **Bỏ `DISTINCT` ở B1 rồi đếm bằng `COUNT(*)`**
>
> Alice có 2 đơn trong tháng 12, nên có 2 dòng ở (2023-12, offset 0). `COUNT(*)` đếm dòng, nên ô này ra 4 thay vì 3 khách.
>
> → **Sửa:** giữ `DISTINCT` ở B1, và đếm bằng `COUNT(DISTINCT customer_id)` để chắc chắn mỗi khách chỉ được đếm một lần.

## B5. Chia cho số khách của cohort (query cuối)

**Ý tưởng:** retention = số khách có mua ở offset đó ÷ số khách của cả cohort. Số khách của cohort chính là ô offset 0, vì theo định nghĩa ở B2, mọi khách đều mua ở tháng cohort của mình. `FIRST_VALUE(...) OVER (PARTITION BY cohort_month ORDER BY month_offset)` lấy giá trị của dòng đầu tiên trong cohort, tức dòng offset 0, và ghi nó lên mọi dòng của cohort đó.

**Ví dụ nhỏ:** cohort 2023-12 có 3 khách.

| cohort_month | month_offset | active_customers | cohort size | retention_pct |
| --- | --- | --- | --- | --- |
| 2023-12 | 0 | 3 | 3 | 100.0 |
| 2023-12 | 1 | 1 | 3 | 33.3 = 100 × 1 / 3 |
| 2023-12 | 3 | 2 | 3 | 66.7 = 100 × 2 / 3 |
| ... | | | | |

```sql
SELECT TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month, month_offset, active_customers,
       ROUND(100.0 * active_customers
             / FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1) AS retention_pct
FROM activity
ORDER BY cohort_month, month_offset;
```

> [!CAUTION]
> ❌ **Chia hai số nguyên: `active_customers / FIRST_VALUE(...) * 100`**
>
> Cả hai số đều là số nguyên, nên PostgreSQL chia lấy phần nguyên: 1 / 3 = 0, rồi 0 × 100 = 0. Mọi ô trừ offset 0 đều ra 0%.
>
> → **Sửa:** đặt `100.0 *` lên **đầu** phép tính. `100.0` là số thập phân, nên cả phép chia thành chia số thập phân.
>
> ---
>
> ❌ **Dùng `FIRST_VALUE` khi cohort không lấy từ đơn đầu tiên**
>
> Cách lấy số khách từ ô offset 0 chỉ đúng khi mọi khách đều chắc chắn mua ở tháng cohort. Nếu cohort là tháng **đăng ký**, sẽ có khách đăng ký mà không mua gì, và ô offset 0 đếm thiếu họ.
>
> → **Sửa:** đếm số khách của cohort từ chính bảng định nghĩa cohort. Xem V1.

## Tổng kết: query đầy đủ

```sql
WITH customer_months AS (                          -- B1: (khách, tháng có mua)
  SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
  FROM orders
),
with_cohort AS (                                   -- B2: cohort = tháng mua đầu tiên
  SELECT customer_id, order_month,
         MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
  FROM customer_months
),
with_offset AS (                                   -- B3: tháng thứ mấy kể từ cohort
  SELECT customer_id, cohort_month, order_month,
         (EXTRACT(YEAR FROM order_month)::int  * 12 + EXTRACT(MONTH FROM order_month)::int)
       - (EXTRACT(YEAR FROM cohort_month)::int * 12 + EXTRACT(MONTH FROM cohort_month)::int) AS month_offset
  FROM with_cohort
),
activity AS (                                      -- B4: số khách mỗi (cohort, offset)
  SELECT cohort_month, month_offset, COUNT(DISTINCT customer_id) AS active_customers
  FROM with_offset
  GROUP BY cohort_month, month_offset
)
SELECT TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month, month_offset, active_customers,   -- B5
       ROUND(100.0 * active_customers
             / FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1) AS retention_pct
FROM activity
ORDER BY cohort_month, month_offset;
```

| cohort_month | month_offset | active_customers | retention_pct |
| --- | --- | --- | --- |
| 2023-12 | 0 | 3 | 100.0 |
| 2023-12 | 1 | 1 | 33.3 |
| 2023-12 | 3 | 2 | 66.7 |
| 2024-01 | 0 | 2 | 100.0 |
| 2024-01 | 1 | 1 | 50.0 |
| 2024-01 | 2 | 1 | 50.0 |

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính: cohort lấy theo ngày đăng ký thay vì đơn đầu tiên, hoặc chỉ số đo không phải retention theo tháng mà là "có mua lại trong 30 ngày không". Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

Có một thay đổi nhỏ không cần mục riêng. Nếu đề tính cohort theo **tuần** hay **quý**, chỉ cần đổi `'month'` trong `DATE_TRUNC` thành `'week'` hay `'quarter'`, và đổi cách tính offset cho hợp. Ví dụ với tuần, lấy hiệu hai ngày chia 7: `(order_week - cohort_week) / 7`.

## V1. Khi cohort là tháng đăng ký

Ở Phần 1, cohort của khách là tháng mua đơn đầu tiên. Nhưng nhiều đề định nghĩa cohort là tháng khách **đăng ký** tài khoản, lấy từ cột `signup_date` của bảng `customers`:

```text
customers (customer_id, name, signup_date)   -- signup_date giờ mới được dùng
orders    (order_id, customer_id, order_date)
```

| customer | signup_date | cohort |
| --- | --- | --- |
| Alice | 2023-12-01 | 2023-12 |
| Chloe | 2023-12-15 | 2023-12 |
| Ben | 2024-01-05 | 2024-01 |
| David | 2024-01-02 | 2024-01 |
| Emma | 2024-01-10 | 2024-01 |
| Frank | 2024-01-20 | 2024-01 |

Thay đổi này nghe nhỏ, nhưng làm vỡ hai giả định mà mạch chính đang dựa vào.

### Giả định 1: không có đơn nào trước cohort

Ben đăng ký tháng 1/2024, nhưng đã mua đơn 2 vào 2023-12-10, trước cả khi có tài khoản (ví dụ mua không cần đăng nhập). Nếu nối `customers` với các tháng có mua rồi tính offset như B3, Ben có một dòng với offset **−1**:

| customer | cohort_month | order_month | month_offset |
| --- | --- | --- | --- |
| Ben | 2024-01 | 2023-12 | **−1** |

Retention không có nghĩa ở tháng trước cohort, nên ta bỏ những dòng này đi bằng điều kiện `order_month >= cohort_month`.

### Giả định 2: offset 0 đếm đủ cả cohort

Đây là chỗ khó thấy hơn. Ở B5, ta lấy số khách của cohort từ ô offset 0 bằng `FIRST_VALUE`. Cách đó đúng vì ở Phần 1, mọi khách đều mua ở tháng cohort của mình. Với cohort đăng ký thì không còn như vậy. Cohort 2024-01 có 4 người đăng ký (Ben, David, Emma, Frank), nhưng tháng 1 chỉ có David và Emma mua. Ben chỉ mua lại vào tháng 3, còn Frank chưa mua gì.

Thử giữ nguyên `FIRST_VALUE` và chạy:

| cohort_month | month_offset | active_customers | retention_pct |
| --- | --- | --- | --- |
| 2024-01 | 0 | 2 | **100.0** |
| 2024-01 | 1 | 1 | **50.0** |
| 2024-01 | 2 | 2 | **100.0** |

Kết quả nói cohort 2024-01 giữ được 100% khách ở tháng thứ 2, trong khi thực ra chỉ 2 trên 4 người mua. Mẫu số đã bị lấy là 2 (số người mua ở tháng 1) thay vì 4 (số người đăng ký).

### Cách sửa: đếm cohort từ bảng định nghĩa nó

Số khách của cohort phải đếm từ chính bảng định nghĩa cohort, tức `customers`, chứ không phải từ các đơn hàng:

| cohort_month | cohort_customers |
| --- | --- |
| 2023-12 | 2 (Alice, Chloe) |
| 2024-01 | 4 (Ben, David, Emma, Frank) |

Ghép cả hai cách sửa lại, các CTE từ B2 trở đi viết lại như sau. `customer_months` ở B1 giữ nguyên.

```sql
cohorts AS (                                                         -- mới: cohort từ ngày đăng ký
  SELECT customer_id, DATE_TRUNC('month', signup_date)::date AS cohort_month
  FROM customers
),
cohort_size AS (                                                     -- mới: số khách mỗi cohort
  SELECT cohort_month, COUNT(*) AS cohort_customers
  FROM cohorts
  GROUP BY cohort_month
),
with_offset AS (
  SELECT c.customer_id, c.cohort_month, m.order_month,
         (EXTRACT(YEAR FROM m.order_month)::int  * 12 + EXTRACT(MONTH FROM m.order_month)::int)
       - (EXTRACT(YEAR FROM c.cohort_month)::int * 12 + EXTRACT(MONTH FROM c.cohort_month)::int) AS month_offset
  FROM cohorts c
  JOIN customer_months m ON m.customer_id = c.customer_id
  WHERE m.order_month >= c.cohort_month                              -- mới: bỏ đơn trước cohort
),
activity AS (
  SELECT cohort_month, month_offset, COUNT(DISTINCT customer_id) AS active_customers
  FROM with_offset
  GROUP BY cohort_month, month_offset
)
SELECT TO_CHAR(a.cohort_month, 'YYYY-MM') AS cohort_month, a.month_offset, a.active_customers,
       ROUND(100.0 * a.active_customers / s.cohort_customers, 1) AS retention_pct   -- mới
FROM activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month                -- mới
ORDER BY a.cohort_month, a.month_offset;
```

| cohort_month | month_offset | active_customers | retention_pct |
| --- | --- | --- | --- |
| 2023-12 | 0 | 2 | 100.0 |
| 2023-12 | 1 | 1 | 50.0 |
| 2023-12 | 3 | 1 | 50.0 |
| 2024-01 | 0 | 2 | **50.0** |
| 2024-01 | 1 | 1 | **25.0** |
| 2024-01 | 2 | 2 | **50.0** |

Cohort 2024-01 giờ chia cho 4 người. Frank không mua gì nên không xuất hiện ở ô nào, nhưng vẫn được tính trong mẫu số. Đó chính là điều đề muốn.

> [!TIP]
> **Ghi nhớ:** cohort lấy từ đâu thì đếm số khách của cohort từ đó. Chỉ dùng `FIRST_VALUE` ở offset 0 khi cohort được định nghĩa bằng chính hoạt động đang đếm.

## V2. Khi đo "mua lại trong 30 ngày"

Đề không hỏi retention theo từng tháng, mà hỏi: **trong mỗi cohort, bao nhiêu phần trăm khách mua đơn thứ hai trong vòng 30 ngày sau đơn đầu tiên?** Cohort vẫn là tháng của đơn đầu tiên như Phần 1.

Chỉ số này cần hai ngày của mỗi khách: ngày đơn thứ nhất và ngày đơn thứ hai.

### Thử cách tự nhiên nhất

Ngày đơn thứ nhất là `MIN(order_date)`. Cách nghĩ nhanh nhất cho ngày đơn sau là `MAX(order_date)`:

```sql
SELECT customer_id, MIN(order_date) AS first_date, MAX(order_date) AS second_date
FROM orders
GROUP BY customer_id
```

| customer | first_date | `MAX(order_date)` | days | should be |
| --- | --- | --- | --- | --- |
| Alice | 2023-12-03 | 2024-03-02 | 90 | 17 (2nd order on 12-20) |
| Chloe | 2023-12-28 | 2023-12-28 | **0** | no 2nd order |
| David | 2024-01-09 | 2024-02-14 | 36 | 21 (2nd order on 01-30) |
| ... | | | | |

Có hai lỗi. `MAX` cho ra đơn **cuối cùng**, không phải đơn thứ hai, nên Alice và David, vốn mua lại rất nhanh, lại bị tính là quá 30 ngày. Còn Chloe chỉ có một đơn, nên `MAX` và `MIN` là cùng một ngày, cách nhau 0 ngày. Chloe bị tính là "mua lại trong 30 ngày" dù chưa hề mua lại.

### Cách sửa: đánh số đơn

Muốn lấy đúng đơn thứ hai, ta đánh số các đơn của mỗi khách theo thứ tự thời gian bằng `ROW_NUMBER`:

| customer | order_id | order_date | rn |
| --- | --- | --- | --- |
| Alice | 1 | 2023-12-03 | 1 |
| Alice | 3 | 2023-12-20 | 2 |
| Alice | 6 | 2024-01-15 | 3 |
| Alice | 10 | 2024-03-02 | 4 |
| Chloe | 4 | 2023-12-28 | 1 |
| ... | | | |

Đơn thứ nhất là dòng `rn = 1`, đơn thứ hai là dòng `rn = 2`. Để đưa hai ngày này lên cùng một dòng, ta `GROUP BY customer_id` và dùng `MAX(order_date) FILTER (WHERE rn = 2)`, nghĩa là "lấy `order_date` của dòng có `rn = 2`". Mỗi khách có nhiều nhất một dòng như vậy, nên `MAX` không chọn gì cả, nó chỉ có mặt vì `GROUP BY` cần một hàm gộp. Khách chỉ có một đơn thì không có dòng `rn = 2`, và nhận `NULL`.

```sql
WITH numbered AS (
  SELECT customer_id, order_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn
  FROM orders
),
first_two AS (
  SELECT customer_id,
         MAX(order_date) FILTER (WHERE rn = 1) AS first_date,
         MAX(order_date) FILTER (WHERE rn = 2) AS second_date
  FROM numbered
  GROUP BY customer_id
)
SELECT TO_CHAR(DATE_TRUNC('month', first_date), 'YYYY-MM') AS cohort_month,
       COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE second_date - first_date <= 30) AS repeaters,
       ROUND(100.0 * COUNT(*) FILTER (WHERE second_date - first_date <= 30) / COUNT(*), 1) AS repeat_rate_pct
FROM first_two
GROUP BY 1
ORDER BY 1;
```

`ORDER BY order_date, order_id` trong `ROW_NUMBER`: nếu hai đơn cùng ngày, `order_id` quyết định đơn nào là đơn thứ nhất. Nhờ vậy kết quả luôn cố định.

Sau `first_two`, mỗi khách một dòng:

| customer | first_date | second_date | second_date − first_date |
| --- | --- | --- | --- |
| Alice | 2023-12-03 | 2023-12-20 | 17 |
| Ben | 2023-12-10 | 2024-03-08 | 89 |
| Chloe | 2023-12-28 | NULL | NULL |
| David | 2024-01-09 | 2024-01-30 | 21 |
| Emma | 2024-01-22 | 2024-03-18 | 56 |

Chloe có hiệu là `NULL`, và `NULL <= 30` không ra `true`. Vì vậy Chloe tự bị loại khỏi tử số `repeaters`, nhưng vẫn nằm trong mẫu số `COUNT(*)`. Đó đúng là điều ta muốn: Chloe là một khách của cohort, chỉ là chưa mua lại.

| cohort_month | customers | repeaters | repeat_rate_pct |
| --- | --- | --- | --- |
| 2023-12 | 3 | 1 (Alice) | 33.3 |
| 2024-01 | 2 | 1 (David) | 50.0 |

> [!TIP]
> **Ghi nhớ:** cần "đơn thứ k" thì đánh số bằng `ROW_NUMBER`, rồi `MAX(...) FILTER (WHERE rn = k)`. `MAX(order_date)` là đơn cuối cùng, không phải đơn thứ hai.
