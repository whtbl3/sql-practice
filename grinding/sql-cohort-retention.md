# Cohort / Retention

> Bài liên quan: `cohort/01`, `03`, `04`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** khách mới của tháng X, sau n tháng còn bao nhiêu % quay lại?

**Vì sao không đếm thẳng theo tháng:** tháng 2024-01 có 3 khách, nhưng khách 1 là khách cũ (bắt đầu từ 2023-11). Đếm theo tháng trộn khách cũ với khách mới.

Muốn tách ra, mọi phân tích cohort đều đi qua 5 bước:

1. Gom hoạt động về mức (khách, kỳ)
2. Xác định cohort của khách
3. Đo khoảng cách tới cohort
4. Đếm khách theo (cohort, khoảng cách)
5. Chia cho quy mô cohort

Ví dụ chạy xuyên suốt dùng bảng `orders`:

| order_id | customer_id | order_date |
| --- | --- | --- |
| 1 | 1 | 2023-11-10 |
| 2 | 1 | 2023-12-05 |
| 3 | 1 | 2024-01-15 |
| 4 | 1 | 2024-02-20 |
| 5 | 2 | 2024-01-08 |
| 6 | 2 | 2024-03-12 |
| 7 | 3 | 2024-01-20 |

---

## B1. Gom hoạt động về mức (khách, kỳ)

- **Vấn đề:** retention chỉ hỏi khách *có* hoạt động trong kỳ hay không. Một khách mua 2 đơn trong cùng tháng sẽ bị đếm 2 lần.
- **Tại sao:** dùng `DATE_TRUNC` vì nó giữ kiểu `date`, nên bước 3 còn trừ được. `TO_CHAR` thì ra chuỗi, chỉ dùng ở `SELECT` cuối. Dùng `DISTINCT` để bỏ trùng.

```sql
orders_clean AS (
  SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
  FROM orders
)
```

| customer_id | order_month |
| --- | --- |
| 1 | 2023-11-01 |
| 1 | 2023-12-01 |
| 1 | 2024-01-01 |
| 1 | 2024-02-01 |
| 2 | 2024-01-01 |
| 2 | 2024-03-01 |
| 3 | 2024-01-01 |

## B2. Xác định cohort của khách

- **Vấn đề:** cohort của khách nằm ở dòng có tháng nhỏ nhất, nhưng dòng nào cũng cần biết giá trị đó.
- **Tại sao:** `GROUP BY` tìm được tháng nhỏ nhất nhưng gộp mất các tháng sau. `MIN() OVER (PARTITION BY ...)` tính trong nhóm của khách và vẫn giữ nguyên mọi dòng.

```sql
with_cohort AS (
  SELECT customer_id, order_month,
         MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
  FROM orders_clean
)
```

| customer_id | order_month | cohort_month |
| --- | --- | --- |
| 1 | 2023-11-01 | 2023-11-01 |
| 1 | 2023-12-01 | 2023-11-01 |
| 1 | 2024-01-01 | 2023-11-01 |
| 1 | 2024-02-01 | 2023-11-01 |
| 2 | 2024-01-01 | 2024-01-01 |
| 2 | 2024-03-01 | 2024-01-01 |
| 3 | 2024-01-01 | 2024-01-01 |

**Khi cohort nằm ở bảng khác** (ví dụ tháng đăng ký trong `users`): lấy cohort từ bảng đó rồi `JOIN` với hoạt động. Lúc này có thể có hoạt động xảy ra **trước** cohort, nên phải lọc `event_month >= cohort_month` trước khi đếm.

```sql
SELECT u.user_id, DATE_TRUNC('month', u.signup_date)::date AS cohort_month,
       DATE_TRUNC('month', e.event_date)::date AS event_month
FROM users u JOIN events e ON e.user_id = u.user_id
WHERE DATE_TRUNC('month', e.event_date) >= DATE_TRUNC('month', u.signup_date)
```

## B3. Đo khoảng cách tới cohort

- **Vấn đề:** cần biết đây là tháng thứ mấy kể từ cohort. Ví dụ 2023-11 → 2024-02 phải ra 3.
- **Tại sao:** trừ thẳng tháng với tháng thì ra `2 - 11 = -9`, vì bỏ qua năm. Đổi mỗi tháng thành một số `năm*12 + tháng` rồi mới trừ.

```sql
(EXTRACT(YEAR FROM order_month)::int  * 12 + EXTRACT(MONTH FROM order_month)::int)
- (EXTRACT(YEAR FROM cohort_month)::int * 12 + EXTRACT(MONTH FROM cohort_month)::int) AS month_offset
```

| customer_id | cohort_month | order_month | month_offset |
| --- | --- | --- | --- |
| 1 | 2023-11-01 | 2023-11-01 | 0 |
| 1 | 2023-11-01 | 2023-12-01 | 1 |
| 1 | 2023-11-01 | 2024-01-01 | 2 |
| 1 | 2023-11-01 | 2024-02-01 | 3 |
| 2 | 2024-01-01 | 2024-01-01 | 0 |
| 2 | 2024-01-01 | 2024-03-01 | 2 |
| 3 | 2024-01-01 | 2024-01-01 | 0 |

