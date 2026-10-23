# Window function

> Bài liên quan: `window/01`–`14`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** làm sao gắn lên **từng dòng** một con số được tính từ **các dòng khác**? Ví dụ: tổng tiền của khách, tổng dồn đến đơn này, đơn ngay trước, hạng của đơn trong nhóm.

**Vì sao `GROUP BY` không làm được:** `GROUP BY` gộp mỗi nhóm thành **một dòng**, nên mất chi tiết từng đơn:

| customer | total |
| --- | --- |
| An | 900 |
| Binh | 200 |

Window function tính trên một nhóm dòng nhưng **giữ nguyên số dòng**. Viết một window function là trả lời 4 câu hỏi, cộng thêm một bước lọc:

```
<hàm> OVER (PARTITION BY ...  ORDER BY ...  ROWS/RANGE BETWEEN ... AND ...)
             └ B1 nhóm nào    └ B2 thứ tự   └ B3 nhìn thấy dòng nào
 └ B4 tính gì                                  B5: lọc kết quả ở tầng ngoài
```

Ví dụ chạy xuyên suốt dùng bảng `orders` (đơn 2 và 3 cùng ngày; đơn 2 và 4 cùng số tiền):

| order_id | customer | order_date | amount |
| --- | --- | --- | --- |
| 1 | An | 2024-01-01 | 100 |
| 2 | An | 2024-01-03 | 300 |
| 3 | An | 2024-01-03 | 200 |
| 4 | An | 2024-01-10 | 300 |
| 5 | Binh | 2024-01-02 | 50 |
| 6 | Binh | 2024-01-08 | 150 |

Thứ tự chạy của một câu `SELECT`:

`FROM → WHERE → GROUP BY → HAVING → window → SELECT → ORDER BY → LIMIT`

Window chạy sau `GROUP BY` và trước `SELECT`.

---

## B1. `PARTITION BY`: tính trong nhóm nào

- **Vấn đề:** cần tổng tiền của khách trên mỗi đơn của khách đó, ví dụ để tính tỷ trọng của từng đơn.
- **Tại sao:**
  - `PARTITION BY customer` chia bảng thành từng nhóm theo khách, và hàm chỉ tính trong nhóm đó.
  - `OVER ()` không có gì bên trong nghĩa là tính trên cả bảng.
  - Khi **không có `ORDER BY`**, hàm nhìn thấy cả nhóm, nên mọi dòng trong nhóm nhận cùng một giá trị.

```sql
SELECT order_id, customer, amount,
       SUM(amount) OVER (PARTITION BY customer) AS cust_total,
       SUM(amount) OVER ()                      AS grand_total,
       ROUND(100.0 * amount / SUM(amount) OVER (PARTITION BY customer), 1) AS pct_of_cust
FROM orders
```

| order_id | customer | amount | cust_total | grand_total | pct_of_cust |
| --- | --- | --- | --- | --- | --- |
| 1 | An | 100 | 900 | 1100 | 11.1 |
| 2 | An | 300 | 900 | 1100 | 33.3 |
| 3 | An | 200 | 900 | 1100 | 22.2 |
| 4 | An | 300 | 900 | 1100 | 33.3 |
| 5 | Binh | 50 | 200 | 1100 | 25.0 |
| 6 | Binh | 150 | 200 | 1100 | 75.0 |

Nếu quên `PARTITION BY` khi tính "đơn trước" hay "tổng dồn", phép tính sẽ chạy xuyên qua khách khác.

## B2. `ORDER BY`: thứ tự trong nhóm

