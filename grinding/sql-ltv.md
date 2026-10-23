# LTV (giá trị vòng đời khách hàng)

> Bài liên quan: `ltv/01`–`04`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** trung bình một khách mang về bao nhiêu tiền? Khách đến từ tháng nào hoặc kênh nào "đáng tiền" hơn?

**Vì sao không lấy tổng doanh thu chia số khách là xong:**
- Khách cũ đã có nhiều tháng để mua, khách mới thì chưa. So sánh thẳng như vậy là không công bằng.
- "Trung bình" có hai nghĩa:
  - **Tỷ số của tổng**: tính trên tổng tiền của cả nhóm.
  - **Trung bình các tỷ số**: tính cho một khách điển hình.

  Hai cách thường cho ra hai con số khác nhau.

Bốn bước:

1. Lọc đơn hợp lệ, rồi tìm lần mua đầu
2. Tính doanh thu mỗi khách trong cửa sổ cần đo
3. Gộp theo nhóm
4. Vẽ đường LTV theo tuổi cohort

Ví dụ chạy xuyên suốt dùng bảng `orders` (chỉ tính đơn `delivered`):

| order_id | customer_id | order_date | amount_vnd | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-05 | 100000 | delivered |
| 2 | 1 | 2024-02-10 | 300000 | delivered |
| 3 | 1 | 2024-04-10 | 600000 | delivered |
| 4 | 2 | 2024-01-28 | 500000 | delivered |
| 5 | 3 | 2024-02-01 | 200000 | delivered |
| 6 | 3 | 2024-02-20 | 200000 | delivered |
| 7 | 3 | 2024-03-05 | 600000 | delivered |
| 8 | 4 | 2024-02-14 | 300000 | delivered |
| 9 | 4 | 2024-04-14 | 300000 | delivered |
| 10 | 5 | 2024-01-31 | 900000 | cancelled |
| 11 | 5 | 2024-02-29 | 1000000 | delivered |

---

## B1. Lọc đơn hợp lệ, rồi tìm lần mua đầu

- **Vấn đề:** cohort của khách là tháng mua đầu tiên, nhưng "lần mua đầu" phải là một đơn **hợp lệ**.
- **Tại sao:** nếu tìm `MIN(order_date)` trước khi lọc, đơn bị hủy của khách 5 (01-31) sẽ trở thành lần đầu, và khách 5 bị xếp nhầm vào cohort 2024-01. Vì vậy `WHERE status = 'delivered'` phải chạy trước window function.

```sql
counted AS (
  SELECT customer_id, order_date, amount_vnd,
         DATE_TRUNC('month', MIN(order_date) OVER (PARTITION BY customer_id))::date AS cohort
  FROM orders
  WHERE status = 'delivered'
)
```

| customer_id | order_date | amount_vnd | cohort |
| --- | --- | --- | --- |
| 1 | 2024-01-05 | 100000 | 2024-01 |
| 1 | 2024-02-10 | 300000 | 2024-01 |
| 1 | 2024-04-10 | 600000 | 2024-01 |
| 2 | 2024-01-28 | 500000 | 2024-01 |
| 3 | 2024-02-01 | 200000 | 2024-02 |
| 3 | 2024-02-20 | 200000 | 2024-02 |
| 3 | 2024-03-05 | 600000 | 2024-02 |
| 4 | 2024-02-14 | 300000 | 2024-02 |
| 4 | 2024-04-14 | 300000 | 2024-02 |
| 5 | 2024-02-29 | 1000000 | **2024-02** |

## B2. Tính doanh thu mỗi khách trong cửa sổ cần đo

- **Vấn đề:** mỗi câu hỏi đo doanh thu trong một cửa sổ khác nhau: cả vòng đời, tháng đầu, hoặc N ngày đầu.
- **Tại sao:** `GROUP BY customer_id` rồi dùng `SUM(...) FILTER (WHERE <trong cửa sổ>)`. Cách này cho nhiều cửa sổ cùng nằm trên một dòng.

```sql
per_customer AS (
  SELECT customer_id, cohort,
         SUM(amount_vnd) FILTER (WHERE DATE_TRUNC('month', order_date) = cohort) AS first_month,
         SUM(amount_vnd)                                                         AS lifetime
  FROM counted
  GROUP BY customer_id, cohort
)
```

| customer_id | cohort | first_month | lifetime | share_pct |
| --- | --- | --- | --- | --- |
| 1 | 2024-01 | 100000 | 1000000 | 10.0 |
| 2 | 2024-01 | 500000 | 500000 | 100.0 |
| 3 | 2024-02 | 400000 | 1000000 | 40.0 |
| 4 | 2024-02 | 300000 | 600000 | 50.0 |
| 5 | 2024-02 | 1000000 | 1000000 | 100.0 |