**Khi khoảng cách tính bằng ngày tới lần mua thứ 2** (ví dụ "mua lại trong 30 ngày"):
- `MAX(order_date)` cho ra đơn **cuối cùng**, không phải đơn thứ 2.
- Dùng `ROW_NUMBER` để đánh số đơn, rồi `MAX(...) FILTER (WHERE rn = k)` để đưa đơn 1 và đơn 2 lên cùng một dòng. Trừ hai `date` cho nhau ra số ngày.

```sql
r AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn
  FROM orders
),
f AS (
  SELECT customer_id,
         MAX(order_date) FILTER (WHERE rn = 1) AS first_date,
         MAX(order_date) FILTER (WHERE rn = 2) AS second_date   -- NULL nếu chỉ có 1 đơn
  FROM r GROUP BY customer_id
)
```

## B4. Đếm khách theo (cohort, khoảng cách)

- **Vấn đề:** cần biết mỗi cặp (cohort, offset) có bao nhiêu khách.
- **Tại sao:** dùng `COUNT(DISTINCT customer_id)` để đếm khách chứ không đếm dòng. Đếm dòng thì một khách có nhiều dòng sẽ bị tính nhiều lần.

```sql
activity AS (
  SELECT cohort_month, <month_offset ở B3> AS month_offset,
         COUNT(DISTINCT customer_id) AS active_customers
  FROM with_cohort
  GROUP BY cohort_month, month_offset
)
```

| cohort_month | month_offset | active_customers |
| --- | --- | --- |
| 2023-11-01 | 0 | 1 |
| 2023-11-01 | 1 | 1 |
| 2023-11-01 | 2 | 1 |
| 2023-11-01 | 3 | 1 |
| 2024-01-01 | 0 | 2 |
| 2024-01-01 | 2 | 1 |

Cohort 2024-01 không có dòng offset 1, vì tháng đó không ai trong cohort mua. `GROUP BY` chỉ tạo ra nhóm có dữ liệu.

## B5. Chia cho quy mô cohort

- **Vấn đề:** quy mô cohort không nằm trên dòng đang tính.
- **Tại sao:** chọn cách lấy quy mô cohort tùy theo cohort được định nghĩa thế nào:

| Cohort được định nghĩa | Offset 0 có đủ mọi khách không? | Lấy quy mô cohort bằng |
| --- | --- | --- |
| Tháng hoạt động đầu tiên (B2 dùng `MIN OVER`) | có, theo định nghĩa | `FIRST_VALUE(active) OVER (PARTITION BY cohort ORDER BY offset)` |
| Bảng khác (tháng đăng ký, ...) | không, vì có người đăng ký mà không hoạt động | `COUNT(*)` từ bảng đó, rồi `JOIN` vào |

Dùng `FIRST_VALUE` trong trường hợp thứ hai thì quy mô cohort bị đếm thiếu, kết quả ra 100% ở mọi ô.

Nhớ đặt `100.0 *` trước phép chia, nếu không sẽ thành chia số nguyên (`1/2 = 0`).

```sql
SELECT TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month, month_offset, active_customers,
       ROUND(100.0 * active_customers /
             FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1) AS retention_pct
FROM activity
ORDER BY cohort_month, month_offset;
```

| cohort_month | month_offset | active_customers | retention_pct |
| --- | --- | --- | --- |
| 2023-11 | 0 | 1 | 100.0 |
| 2023-11 | 1 | 1 | 100.0 |
| 2023-11 | 2 | 1 | 100.0 |
| 2023-11 | 3 | 1 | 100.0 |
| 2024-01 | 0 | 2 | 100.0 |
| 2024-01 | 2 | 1 | 50.0 |

**Với chỉ số kiểu "mua lại trong 30 ngày"** (tiếp từ `f` ở B3): mẫu số là `COUNT(*)`. Tử số là `COUNT(*) FILTER (WHERE second_date - first_date <= 30)`. Khách chỉ có một đơn có `second_date` là `NULL`, nên bị `FILTER` tự loại khỏi tử số nhưng vẫn nằm trong mẫu số.

---

## Tổng kết: query đầy đủ

Ghép B1 → B5 thành một câu, mỗi CTE là một bước:

```sql
WITH orders_clean AS (                             -- B1: (khách, tháng)
  SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
  FROM orders
),
with_cohort AS (                                   -- B2: cohort của khách
  SELECT customer_id, order_month,
         MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
  FROM orders_clean
),
activity AS (                                      -- B3 + B4: offset, đếm khách
  SELECT cohort_month,
         (EXTRACT(YEAR FROM order_month)::int  * 12 + EXTRACT(MONTH FROM order_month)::int)
       - (EXTRACT(YEAR FROM cohort_month)::int * 12 + EXTRACT(MONTH FROM cohort_month)::int) AS month_offset,
         COUNT(DISTINCT customer_id) AS active_customers
  FROM with_cohort
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
| 2023-11 | 0 | 1 | 100.0 |
| 2023-11 | 1 | 1 | 100.0 |
| 2023-11 | 2 | 1 | 100.0 |
| 2023-11 | 3 | 1 | 100.0 |
| 2024-01 | 0 | 2 | 100.0 |
| 2024-01 | 2 | 1 | 50.0 |