- **Vấn đề:** "tổng dồn", "đơn trước", "hạng" đều cần thứ tự. Nhưng hai đơn cùng ngày thì đơn nào đứng trước?
- **Tại sao:**
  - Thêm `ORDER BY` thì frame mặc định trở thành `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
  - `RANGE` coi các dòng có **cùng giá trị** `ORDER BY` là ngang hàng, và cộng chúng vào cùng một lúc. Kết quả là đơn 2 và đơn 3 cùng ra 600.
  - Thêm cột tách hòa (`order_id`) để thứ tự là duy nhất.

```sql
SUM(amount) OVER (PARTITION BY customer ORDER BY order_date)            AS range_default,
SUM(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id)  AS with_tiebreak
```

| order_id | customer | order_date | amount | range_default | with_tiebreak |
| --- | --- | --- | --- | --- | --- |
| 1 | An | 2024-01-01 | 100 | 100 | 100 |
| 2 | An | 2024-01-03 | 300 | **600** | 400 |
| 3 | An | 2024-01-03 | 200 | 600 | 600 |
| 4 | An | 2024-01-10 | 300 | 900 | 900 |
| 5 | Binh | 2024-01-02 | 50 | 50 | 50 |
| 6 | Binh | 2024-01-08 | 150 | 200 | 200 |

## B3. Frame: hàm nhìn thấy những dòng nào

- **Vấn đề:** mỗi câu hỏi cần một tập dòng khác nhau: tổng dồn, trung bình các đơn **trước** đơn này, tổng 7 ngày gần nhất.
- **Tại sao:**
  - `ROWS` đếm theo **dòng**.
  - `RANGE` lọc theo **giá trị** của cột `ORDER BY`. Vì vậy `RANGE ... INTERVAL '6 days'` mới đúng nghĩa 7 ngày lịch khi dữ liệu thiếu ngày. Còn `ROWS 6 PRECEDING` là 6 dòng trước, không phải 6 ngày.
  - `... AND 1 PRECEDING` loại chính dòng hiện tại. Dòng đầu có frame rỗng, nên ra `NULL`.

| Cần | Frame |
| --- | --- |
| tổng dồn | `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` |
| các dòng trước, không tính dòng này | `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING` |
| 7 ngày lịch | `RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW` |
| cửa sổ trượt 5 dòng, dòng hiện tại ở giữa | `ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING` |
| cả nhóm (khi đã có `ORDER BY`) | `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` |

| order_id | customer | order_date | amount | running | avg_before | last_7d | last_default |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | An | 2024-01-01 | 100 | 100 | NULL | 100 | 100 |
| 2 | An | 2024-01-03 | 300 | 400 | 100 | 600 | 300 |
| 3 | An | 2024-01-03 | 200 | 600 | 200 | 600 | 200 |
| 4 | An | 2024-01-10 | 300 | 900 | 200 | 300 | 300 |
| 5 | Binh | 2024-01-02 | 50 | 50 | NULL | 50 | 50 |
| 6 | Binh | 2024-01-08 | 150 | 200 | 50 | 200 | 150 |

- `last_7d` của đơn 4 (ngày 01-10) chỉ còn 300, vì ngày 01-03 đã nằm ngoài khoảng 7 ngày tính tới 01-10.
- `last_default = LAST_VALUE(amount)` với frame mặc định luôn bằng **chính dòng hiện tại**, vì frame chỉ chạy tới dòng đang xét. Muốn lấy dòng cuối nhóm thì mở frame ra cả nhóm, hoặc đảo chiều sắp xếp rồi dùng `FIRST_VALUE`.

## B4. Hàm: tính gì

- **Vấn đề:** cần chọn đúng loại hàm cho câu hỏi.
- **Tại sao:** có ba loại hàm:

| Loại | Hàm | Trả lời |
| --- | --- | --- |
| Xếp hạng | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, `CUME_DIST` | dòng này đứng thứ mấy |
| Lấy giá trị ở dòng khác | `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE` | dòng trước, dòng sau, dòng đầu là gì |
| Tổng hợp | `SUM`, `AVG`, `COUNT`, `MIN`, `MAX` | tổng hợp trên frame |

```sql
SELECT order_id, customer, amount,
       ROW_NUMBER() OVER w AS rn, RANK() OVER w AS rnk, DENSE_RANK() OVER w AS drnk,
       LAG(amount)         OVER (PARTITION BY customer ORDER BY order_date, order_id) AS prev_amount,
       FIRST_VALUE(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id) AS first_amount
