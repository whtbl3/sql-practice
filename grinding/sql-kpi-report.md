# Báo cáo chỉ số (KPI, dashboard)

> Bài liên quan: `misc/01`, `02`, `03`, `05`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** mỗi tháng doanh thu bao nhiêu, có bao nhiêu đơn, bao nhiêu khách, bao nhiêu khách mới? Mỗi đơn trung bình bao nhiêu tiền (AOV)? Doanh thu tăng giảm bao nhiêu % so với tháng trước? Đạt bao nhiêu % chỉ tiêu, chiếm bao nhiêu % tổng?

**Vì sao viết một câu `SELECT` duy nhất thì dễ sai:** các chỉ số này nằm ở **các mức chi tiết khác nhau**:
- Doanh thu tính trên từng đơn.
- Khách mới phải biết tháng mua đầu tiên của từng khách.
- So với tháng trước thì phải nhìn sang dòng khác.

Trộn các mức chi tiết này trong một tầng thì bị nhân dòng, mất tháng trống, hoặc chia sai. Cách làm đúng là **mỗi CTE làm một việc**, và đưa mọi thứ về **một mức chi tiết (grain)** trước khi so sánh giữa các dòng.

Năm bước:

1. Lọc đơn hợp lệ, gắn kỳ
2. Gộp về grain của báo cáo
3. Lấp các kỳ trống
4. Tính chỉ số trong từng dòng
5. Tính chỉ số so với dòng khác

Ví dụ chạy xuyên suốt dùng bảng `orders` (tháng 3 không có đơn nào):

| order_id | customer_id | order_date | amount | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-05 | 100 | Completed |
| 2 | 2 | 2024-01-12 | 50 | Completed |
| 3 | 1 | 2024-01-25 | 30 | Completed |
| 4 | 3 | 2024-01-28 | 70 | Cancelled |
| 5 | 1 | 2024-02-10 | 60 | Completed |
| 6 | 3 | 2024-02-14 | 40 | Completed |
| 7 | 2 | 2024-04-03 | 90 | Completed |
| 8 | 4 | 2024-04-15 | 110 | Completed |
| 9 | 4 | 2024-04-20 | 50 | Completed |

`targets`: mục tiêu doanh thu là 150, 150, 100, 200 cho các tháng 01 đến 04.

---

## B1. Lọc đơn hợp lệ, gắn kỳ

- **Vấn đề:** đơn bị hủy không được tính, và mỗi đơn cần biết nó thuộc tháng nào.
- **Tại sao:** phải lọc **ở bước đầu tiên**, vì mọi bước sau đều dựa trên tập đơn này. Ví dụ khách 3 có đơn tháng 1 đã bị hủy, nên khách 3 là khách mới của tháng 2. Nếu tìm tháng mua đầu từ bảng `orders` gốc, khách 3 sẽ bị tính nhầm vào tháng 1.

```sql
clean AS (
  SELECT order_id, customer_id, amount, DATE_TRUNC('month', order_date)::date AS month
  FROM orders WHERE status = 'Completed'
)
```

| order_id | customer_id | amount | month |
| --- | --- | --- | --- |
| 1 | 1 | 100 | 2024-01-01 |
| 2 | 2 | 50 | 2024-01-01 |
| 3 | 1 | 30 | 2024-01-01 |
| 5 | 1 | 60 | 2024-02-01 |
| 6 | 3 | 40 | 2024-02-01 |
| 7 | 2 | 90 | 2024-04-01 |
| 8 | 4 | 110 | 2024-04-01 |
| 9 | 4 | 50 | 2024-04-01 |

## B2. Gộp về grain của báo cáo

- **Vấn đề:** báo cáo có một dòng mỗi tháng, nhưng dữ liệu đang ở mức một dòng mỗi đơn.
- **Tại sao:**
  - `GROUP BY month`: dùng `COUNT(*)` để đếm đơn, `COUNT(DISTINCT customer_id)` để đếm khách.
  - Khách mới: lấy tháng mua đầu của mỗi khách ở một CTE riêng, có **một dòng mỗi khách**. Nhờ vậy khi nối vào đơn hàng thì không bị nhân dòng.
  - Bảng ở grain khác (ví dụ mục tiêu theo tháng) chỉ nối vào **sau khi đã gộp**. Nếu nối `targets` với từng đơn rồi mới `SUM(target)`, mục tiêu tháng 1 bị nhân 3 (150 thành 450), vì tháng 1 có 3 đơn.

