# RFM (phân khúc khách hàng)

> Bài liên quan: `cohort/02`, `05`–`08`, `rfm/01`–`06`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** tại một ngày chốt, mỗi khách đang ở tình trạng nào (VIP, sắp rời bỏ, đã mất...), để biết nên chăm sóc ai và kéo lại ai.

**Vì sao không nhìn thẳng vào bảng đơn hàng được:** một khách có nhiều đơn, còn câu trả lời cần **một dòng mỗi khách**. Dòng đó gồm 3 con số, rồi từ 3 con số suy ra một nhãn:

- **R**ecency: lần mua gần nhất cách ngày chốt bao nhiêu ngày.
- **F**requency: số đơn.
- **M**onetary: tổng tiền.

Năm bước:

1. Chốt ngày và tập đơn được tính
2. Tính R, F, M cho mỗi khách
3. Chấm điểm từng chỉ số
4. Gắn nhãn phân khúc
5. Tổng hợp theo phân khúc

Ví dụ chạy xuyên suốt: ngày chốt `2024-07-01`, chỉ tính đơn `Completed` đặt trước ngày chốt.

`customers`: 6 khách, `customer_id` từ 1 đến 6.

`orders`:

| order_id | customer_id | order_date | total_amount | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-04-01 | 300 | Completed |
| 2 | 1 | 2024-05-15 | 350 | Completed |
| 3 | 1 | 2024-06-20 | 400 | Completed |
| 4 | 2 | 2024-06-01 | 120 | Completed |
| 5 | 2 | 2024-07-03 | 900 | Completed |
| 6 | 3 | 2024-02-10 | 700 | Completed |
| 7 | 3 | 2024-04-20 | 500 | Completed |
| 8 | 4 | 2024-06-28 | 2000 | Cancelled |
| 9 | 6 | 2023-12-01 | 50 | Completed |

---

## B1. Chốt ngày và tập đơn được tính

- **Vấn đề:**
  - R phụ thuộc vào ngày chốt.
  - Đơn hủy và đơn đặt sau ngày chốt không được tính.
  - Khách chưa mua lần nào vẫn phải có mặt trong kết quả.
- **Tại sao:**
  - Ngày chốt phải **cố định**, không dùng `CURRENT_DATE`, để chạy lại ngày nào cũng ra cùng kết quả.
  - Đi từ `customers LEFT JOIN orders` để giữ khách chưa mua. Điều kiện lọc `orders` phải đặt **trong `ON`**: nếu để ở `WHERE`, dòng `NULL` của khách chưa mua bị loại, khách 4 và 5 biến mất.

```sql
FROM customers c
LEFT JOIN orders o
       ON o.customer_id = c.customer_id
      AND o.status = 'Completed'
      AND o.order_date < DATE '2024-07-01'
```

| customer_id | order_id | order_date | total_amount |
| --- | --- | --- | --- |
| 1 | 1 | 2024-04-01 | 300 |
| 1 | 2 | 2024-05-15 | 350 |
| 1 | 3 | 2024-06-20 | 400 |
| 2 | 4 | 2024-06-01 | 120 |
| 3 | 6 | 2024-02-10 | 700 |
| 3 | 7 | 2024-04-20 | 500 |
| 4 | NULL | NULL | NULL |
| 5 | NULL | NULL | NULL |
| 6 | 9 | 2023-12-01 | 50 |

Đơn 5 (đặt sau ngày chốt) và đơn 8 (đã hủy) đã bị loại, nhưng khách 4 và 5 vẫn còn.

**Khi ngày chốt không cho sẵn:** lấy ngày sau đơn hợp lệ mới nhất: `SELECT MAX(order_date) + 1 FROM orders WHERE status = 'Completed'`.

**Khi cần nhiều ngày chốt cùng lúc** (so sánh phân khúc quý 1 với quý 2):
- `customers CROSS JOIN snapshots(snap, snap_date)` để mỗi khách có một dòng cho mỗi ngày chốt.
- Đặt điều kiện `o.order_date < s.snap_date` trong `ON`.
- Các bước sau `GROUP BY customer_id, snap`.

**Khi chỉ tính một khoảng thời gian** (ví dụ cả năm 2024): viết khoảng nửa mở `order_date >= '2024-01-01' AND order_date < '2025-01-01'`. Cách này đúng cả khi cột có giờ.

## B2. Tính R, F, M cho mỗi khách

