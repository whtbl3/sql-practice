# Khoảng cách giữa các lần mua

> Bài liên quan: `gaps/01`–`05`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** khách bao lâu mua một lần, bao lâu thì quay lại, và ai đang vắng lâu bất thường?

**Khác gì với chủ đề gần giống:**
- **Gaps & Islands** hỏi *chuỗi liên tiếp* dài bao nhiêu.
- **Churn** hỏi có hoạt động *trong tháng* hay không.
- Chủ đề này đo **số ngày** giữa hai lần mua liền nhau, rồi tổng hợp các con số đó.

Bốn bước:

1. Bỏ trùng ngày mua
2. Tính khoảng cách tới lần mua kề bên
3. Tổng hợp theo khách
4. Tổng hợp theo nhóm

Ví dụ chạy xuyên suốt dùng bảng `orders`:

| order_id | customer_id | order_date |
| --- | --- | --- |
| 1 | 1 | 2024-01-01 |
| 2 | 1 | 2024-01-11 |
| 3 | 1 | 2024-01-31 |
| 4 | 1 | 2024-03-01 |
| 5 | 2 | 2024-02-01 |
| 6 | 2 | 2024-02-01 |
| 7 | 2 | 2024-02-05 |
| 8 | 3 | 2024-03-10 |
| 9 | 4 | 2024-01-05 |
| 10 | 4 | 2024-04-05 |
| 11 | 4 | 2024-04-06 |
| 12 | 5 | 2023-12-30 |
| 13 | 5 | 2024-01-02 |
| 14 | 6 | 2024-01-01 |
| 15 | 6 | 2024-01-02 |
| 16 | 6 | 2024-01-04 |

---

## B1. Bỏ trùng ngày mua

- **Vấn đề:** hai đơn trong cùng một ngày tạo ra một khoảng cách bằng 0, kéo `MIN` và `AVG` xuống. Nó cũng làm "lần mua thứ 2" rơi vào chính ngày đầu tiên.
- **Tại sao:** "lần mua" ở đây là một **ngày** có mua hàng, không phải một đơn.

Không bỏ trùng (khách 2):

| customer_id | order_date | gap |
| --- | --- | --- |
| 2 | 2024-02-01 | NULL |
| 2 | 2024-02-01 | **0** |
| 2 | 2024-02-05 | 4 |

Cách sửa:

```sql
days AS (SELECT DISTINCT customer_id, order_date FROM orders)
```

**Khi có ngày chốt:** lọc `order_date <= ngày_chốt` ngay ở bước này, trước khi gọi `LAG`/`LEAD`. Nếu không, một đơn sau ngày chốt sẽ "đóng" một quãng vắng mà lẽ ra vẫn đang mở.

## B2. Tính khoảng cách tới lần mua kề bên

- **Vấn đề:** khoảng cách là hiệu số giữa **hai dòng** liền nhau của cùng một khách.
- **Tại sao:**
  - `LAG` đưa ngày mua trước lên cùng dòng với ngày mua hiện tại.
  - Trừ hai `date` ra số ngày kiểu `int`.
  - Lần mua đầu tiên của mỗi khách không có lần trước, nên khoảng cách là `NULL`.

```sql
gaps AS (
  SELECT customer_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS gap
  FROM days
)
```

| customer_id | order_date | gap |
| --- | --- | --- |
| 1 | 2024-01-01 | NULL |
| 1 | 2024-01-11 | 10 |
| 1 | 2024-01-31 | 20 |
| 1 | 2024-03-01 | 30 |
| 2 | 2024-02-01 | NULL |
| 2 | 2024-02-05 | 4 |
| 3 | 2024-03-10 | NULL |
| 4 | 2024-01-05 | NULL |
| 4 | 2024-04-05 | 91 |
| 4 | 2024-04-06 | 1 |
| 5 | 2023-12-30 | NULL |
| 5 | 2024-01-02 | 3 |
| 6 | 2024-01-01 | NULL |
| 6 | 2024-01-02 | 1 |
| 6 | 2024-01-04 | 2 |

