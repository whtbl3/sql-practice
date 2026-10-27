# Báo cáo chỉ số (KPI, dashboard)

> Bài liên quan: `misc/01`, `02`, `03`, `05`. Output đều chạy thật bằng `check.py`.

## Bài toán

Ban giám đốc muốn một bảng báo cáo **mỗi tháng một dòng**: doanh thu, số đơn, số khách, số khách mới, giá trị đơn trung bình (AOV), % đạt chỉ tiêu, % tăng giảm so với tháng trước, doanh thu cộng dồn, và tỉ trọng của tháng trong tổng.

Viết tất cả trong một câu `SELECT` duy nhất rất dễ sai, vì các chỉ số nằm ở **các mức chi tiết khác nhau**:
- Doanh thu tính trên từng **đơn**.
- Khách mới phải biết tháng mua đầu tiên của từng **khách**.
- Chỉ tiêu có sẵn theo từng **tháng**.
- So với tháng trước thì phải nhìn sang **dòng khác**.

Cách làm đúng là mỗi CTE làm một việc, và đưa mọi thứ về cùng một mức chi tiết (gọi là **grain**, ở đây là "một dòng mỗi tháng") trước khi so sánh giữa các dòng.

## Dữ liệu

`orders`: mỗi dòng = 1 đơn. Chỉ đơn `Completed` được tính.

| order_id | customer_id | order_date | amount | status |
| --- | --- | --- | --- | --- |
| 1 | 1 (Alice) | 2024-01-05 | 100 | Completed |
| 2 | 2 (Ben) | 2024-01-12 | 50 | Completed |
| 3 | 1 (Alice) | 2024-01-25 | 30 | Completed |
| 4 | 3 (Chloe) | 2024-01-28 | 70 | Cancelled |
| 5 | 1 (Alice) | 2024-02-10 | 60 | Completed |
| 6 | 3 (Chloe) | 2024-02-14 | 40 | Completed |
| 7 | 2 (Ben) | 2024-04-03 | 90 | Completed |
| 8 | 4 (David) | 2024-04-15 | 110 | Completed |
| 9 | 4 (David) | 2024-04-20 | 50 | Completed |

`targets`: mỗi dòng = chỉ tiêu doanh thu của 1 tháng.

| month | target |
| --- | --- |
| 2024-01-01 | 150 |
| 2024-02-01 | 150 |
| 2024-03-01 | 100 |
| 2024-04-01 | 200 |

Hai chỗ dễ sai: đơn tháng 1 của Chloe **đã bị hủy**, và **tháng 3 không có đơn nào**.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Lọc đơn hợp lệ, gắn tháng | CTE `clean` | 1 đơn hợp lệ |
| B2 | Gộp về một dòng mỗi tháng | CTE `first_month`, `monthly` | **1 tháng có đơn** |
| B3 | Lấp các tháng trống | CTE `months`, `full_m` | **1 tháng**, kể cả tháng trống |
| B4 | Chỉ số trong cùng một dòng | query cuối (AOV, % chỉ tiêu) | 1 tháng |
| B5 | Chỉ số so với dòng khác | query cuối (% so tháng trước, cộng dồn, tỉ trọng) | 1 tháng |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Lọc đơn hợp lệ, gắn tháng (CTE `clean`)

**Ý tưởng:** bỏ đơn bị hủy **ngay từ đầu**, vì mọi bước sau (doanh thu, số đơn, tháng mua đầu tiên...) đều dựa trên tập đơn này. Mỗi đơn mang thêm tháng của nó.

**Ví dụ nhỏ:**

| order_id | customer | order_date | status | reason |
| --- | --- | --- | --- | --- |
| 3 | Alice | 2024-01-25 | Completed | kept, month 2024-01 |
| 4 | Chloe | 2024-01-28 | Cancelled | <span class="drop">cancelled, removed</span> |
| 6 | Chloe | 2024-02-14 | Completed | kept, month 2024-02 |
| ... | | | | |

```sql
WITH clean AS (
  SELECT order_id, customer_id, amount, DATE_TRUNC('month', order_date)::date AS month
  FROM orders
  WHERE status = 'Completed'
)
```