- **Vấn đề:** gom nhiều đơn của một khách về một dòng gồm 3 con số.
- **Tại sao:**
  - `GROUP BY customer_id`, không nhóm theo tên, vì tên có thể trùng.
  - Đếm bằng `COUNT(o.order_id)` chứ không `COUNT(*)`. Khách chưa mua vẫn có một dòng `NULL`, nên `COUNT(*)` ra 1, còn `COUNT(o.order_id)` ra 0.
  - Trừ hai `date` cho nhau ra số ngày.

```sql
rfm AS (
  SELECT c.customer_id,
         DATE '2024-07-01' - MAX(o.order_date) AS recency_days,   -- NULL nếu chưa mua
         COUNT(o.order_id)                     AS frequency,
         COALESCE(SUM(o.total_amount), 0)      AS monetary
  FROM customers c LEFT JOIN orders o ON ...   -- như B1
  GROUP BY c.customer_id
)
```

| customer_id | recency_days | frequency | monetary |
| --- | --- | --- | --- |
| 1 | 11 | 3 | 1050 |
| 2 | 30 | 1 | 120 |
| 3 | 72 | 2 | 1200 |
| 4 | NULL | 0 | 0 |
| 5 | NULL | 0 | 0 |
| 6 | 213 | 1 | 50 |

**Khi có bảng con nhiều dòng mỗi đơn** (ví dụ `refunds`, một đơn có thể hoàn tiền nhiều lần):
- Gộp bảng con về **một dòng mỗi đơn trước**, rồi mới `JOIN` vào đơn hàng.
- Nếu `JOIN` thẳng, đơn có 2 lần hoàn bị nhân đôi tiền và nhân đôi số đơn.

```sql
refund_per_order AS (SELECT order_id, SUM(refund_vnd) AS refunded FROM refunds GROUP BY order_id)
-- rồi: SUM(o.amount_vnd - COALESCE(r.refunded, 0))
```

## B3. Chấm điểm từng chỉ số

- **Vấn đề:** 3 con số khác đơn vị nhau (ngày, số đơn, tiền), cần đưa về cùng một thang điểm, ví dụ 1–3.
- **Tại sao:** điểm cao phải nghĩa là **tốt**:
  - F và M càng lớn càng tốt.
  - R ngược lại: số ngày càng **nhỏ** càng tốt.
  - Khách chưa mua có R là `NULL`. Phép so sánh `NULL <= 30` không ra `true`, nên rơi xuống `ELSE`, tức điểm thấp nhất.

Khi doanh nghiệp đã có ngưỡng cụ thể, chấm bằng `CASE`:

```sql
scored AS (
  SELECT *,
         CASE WHEN recency_days <= 30 THEN 3 WHEN recency_days <= 90 THEN 2 ELSE 1 END AS r_score,
         CASE WHEN frequency >= 3 THEN 3 WHEN frequency >= 2 THEN 2 ELSE 1 END       AS f_score,
         CASE WHEN monetary >= 1000 THEN 3 WHEN monetary >= 300 THEN 2 ELSE 1 END    AS m_score
  FROM rfm
)
```

| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score | rfm_code |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 11 | 3 | 1050 | 3 | 3 | 3 | 333 |
| 2 | 30 | 1 | 120 | 3 | 1 | 1 | 311 |
| 3 | 72 | 2 | 1200 | 2 | 2 | 3 | 223 |
| 4 | NULL | 0 | 0 | 1 | 1 | 1 | 111 |
| 5 | NULL | 0 | 0 | 1 | 1 | 1 | 111 |
| 6 | 213 | 1 | 50 | 1 | 1 | 1 | 111 |

`rfm_code = CONCAT(r_score, f_score, m_score)` ra kiểu **text**.

**Khi không có ngưỡng**, chấm theo thứ hạng tương đối giữa các khách:

| Cách | Viết | Dùng khi |
| --- | --- | --- |
| `NTILE(3)` | `NTILE(3) OVER (ORDER BY recency_days DESC, customer_id)` | cần chia thành các nhóm đông bằng nhau. Khách có giá trị bằng nhau vẫn có thể bị chia khác điểm, nên phải thêm `customer_id` để kết quả cố định |
| `CUME_DIST` | `CEIL(5 * CUME_DIST() OVER (ORDER BY frequency))::int` | đề yêu cầu giá trị bằng nhau thì cùng điểm |

Với R, cả hai cách đều phải `ORDER BY recency_days DESC`, để người mua gần nhất đứng cuối danh sách và nhận điểm cao.