**Khi tính cả quãng đang vắng** (từ lần mua cuối đến ngày chốt):
- Dùng `LEAD` để mỗi dòng nhìn về lần mua kế tiếp. Tham số thứ 3 là giá trị dùng khi không có dòng kế tiếp, ở đây là ngày chốt.
- Để biết quãng nào đang mở, kiểm tra `LEAD` **không có giá trị mặc định** `IS NULL`. Không so `gap_end = ngày_chốt` được, vì một quãng đã đóng cũng có thể kết thúc đúng ngày chốt.

```sql
LEAD(order_date, 1, DATE '2024-04-30') OVER (PARTITION BY customer_id ORDER BY order_date) AS gap_end,
LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) IS NULL               AS is_open
```

| customer_id | gap_start | gap_end | is_open |
| --- | --- | --- | --- |
| 1 | 2024-01-01 | 2024-01-11 | false |
| 1 | 2024-01-11 | 2024-01-31 | false |
| 1 | 2024-01-31 | 2024-03-01 | false |
| 1 | 2024-03-01 | 2024-04-30 | true |
| 3 | 2024-03-10 | 2024-04-30 | true |

Khách 3 chỉ mua một lần vẫn có một dòng, chính là quãng đang mở.

**Khi chỉ cần lần mua thứ 2:**
- `ROW_NUMBER()` trên các **ngày đã bỏ trùng** ở B1.
- Rồi `MAX(order_date) FILTER (WHERE rn = 2) - MAX(order_date) FILTER (WHERE rn = 1)`.

## B3. Tổng hợp theo khách

- **Vấn đề:** mỗi khách cần một dòng thống kê: nhỏ nhất, trung bình, trung vị, lớn nhất.
- **Tại sao:**
  - `MIN`, `AVG`, `MAX` và `PERCENTILE_CONT` đều bỏ qua `NULL`, nên dòng đầu tiên (không có khoảng cách) tự bị loại.
  - `COUNT(*)` đếm số ngày mua. `COUNT(gap)` đếm số khoảng cách, luôn ít hơn 1.
  - `PERCENTILE_CONT` trả về `double precision`, mà `ROUND(double precision, int)` không tồn tại. Phải ép `::numeric` trước khi làm tròn.

```sql
SELECT customer_id,
       COUNT(*)           AS purchase_days,
       MIN(gap)           AS min_gap,
       ROUND(AVG(gap), 1) AS avg_gap,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap))::numeric, 1) AS median_gap,
       MAX(gap)           AS max_gap
FROM gaps
GROUP BY customer_id
HAVING COUNT(gap) >= 1
```

| customer_id | purchase_days | min_gap | avg_gap | median_gap | max_gap |
| --- | --- | --- | --- | --- | --- |
| 1 | 4 | 10 | 20.0 | 20.0 | 30 |
| 2 | 2 | 4 | 4.0 | 4.0 | 4 |
| 4 | 3 | 1 | 46.0 | 46.0 | 91 |
| 5 | 2 | 3 | 3.0 | 3.0 | 3 |
| 6 | 3 | 1 | 1.5 | 1.5 | 2 |

**Khi tìm khách vắng lâu bất thường:**
- So mỗi khách với **nhịp của chính họ**: `days_since_last > 2 * median_gap`. Một ngưỡng chung (ví dụ 30 ngày) sai với cả người mua hằng tuần lẫn người mua theo quý.
- Dùng trung vị, không dùng trung bình, vì một lần nghỉ dài kéo trung bình lên rất cao. Ví dụ với các khoảng 10, 100, 12, 14: trung bình là 34, trung vị là 13.