> [!CAUTION]
> ❌ **Tìm tháng mua đầu tiên từ bảng `orders` gốc**
>
> Đơn bị hủy tháng 1 của Chloe vẫn được tính, nên tháng mua đầu tiên của Chloe ra **2024-01**, và Chloe bị đếm là khách mới của tháng 1. Thực ra đơn hợp lệ đầu tiên của Chloe là tháng 2.
>
> → **Sửa:** mọi phép tính sau đều đọc từ `clean`, không đọc lại `orders`.

## B2. Gộp về một dòng mỗi tháng (CTE `first_month`, `monthly`)

**Ý tưởng:** `GROUP BY month` để có một dòng mỗi tháng. Riêng số khách mới cần biết tháng mua đầu tiên của từng khách. Ta tính nó ở một CTE riêng có **một dòng mỗi khách**, rồi mới nối vào. Vì mỗi khách chỉ có một dòng, việc nối không làm nhân đơn hàng.

**Ví dụ nhỏ:** tháng 2.

| order | customer | amount | first_month of customer | new this month? |
| --- | --- | --- | --- | --- |
| 5 | Alice | 60 | 2024-01 | no |
| 6 | Chloe | 40 | 2024-02 | yes |

→ tháng 2: revenue 100, orders 2, customers 2, new_customers 1.

```sql
first_month AS (
  SELECT customer_id, MIN(month) AS first_month
  FROM clean
  GROUP BY customer_id
),
monthly AS (
  SELECT c.month,
         SUM(c.amount)                 AS revenue,
         COUNT(*)                      AS orders,
         COUNT(DISTINCT c.customer_id) AS customers,
         COUNT(DISTINCT c.customer_id) FILTER (WHERE c.month = f.first_month) AS new_customers
  FROM clean c
  JOIN first_month f USING (customer_id)
  GROUP BY c.month
)
```

`COUNT(*)` đếm đơn. `COUNT(DISTINCT customer_id)` đếm khách: Alice có 2 đơn tháng 1 nhưng chỉ tính là 1 khách.

> [!CAUTION]
> ❌ **Nối `targets` vào từng đơn, rồi mới `SUM(target)`**
>
> Tháng 1 có 3 đơn hợp lệ, nên chỉ tiêu 150 của tháng 1 bị lặp lại 3 lần, và `SUM(target)` ra 450.
>
> → **Sửa:** chỉ nối bảng ở mức tháng (`targets`) **sau khi** đã gộp về một dòng mỗi tháng.

## B3. Lấp các tháng trống (CTE `months`, `full_m`)

**Ý tưởng:** tháng 3 không có đơn nào nên không có dòng trong `monthly`. Ta tạo danh sách **mọi tháng** bằng `generate_series`, rồi `LEFT JOIN` `monthly` vào. Tháng không có dữ liệu nhận `NULL`, và `COALESCE` đổi thành 0.

**Ví dụ nhỏ:**

| month | in `monthly`? | revenue after fill |
| --- | --- | --- |
| 2024-02 | yes | 100 |
| 2024-03 | **no** | 0 |
| 2024-04 | yes | 250 |
| ... | | |

```sql
months AS (
  SELECT generate_series(MIN(month), MAX(month), INTERVAL '1 month')::date AS month
  FROM clean
),
full_m AS (
  SELECT m.month,
         COALESCE(mo.revenue, 0)       AS revenue,
         COALESCE(mo.orders, 0)        AS orders,
         COALESCE(mo.customers, 0)     AS customers,
         COALESCE(mo.new_customers, 0) AS new_customers
  FROM months m
  LEFT JOIN monthly mo USING (month)
)
```

> [!CAUTION]
> ❌ **Bỏ qua bước này, tính `LAG` thẳng trên `monthly`**
>
> `LAG(revenue)` lấy doanh thu của **dòng** trước, không phải **tháng** trước. Trong `monthly`, dòng trước tháng 4 là tháng 2, vì tháng 3 không có dòng. Tháng 4 bị so với 100 (tháng 2) thay vì 0 (tháng 3), và báo cáo không có dòng nào cho tháng 3.
>
> → **Sửa:** lấp đủ các tháng **trước khi** dùng `LAG`.

## B4. Chỉ số trong cùng một dòng (query cuối: AOV, % chỉ tiêu)