**Khi ngưỡng nằm trong bảng** `rfm_thresholds(metric, score, min_value, max_value)`:
- Nối theo khoảng giá trị (non-equi join), mỗi chỉ số một lần `LEFT JOIN` với một alias riêng.
- `max_value` là `NULL` nghĩa là không có cận trên. Không dùng `BETWEEN` được, vì so sánh với `NULL` không ra `true`.

```sql
LEFT JOIN rfm_thresholds r
       ON r.metric = 'R' AND c.recency_days >= r.min_value
      AND (r.max_value IS NULL OR c.recency_days <= r.max_value)
-- COALESCE(r.score, 0) cho giá trị không rơi vào khoảng nào
```

## B4. Gắn nhãn phân khúc

- **Vấn đề:** biến bộ 3 điểm thành một cái tên mà người làm kinh doanh hiểu được.
- **Tại sao:** `CASE` dừng ở nhánh đúng **đầu tiên**, nên phải xếp nhánh cụ thể trước, nhánh chung sau. Ví dụ `Champions` (3,3) phải đứng trước `Loyal` (>=2, >=2), nếu không khách 1 sẽ thành `Loyal`.

```sql
labeled AS (
  SELECT *,
         CASE WHEN r_score = 3 AND f_score = 3   THEN 'Champions'
              WHEN r_score >= 2 AND f_score >= 2 THEN 'Loyal'
              WHEN r_score = 3 AND f_score = 1   THEN 'New'
              WHEN r_score = 1 AND f_score >= 2  THEN 'At Risk'
              ELSE 'Lost' END AS segment
  FROM scored
)
```

| customer_id | r_score | f_score | m_score | segment |
| --- | --- | --- | --- | --- |
| 1 | 3 | 3 | 3 | Champions |
| 2 | 3 | 1 | 1 | New |
| 3 | 2 | 2 | 3 | Loyal |
| 4 | 1 | 1 | 1 | Lost |
| 5 | 1 | 1 | 1 | Lost |
| 6 | 1 | 1 | 1 | Lost |

**Khi luật nằm trong bảng** `segment_rules(priority, segment, pattern)`:
- Một khách có thể khớp nhiều luật, nên đây là bài **lấy 1 dòng tốt nhất cho mỗi khách**: chọn luật khớp có `priority` nhỏ nhất.
- Dùng `LEFT JOIN ... ON TRUE` để giữ cả khách không khớp luật nào.

```sql
LEFT JOIN LATERAL (
  SELECT r.segment FROM segment_rules r
  WHERE c.rfm_code ~ r.pattern          -- ~ : khớp regex
  ORDER BY r.priority LIMIT 1
) best ON TRUE
-- COALESCE(best.segment, 'Unclassified')
```

## B5. Tổng hợp theo phân khúc

- **Vấn đề:** cần biết mỗi phân khúc có bao nhiêu khách và chiếm bao nhiêu % doanh thu.
- **Tại sao:** chỉ `GROUP BY segment` thì có hai chỗ sai:
  - Phân khúc không có khách nào (`At Risk`) biến mất.
  - Thứ tự xếp theo bảng chữ cái thay vì thứ tự nghiệp vụ.

`GROUP BY segment` đơn thuần:

| segment | customers | revenue |
| --- | --- | --- |
| Champions | 1 | 1050 |
| Lost | 3 | 50 |
| Loyal | 1 | 1200 |
| New | 1 | 120 |

Cách sửa:
- Tạo danh sách phân khúc bằng `VALUES`, kèm cột thứ tự, rồi `LEFT JOIN` khách vào danh sách đó.
- Đếm bằng `COUNT(l.segment)` để phân khúc trống ra 0.
- `SUM(SUM(...)) OVER ()` cho tổng doanh thu toàn bộ, dùng làm mẫu số.

```sql
segments(segment, sort_key) AS (
  VALUES ('Champions', 1), ('Loyal', 2), ('New', 3), ('At Risk', 4), ('Lost', 5)
)
SELECT s.segment,
       COUNT(l.segment)             AS customers,
       COALESCE(SUM(l.monetary), 0) AS revenue,
       ROUND(100.0 * COALESCE(SUM(l.monetary), 0)
             / NULLIF(SUM(SUM(l.monetary)) OVER (), 0), 1) AS revenue_pct
FROM segments s
LEFT JOIN labeled l ON l.segment = s.segment
GROUP BY s.segment, s.sort_key
ORDER BY s.sort_key;
```