```sql
first_month AS (SELECT customer_id, MIN(month) AS first_month FROM clean GROUP BY customer_id),
monthly AS (
  SELECT c.month,
         SUM(c.amount)                 AS revenue,
         COUNT(*)                      AS orders,
         COUNT(DISTINCT c.customer_id) AS customers,
         COUNT(DISTINCT c.customer_id) FILTER (WHERE c.month = f.first_month) AS new_customers
  FROM clean c JOIN first_month f USING (customer_id)
  GROUP BY c.month
)
```

| month | revenue | orders | customers | new_customers |
| --- | --- | --- | --- | --- |
| 2024-01 | 180 | 3 | 2 | 2 |
| 2024-02 | 100 | 2 | 2 | 1 |
| 2024-04 | 250 | 3 | 2 | 1 |

## B3. Lấp các kỳ trống

- **Vấn đề:** tháng 03 không có đơn nào nên biến mất khỏi bảng ở B2. Khi đó `LAG` ở dòng tháng 04 lấy nhầm doanh thu của tháng **02** để so sánh.
- **Tại sao:** tạo đủ mọi tháng bằng `generate_series`, rồi `LEFT JOIN` bảng `monthly` vào. Tháng không có dữ liệu thì `COALESCE` về 0. Việc này phải làm **trước** B5.

Không lấp tháng trống:

| month | revenue | prev |
| --- | --- | --- |
| 2024-01 | 180 | NULL |
| 2024-02 | 100 | 180 |
| 2024-04 | 250 | **100** |

Cách sửa:

```sql
months AS (SELECT generate_series(MIN(month), MAX(month), INTERVAL '1 month')::date AS month FROM clean),
full_m AS (
  SELECT m.month, COALESCE(mo.revenue, 0) AS revenue, COALESCE(mo.orders, 0) AS orders,
         COALESCE(mo.customers, 0) AS customers, COALESCE(mo.new_customers, 0) AS new_customers
  FROM months m LEFT JOIN monthly mo USING (month)
)
```

| month | revenue | orders | customers | new_customers |
| --- | --- | --- | --- | --- |
| 2024-01 | 180 | 3 | 2 | 2 |
| 2024-02 | 100 | 2 | 2 | 1 |
| 2024-03 | 0 | 0 | 0 | 0 |
| 2024-04 | 250 | 3 | 2 | 1 |

## B4. Tính chỉ số trong từng dòng

- **Vấn đề:** cần các tỷ số trong cùng một tháng: AOV, khách quay lại, % đạt mục tiêu.
- **Tại sao:**
  - Tỷ số phải là **tỷ số của tổng**. AOV = `SUM(revenue) / COUNT(orders)`, không phải trung bình AOV của từng khách.
  - Dùng `NULLIF(mẫu, 0)` để tháng không có đơn ra `NULL` thay vì báo lỗi chia cho 0.
  - Nhân với `1.0` hoặc `100.0` trước khi chia, để không bị chia số nguyên.

```sql
SELECT month, revenue, orders,
       ROUND(1.0 * revenue / NULLIF(orders, 0), 2) AS aov,
       customers - new_customers                   AS returning_customers,
       ROUND(100.0 * revenue / t.target, 1)        AS attainment_pct
FROM full_m JOIN targets t USING (month)
```

| month | revenue | orders | aov | returning_customers | attainment_pct |
| --- | --- | --- | --- | --- | --- |
| 2024-01 | 180 | 3 | 60.00 | 0 | 120.0 |
| 2024-02 | 100 | 2 | 50.00 | 1 | 66.7 |
| 2024-03 | 0 | 0 | NULL | 0 | 0.0 |
| 2024-04 | 250 | 3 | 83.33 | 1 | 125.0 |

**Khi tính biên lợi nhuận của một nhóm:** dùng `SUM(lợi nhuận) / SUM(doanh thu)`, không dùng `AVG(margin_pct)`. Ví dụ hai sản phẩm có doanh thu 200 và 100, biên 40% và 60%. Biên của nhóm là 140 / 300 = 46,7%, chứ không phải 50%.

## B5. Tính chỉ số so với dòng khác