FROM orders
WINDOW w AS (PARTITION BY customer ORDER BY amount DESC)
```

| order_id | customer | amount | rn | rnk | drnk | prev_amount | first_amount |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | An | 300 | 1 | 1 | 1 | 100 | 100 |
| 4 | An | 300 | 2 | 1 | 1 | 200 | 100 |
| 3 | An | 200 | 3 | 3 | 2 | 300 | 100 |
| 1 | An | 100 | 4 | 4 | 3 | NULL | 100 |
| 6 | Binh | 150 | 1 | 1 | 1 | 50 | 50 |
| 5 | Binh | 50 | 2 | 2 | 2 | NULL | 50 |

- Đơn 2 và 4 cùng 300: `ROW_NUMBER` vẫn cho hai số khác nhau, `RANK` cho cùng hạng rồi bỏ qua hạng 2, `DENSE_RANK` cho cùng hạng và không bỏ hạng nào.
- `WINDOW w AS (...)` đặt tên cho một cửa sổ để dùng lại nhiều lần.
- Một số lỗi hay gặp:
  - `COUNT(DISTINCT x) OVER (...)` báo lỗi `DISTINCT is not implemented for window functions`. Muốn đếm số khách khác nhau tính đến ngày D, hãy đếm số khách có **ngày mua đầu tiên** không sau ngày D.
  - `PERCENT_RANK` và `CUME_DIST` trả về `double precision`, nên phải ép `::numeric` trước khi `ROUND`.
  - Muốn so sánh với dòng trước mà vẫn đúng khi có `NULL`, dùng `x IS DISTINCT FROM LAG(x) OVER (...)` thay vì `<>`.

## B5. Lọc kết quả window ở tầng ngoài

- **Vấn đề:** cần đơn lớn nhất của mỗi khách, tức là `rn = 1`.
- **Tại sao:** window chạy **sau** `WHERE`, nên viết `WHERE ROW_NUMBER() OVER (...) = 1` sẽ báo lỗi `window functions are not allowed in WHERE`. `HAVING` cũng không dùng được. Phải tính window ở subquery hoặc CTE, rồi lọc ở tầng ngoài.

```sql
SELECT order_id, customer, amount
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY customer ORDER BY amount DESC, order_id) AS rn
      FROM orders) t
WHERE rn = 1;
```

| order_id | customer | amount |
| --- | --- | --- |
| 2 | An | 300 |
| 6 | Binh | 150 |

**Dùng window trên kết quả `GROUP BY`:** vì window chạy sau `GROUP BY`, có thể lồng một hàm tổng hợp vào trong window, ví dụ `RANK() OVER (ORDER BY SUM(amount) DESC)` hoặc `SUM(SUM(amount)) OVER ()`.

```sql
SELECT customer, SUM(amount) AS total,
       RANK() OVER (ORDER BY SUM(amount) DESC) AS rnk,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 1) AS pct
FROM orders GROUP BY customer;
```

| customer | total | rnk | pct |
| --- | --- | --- | --- |
| An | 900 | 1 | 81.8 |
| Binh | 200 | 2 | 18.2 |

---

## Tổng kết: query đầy đủ

Một câu dùng cả 5 bước: tổng của khách, tổng dồn, đơn trước, rồi giữ đơn lớn nhất mỗi khách:

```sql
WITH per_order AS (
  SELECT order_id, customer, order_date, amount,
         SUM(amount) OVER (PARTITION BY customer)                                   AS cust_total,   -- B1
         SUM(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id                        -- B2
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)        AS running,      -- B3
         LAG(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id)     AS prev_amount,  -- B4
         ROW_NUMBER() OVER (PARTITION BY customer ORDER BY amount DESC, order_id)   AS rn
  FROM orders
)
SELECT order_id, customer, amount, cust_total, running, prev_amount  -- B5: lọc ở tầng ngoài
FROM per_order
WHERE rn = 1
ORDER BY customer;
```

| order_id | customer | amount | cust_total | running | prev_amount |
| --- | --- | --- | --- | --- | --- |
| 2 | An | 300 | 900 | 400 | 100 |
| 6 | Binh | 150 | 200 | 200 | 50 |