| segment | customers | revenue | revenue_pct |
| --- | --- | --- | --- |
| Champions | 1 | 1050 | 43.4 |
| Loyal | 1 | 1200 | 49.6 |
| New | 1 | 120 | 5.0 |
| At Risk | 0 | 0 | 0.0 |
| Lost | 3 | 50 | 2.1 |

**Khi so sánh hai ngày chốt** (tiếp từ B1 có nhiều ngày chốt):
- Xoay ngang bằng `MAX(segment) FILTER (WHERE snap = 'q1')`, làm tương tự cho `q2`.
- Lọc `segment_q1 <> segment_q2` để lấy khách đã chuyển phân khúc.
- Nếu bỏ bộ lọc và `GROUP BY segment_q1, segment_q2` thì ra ma trận chuyển dịch giữa các phân khúc.

**Khi hỏi "bao nhiêu % khách tạo ra 80% doanh thu"** (Pareto):
- Một khách thuộc nhóm top khi tổng doanh thu của các khách **giàu hơn hẳn** mình còn dưới 80%.
- `EXCLUDE GROUP` bỏ mọi khách đồng doanh thu với dòng hiện tại (kể cả chính nó) khỏi phép cộng, nên các khách bằng nhau cùng vào hoặc cùng ra.
- Khách giàu nhất không có ai giàu hơn, `SUM` ra `NULL`, nên phải `COALESCE(..., 0)`.

```sql
COALESCE(SUM(revenue) OVER (ORDER BY revenue DESC
         RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW EXCLUDE GROUP), 0) AS higher_revenue
-- top khi higher_revenue < 0.8 * SUM(revenue) OVER ()
```

---

## Tổng kết: query đầy đủ

Ghép B1 → B5 thành một câu, mỗi CTE là một bước:

```sql
WITH rfm AS (                                      -- B1 + B2: ngày chốt, đơn hợp lệ, R/F/M mỗi khách
  SELECT c.customer_id,
         DATE '2024-07-01' - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id)                     AS frequency,
         COALESCE(SUM(o.total_amount), 0)      AS monetary
  FROM customers c
  LEFT JOIN orders o
         ON o.customer_id = c.customer_id
        AND o.status = 'Completed'
        AND o.order_date < DATE '2024-07-01'
  GROUP BY c.customer_id
),
scored AS (                                        -- B3: chấm điểm
  SELECT *,
         CASE WHEN recency_days <= 30 THEN 3 WHEN recency_days <= 90 THEN 2 ELSE 1 END AS r_score,
         CASE WHEN frequency >= 3 THEN 3 WHEN frequency >= 2 THEN 2 ELSE 1 END       AS f_score,
         CASE WHEN monetary >= 1000 THEN 3 WHEN monetary >= 300 THEN 2 ELSE 1 END    AS m_score
  FROM rfm
),
labeled AS (                                       -- B4: gắn nhãn
  SELECT *,
         CASE WHEN r_score = 3 AND f_score = 3   THEN 'Champions'
              WHEN r_score >= 2 AND f_score >= 2 THEN 'Loyal'
              WHEN r_score = 3 AND f_score = 1   THEN 'New'
              WHEN r_score = 1 AND f_score >= 2  THEN 'At Risk'
              ELSE 'Lost' END AS segment
  FROM scored
),
segments(segment, sort_key) AS (
  VALUES ('Champions', 1), ('Loyal', 2), ('New', 3), ('At Risk', 4), ('Lost', 5)
)
SELECT s.segment,                                  -- B5: tổng hợp theo phân khúc
       COUNT(l.segment)             AS customers,
       COALESCE(SUM(l.monetary), 0) AS revenue,
       ROUND(100.0 * COALESCE(SUM(l.monetary), 0)
             / NULLIF(SUM(SUM(l.monetary)) OVER (), 0), 1) AS revenue_pct
FROM segments s
LEFT JOIN labeled l ON l.segment = s.segment
GROUP BY s.segment, s.sort_key
ORDER BY s.sort_key;
```

| segment | customers | revenue | revenue_pct |
| --- | --- | --- | --- |
| Champions | 1 | 1050 | 43.4 |
| Loyal | 1 | 1200 | 49.6 |
| New | 1 | 120 | 5.0 |
| At Risk | 0 | 0 | 0.0 |
| Lost | 3 | 50 | 2.1 |