- **Vấn đề:** cần so tháng này với tháng trước, cộng dồn từ đầu năm, và tính tỷ trọng so với tổng.
- **Tại sao:** window function chạy **sau** `GROUP BY`, nên làm việc trên các dòng tháng đã có ở B3:
  - So với tháng trước: `LAG(revenue) OVER (ORDER BY month)`.
  - Cộng dồn: `SUM(revenue) OVER (ORDER BY month)`. Có `ORDER BY` thì ra tổng dồn.
  - Tỷ trọng: `SUM(revenue) OVER ()`. Không có `ORDER BY`, nên mọi dòng nhận cùng một tổng.

```sql
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS mom_pct,
       SUM(revenue) OVER (ORDER BY month)                 AS running_revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)   AS pct_of_total
FROM full_m
```

| month | revenue | prev_revenue | mom_pct | running_revenue | pct_of_total |
| --- | --- | --- | --- | --- | --- |
| 2024-01 | 180 | NULL | NULL | 180 | 34.0 |
| 2024-02 | 100 | 180 | -44.4 | 280 | 18.9 |
| 2024-03 | 0 | 100 | -100.0 | 280 | 0.0 |
| 2024-04 | 250 | 0 | NULL | 530 | 47.2 |

**Khi gộp và window nằm trong cùng một tầng:** `SUM(SUM(amount)) OVER (PARTITION BY category)`. `SUM` bên trong là tổng của từng nhóm `GROUP BY`. `SUM ... OVER` bên ngoài cộng các tổng nhóm đó lại trong mỗi danh mục.

**Khi chỉ cộng dồn một số dòng nhưng vẫn giữ mọi dòng:**

| Đề nói | Viết |
| --- | --- |
| chỉ cộng đơn Completed | `SUM(amount) FILTER (WHERE status = 'Completed') OVER (ORDER BY id)` |
| reset mỗi tháng | `SUM(amount) OVER (PARTITION BY DATE_TRUNC('month', d) ORDER BY id)` |
| reset khi gặp một sự kiện | `grp = COUNT(*) FILTER (WHERE kind = 'redeem') OVER (ORDER BY id)`, rồi `SUM(pts) OVER (PARTITION BY grp ORDER BY id)` |
| dòng đầu tiên đạt ngưỡng | tính tổng dồn trong CTE, rồi ở tầng ngoài `WHERE running >= 200 ORDER BY id LIMIT 1` |

Window function không dùng được trong `WHERE` của cùng tầng, nên mọi điều kiện lọc trên kết quả window đều phải đặt ở tầng ngoài.

---

## Tổng kết: query đầy đủ

Ghép B1 → B5 thành một câu:

```sql
WITH clean AS (                                    -- B1: đơn hợp lệ, gắn tháng
  SELECT order_id, customer_id, amount, DATE_TRUNC('month', order_date)::date AS month
  FROM orders WHERE status = 'Completed'
),
first_month AS (SELECT customer_id, MIN(month) AS first_month FROM clean GROUP BY customer_id),
monthly AS (                                       -- B2: một dòng mỗi tháng
  SELECT c.month,
         SUM(c.amount)                 AS revenue,
         COUNT(*)                      AS orders,
         COUNT(DISTINCT c.customer_id) AS customers,
         COUNT(DISTINCT c.customer_id) FILTER (WHERE c.month = f.first_month) AS new_customers
  FROM clean c JOIN first_month f USING (customer_id)
  GROUP BY c.month
),
months AS (SELECT generate_series(MIN(month), MAX(month), INTERVAL '1 month')::date AS month FROM clean),
full_m AS (                                        -- B3: lấp tháng trống
  SELECT m.month, COALESCE(mo.revenue, 0) AS revenue, COALESCE(mo.orders, 0) AS orders,
         COALESCE(mo.customers, 0) AS customers, COALESCE(mo.new_customers, 0) AS new_customers
  FROM months m LEFT JOIN monthly mo USING (month)
)
SELECT TO_CHAR(f.month, 'YYYY-MM') AS month, f.revenue, f.orders, f.customers, f.new_customers,
       f.customers - f.new_customers                   AS returning_customers,    -- B4: trong dòng
       ROUND(1.0 * f.revenue / NULLIF(f.orders, 0), 2) AS aov,
       ROUND(100.0 * f.revenue / t.target, 1)          AS attainment_pct,
       ROUND(100.0 * (f.revenue - LAG(f.revenue) OVER w)                          -- B5: so với dòng khác
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