**Khi đo N ngày đầu** (ví dụ 90 ngày):
- Cửa sổ là `order_date <= first_date + 89`, tức từ ngày 0 đến ngày 89. Viết `+ 90` thì thành 91 ngày.
- Chỉ giữ những khách đã **đi hết** cửa sổ: `WHERE first_date + 89 <= ngày_chốt`. Nếu không, khách mới mua chưa đủ 90 ngày sẽ kéo giá trị trung bình xuống một cách giả tạo.

## B3. Gộp theo nhóm

- **Vấn đề:** cần một con số cho mỗi cohort (hoặc mỗi kênh).
- **Tại sao:** có hai cách, và chúng trả lời hai câu hỏi khác nhau:
  - **Tỷ số của tổng** `SUM(a) / SUM(b)`: tính trên tổng tiền, nên khách chi nhiều có trọng số lớn hơn.
  - **Trung bình các tỷ số** `AVG(a / b)`: mỗi khách có trọng số bằng nhau.

  Đề phải nói rõ muốn cách nào. Nếu đề không nói, hãy ghi rõ cách mình chọn.

```sql
SELECT cohort, COUNT(*) AS customers,
       SUM(first_month) AS first_month_revenue, SUM(lifetime) AS lifetime_revenue,
       ROUND(100.0 * SUM(first_month) / SUM(lifetime), 1)  AS share_of_totals_pct,
       ROUND(AVG(100.0 * first_month / lifetime), 1)       AS avg_customer_share_pct
FROM per_customer
GROUP BY cohort;
```

| cohort_month | customers | first_month_revenue | lifetime_revenue | share_of_totals_pct | avg_customer_share_pct |
| --- | --- | --- | --- | --- | --- |
| 2024-01 | 2 | 600000 | 1500000 | 40.0 | 55.0 |
| 2024-02 | 3 | 1700000 | 2600000 | 65.4 | 63.3 |

Cohort 2024-01: tính trên tổng tiền thì là 600k / 1,5tr = 40%. Tính theo từng khách thì là (10% + 100%) / 2 = 55%.

**Khi dùng công thức `LTV = AOV × tần suất × vòng đời`:**
- AOV = **tổng** doanh thu / **tổng** số đơn. Không lấy `AVG` của AOV từng khách.
- Vòng đời = `1 / NULLIF(churn_rate, 0)`. Khi churn bằng 0, vòng đời không xác định, nên để `NULL`.
- Chỉ làm tròn **một lần, ở cuối**. Làm tròn AOV trước rồi mới nhân sẽ làm sai số bị nhân lên.
- Đi `LEFT JOIN` từ danh sách kênh, để kênh không có khách vẫn hiện ra.

## B4. Vẽ đường LTV theo tuổi cohort

- **Vấn đề:** muốn biết LTV tăng thế nào theo từng tháng tuổi của cohort, kể cả những tháng không có doanh thu.
- **Tại sao:**
  - Tạo lưới cohort × mọi tháng đến cuối kỳ bằng `CROSS JOIN LATERAL generate_series`, rồi `LEFT JOIN` doanh thu vào lưới.
  - Cộng dồn doanh thu bằng `SUM() OVER (ORDER BY m)`, rồi chia cho **quy mô cohort**, không chia cho số khách hoạt động trong tháng.
  - Đường LTV lũy kế không bao giờ đi xuống. Nếu thấy nó giảm thì gần như chắc chắn là đã chia sai mẫu số.

```sql
sizes   AS (SELECT cohort, COUNT(DISTINCT customer_id) AS cohort_size FROM counted GROUP BY cohort),
monthly AS (SELECT cohort, DATE_TRUNC('month', order_date)::date AS m, SUM(amount_vnd) AS revenue
            FROM counted GROUP BY 1, 2),
grid AS (
  SELECT s.cohort, s.cohort_size, g.m::date AS m
  FROM sizes s
  CROSS JOIN LATERAL generate_series(s.cohort, DATE '2024-04-01', INTERVAL '1 month') AS g(m)
)
SELECT g.cohort, g.m, g.cohort_size, COALESCE(mo.revenue, 0) AS revenue,
       ROUND(SUM(COALESCE(mo.revenue, 0)) OVER (PARTITION BY g.cohort ORDER BY g.m)
             / g.cohort_size::numeric) AS cum_ltv
FROM grid g
LEFT JOIN monthly mo ON mo.cohort = g.cohort AND mo.m = g.m;
```