**Ý tưởng:** các chỉ số chỉ cần số liệu của chính tháng đó: AOV = doanh thu / số đơn, khách quay lại = tổng khách − khách mới, % đạt chỉ tiêu = doanh thu / chỉ tiêu.

**Ví dụ nhỏ:** tháng 1, doanh thu 180, 3 đơn, chỉ tiêu 150.

| metric | value |
| --- | --- |
| aov | 60.00 = 180 / 3 |
| attainment_pct | 120.0 = 180 / 150 |

```sql
ROUND(1.0 * f.revenue / NULLIF(f.orders, 0), 2) AS aov,
f.customers - f.new_customers                   AS returning_customers,
ROUND(100.0 * f.revenue / t.target, 1)          AS attainment_pct
```

`NULLIF(f.orders, 0)` cho tháng 3 (không có đơn) ra AOV là `NULL` thay vì lỗi chia cho 0. `1.0 *` và `100.0 *` để phép chia không bị chia số nguyên.

> [!CAUTION]
> ❌ **Lấy AOV bằng trung bình AOV của từng khách**
>
> Tháng 1: AOV của Alice là (100 + 30) / 2 = 65, của Ben là 50. Trung bình hai số này là 57.50. Nhưng AOV theo định nghĩa là tổng doanh thu / tổng số đơn = 180 / 3 = **60.00**. Ben có ít đơn hơn mà lại có trọng số bằng Alice.
>
> → **Sửa:** tỉ số của tổng: `SUM(doanh thu) / COUNT(đơn)`. Biên lợi nhuận của một nhóm cũng vậy: `SUM(lợi nhuận) / SUM(doanh thu)`, không dùng `AVG(margin_pct)`.

## B5. Chỉ số so với dòng khác (query cuối: % so tháng trước, cộng dồn, tỉ trọng)

**Ý tưởng:** ba chỉ số cần nhìn sang các dòng khác. Hàm cửa sổ chạy **sau** `GROUP BY`, nên làm việc thẳng trên các dòng tháng đã có ở B3:
- So với tháng trước: `LAG(revenue) OVER (ORDER BY month)`.
- Cộng dồn: `SUM(revenue) OVER (ORDER BY month)`. Có `ORDER BY` thì ra tổng **từ đầu tới dòng hiện tại**.
- Tỉ trọng: `SUM(revenue) OVER ()`. Không có `ORDER BY` thì mọi dòng nhận **cùng một tổng** của cả bảng.

**Ví dụ nhỏ:** tháng 2.

| metric | value |
| --- | --- |
| mom_pct | −44.4 = (100 − 180) / 180 |
| running_revenue | 280 = 180 + 100 |
| pct_of_total | 18.9 = 100 / 530 |

```sql
ROUND(100.0 * (f.revenue - LAG(f.revenue) OVER w)
      / NULLIF(LAG(f.revenue) OVER w, 0), 1)    AS mom_pct,
SUM(f.revenue) OVER w                           AS running_revenue,
ROUND(100.0 * f.revenue / SUM(f.revenue) OVER (), 1) AS pct_of_total
-- WINDOW w AS (ORDER BY f.month)
```

`WINDOW w AS (...)` đặt tên cho cửa sổ để dùng lại nhiều lần. Tháng 4 có tháng trước là 0, nên `NULLIF` cho `mom_pct` là `NULL` (không tính được % tăng từ 0).

> [!CAUTION]
> ❌ **Tính tỉ trọng bằng `SUM(revenue) OVER (ORDER BY month)`**
>
> Có `ORDER BY` thì mẫu số là tổng **cộng dồn tới tháng đó**, không phải tổng cả kỳ. Tháng 1 ra 100% (180 / 180), tháng 2 ra 35.7% (100 / 280).
>
> → **Sửa:** tỉ trọng dùng `SUM(revenue) OVER ()`, với dấu ngoặc trống.

## Tổng kết: query đầy đủ