**Khi chọn quãng vắng dài nhất:** đây là bài lấy 1 dòng tốt nhất cho mỗi khách. Dùng `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY gap_days DESC, gap_start)`, thêm `gap_start` để khi hai quãng dài bằng nhau thì luôn chọn quãng sớm hơn.

## B4. Tổng hợp theo nhóm

- **Vấn đề:** cần phân bố khoảng cách theo từng nhóm (1–7 ngày, 8–30 ngày, ...), và phải có đủ mọi nhóm.
- **Tại sao:** dùng `CASE` rồi `GROUP BY` thì có hai chỗ sai:
  - Nhóm không có khoảng cách nào sẽ biến mất.
  - Sắp theo tên thì `'31-90'` đứng trước `'8-30'`, vì so sánh chữ.

  Cách sửa: tạo bảng `VALUES` gồm tên nhóm, thứ tự, cận dưới và cận trên, rồi `LEFT JOIN` theo khoảng. Dòng `gap` là `NULL` không khớp nhóm nào nên tự rơi ra.

```sql
buckets(bucket, sort_key, lo, hi) AS (
  VALUES ('1-7 days', 1, 1, 7), ('8-30 days', 2, 8, 30), ('31-90 days', 3, 31, 90), ('91+ days', 4, 91, NULL)
)
SELECT b.bucket,
       COUNT(g.gap) AS gaps,
       ROUND(100.0 * COUNT(g.gap) / NULLIF(SUM(COUNT(g.gap)) OVER (), 0), 1) AS pct_of_gaps
FROM buckets b
LEFT JOIN gaps g ON g.gap >= b.lo AND (b.hi IS NULL OR g.gap <= b.hi)
GROUP BY b.bucket, b.sort_key
ORDER BY b.sort_key;
```

| bucket | gaps | pct_of_gaps |
| --- | --- | --- |
| 1-7 days | 5 | 55.6 |
| 8-30 days | 3 | 33.3 |
| 31-90 days | 0 | 0.0 |
| 91+ days | 1 | 11.1 |

**Khi nhóm theo một thuộc tính của khách** (ví dụ kênh thu hút khách):
- Đi `customers LEFT JOIN` bảng kết quả theo khách ở B3.
- Một dòng có ba mẫu số khác nhau, đọc kỹ đề để chia đúng:
  - Số khách của kênh: `COUNT(*)`.
  - Số người đã mua: `COUNT(p.customer_id)`.
  - Số người đã quay lại: `COUNT(p.days_to_return)`. `AVG` và `PERCENTILE_CONT` cũng chỉ tính trên những người này, vì chúng bỏ qua `NULL`.

---

## Tổng kết: query đầy đủ

Ghép B1 → B3 thành một câu (B4 là bước thay thế cho B3 khi đề hỏi theo nhóm):

```sql
WITH days AS (                                     -- B1: bỏ trùng ngày mua
  SELECT DISTINCT customer_id, order_date FROM orders
),
gaps AS (                                          -- B2: khoảng cách tới lần mua trước
  SELECT customer_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS gap
  FROM days
)
SELECT customer_id,                                -- B3: thống kê theo khách
       COUNT(*)           AS purchase_days,
       MIN(gap)           AS min_gap,
       ROUND(AVG(gap), 1) AS avg_gap,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap))::numeric, 1) AS median_gap,
       MAX(gap)           AS max_gap
FROM gaps
GROUP BY customer_id
HAVING COUNT(gap) >= 1
ORDER BY customer_id;
```

| customer_id | purchase_days | min_gap | avg_gap | median_gap | max_gap |
| --- | --- | --- | --- | --- | --- |
| 1 | 4 | 10 | 20.0 | 20.0 | 30 |
| 2 | 2 | 4 | 4.0 | 4.0 | 4 |
| 4 | 3 | 1 | 46.0 | 46.0 | 91 |
| 5 | 2 | 3 | 3.0 | 3.0 | 3 |
| 6 | 3 | 1 | 1.5 | 1.5 | 2 |