| cohort_month | m | cohort_size | revenue | cum_ltv |
| --- | --- | --- | --- | --- |
| 2024-01 | 2024-01 | 2 | 600000 | 300000 |
| 2024-01 | 2024-02 | 2 | 300000 | 450000 |
| 2024-01 | 2024-03 | 2 | **0** | 450000 |
| 2024-01 | 2024-04 | 2 | 600000 | 750000 |
| 2024-02 | 2024-02 | 3 | 1700000 | 566667 |
| 2024-02 | 2024-03 | 3 | 600000 | 766667 |
| 2024-02 | 2024-04 | 3 | 300000 | 866667 |

- Tháng 2024-03 của cohort 01 không có doanh thu nhưng vẫn có dòng, nhờ lưới.
- So sánh các cohort ở **cùng tuổi** (cùng `month_offset`), không so ở cùng tháng lịch.

---

## Tổng kết: query đầy đủ

Hai câu đầy đủ: B1 → B3 (tỷ trọng tháng đầu theo cohort) và B1 + B4 (đường LTV lũy kế):

```sql
WITH counted AS (                                  -- B1: lọc đơn hợp lệ, rồi tìm lần mua đầu
  SELECT customer_id, order_date, amount_vnd,
         DATE_TRUNC('month', MIN(order_date) OVER (PARTITION BY customer_id))::date AS cohort
  FROM orders
  WHERE status = 'delivered'
),
per_customer AS (                                  -- B2: doanh thu mỗi khách trong từng cửa sổ
  SELECT customer_id, cohort,
         SUM(amount_vnd) FILTER (WHERE DATE_TRUNC('month', order_date) = cohort) AS first_month,
         SUM(amount_vnd)                                                         AS lifetime
  FROM counted
  GROUP BY customer_id, cohort
)
SELECT TO_CHAR(cohort, 'YYYY-MM') AS cohort_month, COUNT(*) AS customers,   -- B3: gộp theo cohort
       SUM(first_month) AS first_month_revenue, SUM(lifetime) AS lifetime_revenue,
       ROUND(100.0 * SUM(first_month) / SUM(lifetime), 1) AS share_of_totals_pct,
       ROUND(AVG(100.0 * first_month / lifetime), 1)      AS avg_customer_share_pct
FROM per_customer
GROUP BY cohort
ORDER BY cohort;
```

| cohort_month | customers | first_month_revenue | lifetime_revenue | share_of_totals_pct | avg_customer_share_pct |
| --- | --- | --- | --- | --- | --- |
| 2024-01 | 2 | 600000 | 1500000 | 40.0 | 55.0 |
| 2024-02 | 3 | 1700000 | 2600000 | 65.4 | 63.3 |

```sql
WITH counted AS (
  SELECT customer_id, order_date, amount_vnd,
         DATE_TRUNC('month', MIN(order_date) OVER (PARTITION BY customer_id))::date AS cohort
  FROM orders
  WHERE status = 'delivered'
),
sizes   AS (SELECT cohort, COUNT(DISTINCT customer_id) AS cohort_size FROM counted GROUP BY cohort),
monthly AS (SELECT cohort, DATE_TRUNC('month', order_date)::date AS m, SUM(amount_vnd) AS revenue
            FROM counted GROUP BY 1, 2),
grid AS (
  SELECT s.cohort, s.cohort_size, g.m::date AS m
  FROM sizes s
  CROSS JOIN LATERAL generate_series(s.cohort, DATE '2024-04-01', INTERVAL '1 month') AS g(m)
)
SELECT TO_CHAR(g.cohort, 'YYYY-MM') AS cohort_month,
       (EXTRACT(YEAR FROM g.m)::int * 12 + EXTRACT(MONTH FROM g.m)::int)
     - (EXTRACT(YEAR FROM g.cohort)::int * 12 + EXTRACT(MONTH FROM g.cohort)::int) AS month_offset,
       g.cohort_size,
       ROUND(SUM(COALESCE(mo.revenue, 0)) OVER (PARTITION BY g.cohort ORDER BY g.m)
             / g.cohort_size::numeric) AS cum_ltv
FROM grid g
LEFT JOIN monthly mo ON mo.cohort = g.cohort AND mo.m = g.m
ORDER BY 1, 2;
```

| cohort_month | month_offset | cohort_size | cum_ltv |
| --- | --- | --- | --- |
| 2024-01 | 0 | 2 | 300000 |
| 2024-01 | 1 | 2 | 450000 |
| 2024-01 | 2 | 2 | 450000 |
| 2024-01 | 3 | 2 | 750000 |
| 2024-02 | 0 | 3 | 566667 |
| 2024-02 | 1 | 3 | 766667 |
| 2024-02 | 2 | 3 | 866667 |