```sql
WITH clean AS (                                    -- B1: đơn hợp lệ, gắn tháng
  SELECT order_id, customer_id, amount, DATE_TRUNC('month', order_date)::date AS month
  FROM orders
  WHERE status = 'Completed'
),
first_month AS (                                   -- B2: tháng mua đầu mỗi khách
  SELECT customer_id, MIN(month) AS first_month
  FROM clean
  GROUP BY customer_id
),
monthly AS (                                       -- B2: một dòng mỗi tháng có đơn
  SELECT c.month,
         SUM(c.amount)                 AS revenue,
         COUNT(*)                      AS orders,
         COUNT(DISTINCT c.customer_id) AS customers,
         COUNT(DISTINCT c.customer_id) FILTER (WHERE c.month = f.first_month) AS new_customers
  FROM clean c
  JOIN first_month f USING (customer_id)
  GROUP BY c.month
),
months AS (                                        -- B3: mọi tháng
  SELECT generate_series(MIN(month), MAX(month), INTERVAL '1 month')::date AS month
  FROM clean
),
full_m AS (                                        -- B3: lấp tháng trống
  SELECT m.month,
         COALESCE(mo.revenue, 0)       AS revenue,
         COALESCE(mo.orders, 0)        AS orders,
         COALESCE(mo.customers, 0)     AS customers,
         COALESCE(mo.new_customers, 0) AS new_customers
  FROM months m
  LEFT JOIN monthly mo USING (month)
)
SELECT TO_CHAR(f.month, 'YYYY-MM') AS month, f.revenue, f.orders, f.customers, f.new_customers,
       f.customers - f.new_customers                   AS returning_customers,    -- B4
       ROUND(1.0 * f.revenue / NULLIF(f.orders, 0), 2) AS aov,
       ROUND(100.0 * f.revenue / t.target, 1)          AS attainment_pct,
       ROUND(100.0 * (f.revenue - LAG(f.revenue) OVER w)                          -- B5
             / NULLIF(LAG(f.revenue) OVER w, 0), 1)    AS mom_pct,
       SUM(f.revenue) OVER w                           AS running_revenue,
       ROUND(100.0 * f.revenue / SUM(f.revenue) OVER (), 1) AS pct_of_total
FROM full_m f
JOIN targets t USING (month)
WINDOW w AS (ORDER BY f.month)
ORDER BY f.month;
```

| month | revenue | orders | customers | new_customers | returning_customers | aov | attainment_pct | mom_pct | running_revenue | pct_of_total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 180 | 3 | 2 | 2 | 0 | 60.00 | 120.0 | NULL | 180 | 34.0 |
| 2024-02 | 100 | 2 | 2 | 1 | 1 | 50.00 | 66.7 | -44.4 | 280 | 18.9 |
| 2024-03 | 0 | 0 | 0 | 0 | 0 | NULL | 0.0 | -100.0 | 280 | 0.0 |
| 2024-04 | 250 | 3 | 2 | 1 | 1 | 83.33 | 125.0 | NULL | 530 | 47.2 |

---

# Phần 2: Biến thể

Ngoài bảng báo cáo tháng, có ba dạng tính toán trên cửa sổ hay gặp trong báo cáo: trung bình trượt, tỉ trọng trong nhóm, và tổng cộng dồn có điều kiện. Mỗi mục dưới đây kể một tình huống, thử cách làm quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi tính trung bình trượt 3 ngày

Một cửa hàng muốn làm mượt doanh thu theo ngày: với mỗi ngày, lấy **trung bình của ngày đó và 2 ngày trước** (ở đầu chuỗi thì ít ngày hơn). Đi kèm là doanh thu cộng dồn.

```text
daily_sales (sale_date, amount)   -- mới; một dòng mỗi ngày
```

| sale_date | amount |
| --- | --- |
| 2024-03-01 | 120 |
| 2024-03-02 | 80 |
| 2024-03-03 | 100 |
| 2024-03-04 | 200 |
| 2024-03-05 | 60 |

### Thử cách tự nhiên nhất

Cộng dồn thì viết `SUM(amount) OVER (ORDER BY sale_date)`. Viết trung bình theo cùng kiểu: `AVG(amount) OVER (ORDER BY sale_date)`. Kết quả ngày 03-04 ra 125.00, ngày 03-05 ra 112.00.

Đó là trung bình **từ ngày đầu tiên** tới ngày đang xét, không phải của 3 ngày gần nhất. Khi có `ORDER BY`, cửa sổ mặc định chạy từ dòng đầu tới dòng hiện tại. Với `SUM`, đó chính là tổng cộng dồn ta cần. Với `AVG`, đó là trung bình cộng dồn, không phải trung bình trượt.

### Cách sửa: chỉ rõ khung cửa sổ

Thêm **khung** (frame) để chỉ rõ cửa sổ gồm những dòng nào: `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` nghĩa là 2 dòng trước và chính dòng hiện tại.

```sql
SELECT sale_date, amount,
       SUM(amount) OVER (ORDER BY sale_date) AS running_total,
       ROUND(AVG(amount) OVER (ORDER BY sale_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3
FROM daily_sales
ORDER BY sale_date;
```

| sale_date | amount | running_total | moving_avg_3 | window |
| --- | --- | --- | --- | --- |
| 2024-03-01 | 120 | 120 | 120.00 | 120 |
| 2024-03-02 | 80 | 200 | 100.00 | 120, 80 |
| 2024-03-03 | 100 | 300 | 100.00 | 120, 80, 100 |
| 2024-03-04 | 200 | 500 | 126.67 | 80, 100, 200 |
| 2024-03-05 | 60 | 560 | 120.00 | 100, 200, 60 |

`ROWS` đếm theo **dòng**. Nếu có ngày bị thiếu, "2 dòng trước" có thể cách xa hơn 2 ngày. Khi đó, lấp đủ các ngày trước (như B3, dùng `generate_series` theo ngày), rồi mới tính.

> [!TIP]
> **Ghi nhớ:** `SUM ... OVER (ORDER BY ...)` là cộng dồn. Trung bình trượt cần khung rõ ràng: `ROWS BETWEEN n PRECEDING AND CURRENT ROW`.

## V2. Khi tính tỉ trọng của mỗi sản phẩm trong nhóm

Đề: với mỗi sản phẩm, tổng doanh số là bao nhiêu, và chiếm bao nhiêu **phần trăm doanh số của nhóm hàng** chứa nó?

```text
products     (product_id, product_name, category)   -- mới
transactions (transaction_id, product_id, amount)    -- mới
```

| product_id | product_name | category |
| --- | --- | --- |
| 1 | Tea | Drinks |
| 2 | Coffee | Drinks |
| 3 | Cookies | Snacks |

| transaction_id | product_id | amount |
| --- | --- | --- |
| 101 | 1 | 30 |
| 102 | 1 | 50 |
| 103 | 2 | 120 |
| 104 | 3 | 70 |

Có hai mức gộp ở đây: tổng mỗi **sản phẩm** (Tea = 30 + 50 = 80), rồi tổng mỗi **nhóm** (Drinks = 80 + 120 = 200).

### Thử cách tự nhiên nhất

`GROUP BY` sản phẩm để có tổng sản phẩm, rồi viết `SUM(t.amount) OVER (PARTITION BY p.category)` cho tổng nhóm:

```text
ERROR:  column "t.amount" must appear in the GROUP BY clause or be used in an aggregate function
```

Sau `GROUP BY`, từng dòng giao dịch (`t.amount`) không còn nữa: mỗi sản phẩm đã gộp thành một dòng. Hàm cửa sổ chạy **sau** `GROUP BY`, nên nó chỉ nhìn thấy các giá trị đã gộp như `SUM(t.amount)`.

### Cách sửa: `SUM` lồng `SUM`

Viết `SUM(SUM(t.amount)) OVER (PARTITION BY p.category)`. `SUM` bên trong là hàm gộp: tổng mỗi sản phẩm, tính lúc `GROUP BY`. `SUM ... OVER` bên ngoài là hàm cửa sổ: cộng các tổng sản phẩm đó lại trong mỗi nhóm.

```sql
SELECT p.category, p.product_name,
       SUM(t.amount) AS total_sold,
       ROUND(100.0 * SUM(t.amount) / SUM(SUM(t.amount)) OVER (PARTITION BY p.category), 2) AS pct_of_category
FROM products p
JOIN transactions t ON t.product_id = p.product_id
GROUP BY p.category, p.product_name
ORDER BY p.category, p.product_name;
```

| category | product_name | total_sold | category total | pct_of_category |
| --- | --- | --- | --- | --- |
| Drinks | Coffee | 120 | 200 | 60.00 |
| Drinks | Tea | 80 | 200 | 40.00 |
| Snacks | Cookies | 70 | 70 | 100.00 |

> [!TIP]
> **Ghi nhớ:** khi cần cả tổng của nhóm nhỏ lẫn tổng của nhóm lớn trong một tầng, dùng `SUM(SUM(x)) OVER (PARTITION BY nhóm_lớn)`.

## V3. Khi tổng cộng dồn phải reset

Một chương trình tích điểm: khách tích điểm qua mỗi lần mua (`earn`). Khi khách **đổi thưởng** (`redeem`), số điểm tích lũy quay về 0. Đề: số điểm đang có sau mỗi giao dịch là bao nhiêu, và giao dịch nào **đầu tiên** đưa số điểm (kể từ lần đổi gần nhất) lên tới 200?

```text
ledger (entry_id, kind, pts)   -- mới
```

| entry_id | kind | pts |
| --- | --- | --- |
| 1 | earn | 40 |
| 2 | earn | 70 |
| 3 | redeem | 0 |
| 4 | earn | 30 |
| 5 | earn | 90 |
| 6 | earn | 100 |

### Thử cách tự nhiên nhất

`SUM(pts) OVER (ORDER BY entry_id)` cộng dồn mọi giao dịch: 40, 110, 110, 140, **230**, 330. Theo cách này, giao dịch 5 là lần đầu đạt 200. Nhưng giao dịch 3 là đổi thưởng, nên tính từ đó khách mới chỉ có 30 + 90 = 120 điểm ở giao dịch 5.

### Cách sửa: đánh số nhóm, rồi cộng dồn trong từng nhóm

Chia các giao dịch thành **nhóm**: mỗi lần đổi thưởng mở một nhóm mới. Số thứ tự nhóm chính là **số lần đổi thưởng tính tới dòng đó**: `COUNT(*) FILTER (WHERE kind = 'redeem') OVER (ORDER BY entry_id)`. Sau đó cộng dồn trong từng nhóm bằng `PARTITION BY` nhóm:

```sql
WITH grouped AS (
  SELECT entry_id, kind, pts,
         COUNT(*) FILTER (WHERE kind = 'redeem') OVER (ORDER BY entry_id) AS grp
  FROM ledger
),
running AS (
  SELECT entry_id, kind, pts,
         SUM(pts) OVER (PARTITION BY grp ORDER BY entry_id) AS balance
  FROM grouped
)
SELECT entry_id, balance
FROM running
WHERE balance >= 200
ORDER BY entry_id
LIMIT 1;
```

| entry_id | kind | pts | grp | balance | without reset |
| --- | --- | --- | --- | --- | --- |
| 1 | earn | 40 | 0 | 40 | 40 |
| 2 | earn | 70 | 0 | 110 | 110 |
| 3 | redeem | 0 | 1 | 0 | 110 |
| 4 | earn | 30 | 1 | 30 | 140 |
| 5 | earn | 90 | 1 | 120 | <span class="bad">230</span> |
| 6 | earn | 100 | 1 | **220** | 330 |

Kết quả: giao dịch 6, số điểm 220. Bộ lọc `balance >= 200` phải đặt ở tầng ngoài (`running` là một CTE riêng), vì hàm cửa sổ không dùng được trong `WHERE` của cùng tầng `SELECT`.

Hai biến thể khác của tổng cộng dồn dùng cùng ý tưởng:
- **Chỉ cộng một số dòng nhưng vẫn giữ mọi dòng**: thêm `FILTER` vào hàm cửa sổ, ví dụ `SUM(amount) FILTER (WHERE status = 'Completed') OVER (ORDER BY id)`.
- **Reset theo kỳ cố định** (mỗi tháng): `PARTITION BY` kỳ đó, ví dụ `SUM(amount) OVER (PARTITION BY DATE_TRUNC('month', d) ORDER BY d)`.

> [!TIP]
> **Ghi nhớ:** tổng cộng dồn reset khi gặp một sự kiện thì đánh số nhóm bằng `COUNT(*) FILTER (WHERE sự_kiện) OVER (ORDER BY ...)`, rồi `SUM ... OVER (PARTITION BY nhóm ORDER BY ...)`.
