# RFM (phân khúc khách hàng)

> Bài liên quan: `cohort/02`, `05`–`08`, `rfm/01`–`06`. Output đều chạy thật bằng `check.py`.

## Bài toán

Hôm nay là `2024-07-01`. Cửa hàng muốn biết mỗi khách đang "nóng" hay "nguội", để biết nên chăm ai và kéo lại ai. Với mỗi khách, ta trả lời 3 câu hỏi:

- **R**ecency: lần cuối mua cách đây bao nhiêu ngày? Càng ít càng tốt.
- **F**requency: đã mua bao nhiêu đơn? Càng nhiều càng tốt.
- **M**onetary: đã chi bao nhiêu tiền? Càng nhiều càng tốt.

Rồi đặt tên nhóm theo 3 câu trả lời. Ví dụ `Champions` là khách vừa mua gần đây và mua nhiều. `At Risk` là khách từng mua nhiều nhưng lâu rồi không quay lại.

## Dữ liệu

Hai bảng, quan hệ **1 khách – nhiều đơn** (`orders.customer_id` → `customers.customer_id`).

`customers`: mỗi dòng = 1 khách.

| customer_id | name |
| --- | --- |
| 1 | Alice |
| 2 | Ben |
| 3 | Chloe |
| 4 | David |
| 5 | Emma |
| 6 | Frank |

`orders`: mỗi dòng = 1 đơn. `status` là `Completed` hoặc `Cancelled`.

| order_id | customer_id | order_date | total_amount | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-03-10 | 200 | Completed |
| 2 | 1 | 2024-05-02 | 300 | Completed |
| 3 | 1 | 2024-06-18 | 600 | Completed |
| 4 | 2 | 2024-04-05 | 400 | Completed |
| 5 | 2 | 2024-05-20 | 250 | Completed |
| 6 | 2 | 2024-07-05 | 900 | Completed |
| 7 | 3 | 2023-11-15 | 500 | Completed |
| 8 | 3 | 2024-01-08 | 450 | Completed |
| 9 | 3 | 2024-02-25 | 300 | Completed |
| 10 | 4 | 2024-06-28 | 1500 | Cancelled |
| 11 | 6 | 2023-10-01 | 120 | Completed |

Ba chỗ dễ sai: đơn 6 đặt **sau** hôm nay, David chỉ có đơn **đã hủy**, Emma **chưa có đơn nào**.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Chọn đơn được tính | phần `LEFT JOIN orders` trong CTE `rfm` | 1 đơn (kèm khách) |
| B2 | Tính R, F, M | CTE `rfm` | **1 khách** |
| B3 | Đổi R, F, M thành điểm 1–3 | CTE `scored` | 1 khách |
| B4 | Đặt tên nhóm từ 3 điểm | CTE `labeled` | 1 khách |
| B5 | Đếm khách, cộng tiền theo nhóm | query cuối | **1 nhóm** |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Chọn đơn được tính

**Ý tưởng:** chỉ tính đơn `Completed` đặt trước hôm nay. Khách không có đơn hợp lệ nào vẫn giữ lại **1 dòng `NULL`**, vì họ cũng cần được xếp nhóm.

**Ví dụ nhỏ:** Ben và David.

| order_id | customer | order_date | status | reason |
| --- | --- | --- | --- | --- |
| 4 | Ben | 2024-04-05 | Completed | completed, before as-of date |
| 5 | Ben | 2024-05-20 | Completed | completed, before as-of date |
| 6 | Ben | 2024-07-05 | Completed | <span class="drop">placed after as-of date 2024-07-01</span> |
| 10 | David | 2024-06-28 | Cancelled | <span class="drop">cancelled</span> |

→

| customer_id | name | order_id | order_date | total_amount |
| --- | --- | --- | --- | --- |
| ... | | | | |
| 2 | Ben | 4 | 2024-04-05 | 400 |
| 2 | Ben | 5 | 2024-05-20 | 250 |
| 4 | David | NULL | NULL | NULL |
| ... | | | | |

```sql
SELECT c.customer_id, c.name, o.order_id, o.order_date, o.total_amount
FROM customers c
LEFT JOIN orders o
       ON o.customer_id = c.customer_id
      AND o.status = 'Completed'
      AND o.order_date < DATE '2024-07-01'
```

> [!CAUTION]
> ❌ **Điều kiện lọc đơn viết ở `WHERE`**
> ```sql
> LEFT JOIN orders o ON o.customer_id = c.customer_id
> WHERE o.status = 'Completed' AND o.order_date < DATE '2024-07-01'
> ```
>
> `LEFT JOIN` chạy trước: David được nối với đơn 10 (`Cancelled`), Emma không có đơn nên được một dòng `NULL`. Sau đó `WHERE` chỉ giữ dòng có `status = 'Completed'`. Đơn 10 bị xóa, dòng `NULL` của Emma cũng bị xóa (vì `NULL` không bằng `'Completed'`). Kết quả là David và Emma không còn dòng nào và biến mất khỏi bảng.
>
> → **Sửa:** viết điều kiện vào `ON`. Khi đó điều kiện chỉ quyết định **đơn nào được nối vào**. Khách không có đơn nào thỏa vẫn được giữ lại với một dòng `NULL`.
>
> ---
>
> ❌ **Dùng `CURRENT_DATE` thay cho ngày đề cho**
>
> `CURRENT_DATE` là ngày bạn chạy query. Hôm nay chạy, R của Alice ra một số; mai chạy lại thì R tăng thêm 1. Kết quả thay đổi theo ngày nên không bao giờ khớp đáp án.
>
> → **Sửa:** dùng đúng ngày đề cho: `DATE '2024-07-01' - MAX(o.order_date)`.

## B2. Tính R, F, M (CTE `rfm`)

**Ý tưởng:** gom các đơn của mỗi khách thành **1 dòng**: đơn gần nhất cho ra R, số đơn là F, tổng tiền là M.

**Ví dụ nhỏ:** Alice có 3 dòng, David có 1 dòng `NULL`.

| name | order_id | order_date | total_amount |
| --- | --- | --- | --- |
| Alice | 1 | 2024-03-10 | 200 |
| Alice | 2 | 2024-05-02 | 300 |
| Alice | 3 | 2024-06-18 | 600 |
| David | NULL | NULL | NULL |
| ... | | | |

→

| name | recency_days | frequency | monetary |
| --- | --- | --- | --- |
| Alice | 13 = 07-01 − 06-18 | 3 | 1100 = 200 + 300 + 600 |
| David | NULL (no orders) | 0 | 0 |
| ... | | | |

```sql
WITH rfm AS (
  SELECT c.customer_id, c.name,
         DATE '2024-07-01' - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id)                     AS frequency,
         COALESCE(SUM(o.total_amount), 0)      AS monetary
  FROM customers c
  LEFT JOIN orders o
         ON o.customer_id = c.customer_id
        AND o.status = 'Completed'
        AND o.order_date < DATE '2024-07-01'
  GROUP BY c.customer_id, c.name
)
```

> [!CAUTION]
> ❌ **Đếm đơn bằng `COUNT(*)`**
>
> Sau `LEFT JOIN`, David không có đơn nhưng vẫn có 1 dòng (toàn `NULL`). `COUNT(*)` đếm số dòng, nên ra 1, như thể David đã mua 1 đơn.
>
> → **Sửa:** `COUNT(o.order_id)`. Hàm này chỉ đếm dòng có `order_id` khác `NULL`, nên David ra 0.
>
> ---
>
> ❌ **Nhóm theo tên: `GROUP BY c.name`**
>
> Nếu có hai khách cùng tên Alice, đơn của cả hai bị cộng chung vào một dòng, như thể là một người.
>
> → **Sửa:** nhóm theo `customer_id`, vì mỗi khách có một mã riêng. Thêm `c.name` vào `GROUP BY` chỉ để hiện tên ra kết quả.

## B3. Đổi R, F, M thành điểm (CTE `scored`)

**Ý tưởng:** ba con số khác đơn vị (ngày, số đơn, tiền), không so với nhau được. Ta đổi mỗi số thành điểm 1–3, trong đó **3 luôn là tốt nhất**. Với R, ít ngày mới là tốt, nên ngưỡng của R đi theo chiều ngược lại.

| score | R (days) | F (orders) | M (amount) |
| --- | --- | --- | --- |
| 3 | ≤ 30 | ≥ 3 | ≥ 1000 |
| 2 | ≤ 90 | ≥ 2 | ≥ 300 |
| 1 | otherwise | otherwise | otherwise |

**Ví dụ nhỏ:**

| name | R → r_score | F → f_score | M → m_score |
| --- | --- | --- | --- |
| Alice | 13 → 3 | 3 → 3 | 1100 → 3 |
| Chloe | 127 → 1 | 3 → 3 | 1250 → 3 |
| David | NULL → 1 | 0 → 1 | 0 → 1 |
| ... | | | |

Chloe mua nhiều, chi nhiều, nhưng lâu rồi không quay lại, nên chỉ được 1 điểm R.

```sql
scored AS (
  SELECT *,
         CASE WHEN recency_days <= 30 THEN 3 WHEN recency_days <= 90 THEN 2 ELSE 1 END AS r_score,
         CASE WHEN frequency >= 3 THEN 3 WHEN frequency >= 2 THEN 2 ELSE 1 END       AS f_score,
         CASE WHEN monetary >= 1000 THEN 3 WHEN monetary >= 300 THEN 2 ELSE 1 END    AS m_score
  FROM rfm
)
```

David có R là `NULL`. Phép so sánh `NULL <= 30` không ra `true`, nên David rơi xuống `ELSE` và được 1 điểm. Ở đây đó đúng là điều ta muốn.

> [!CAUTION]
> ❌ **Để khách chưa mua rơi xuống `ELSE` khi đề quy định điểm riêng cho họ**
>
> Giả sử đề nói khách chưa mua được R = 0. David có `recency_days` là `NULL`. Cả `NULL <= 30` lẫn `NULL <= 90` đều không đúng, nên David rơi xuống `ELSE` và nhận 1 điểm, sai so với đề.
>
> → **Sửa:** thêm `WHEN recency_days IS NULL THEN 0` làm nhánh **đầu tiên** của `CASE`.

Đề cần **mã RFM** thì dùng `CONCAT(r_score, f_score, m_score) AS rfm_code`. Kết quả là **text**, ví dụ `'133'`.

## B4. Đặt tên nhóm (CTE `labeled`)

**Ý tưởng:** đưa 3 điểm qua một danh sách luật, xét **từ trên xuống**. Luật nào khớp trước thì lấy tên đó, rồi dừng.

**Ví dụ nhỏ:**

| rule (in order) | Alice (R=3, F=3) | Chloe (R=1, F=3) |
| --- | --- | --- |
| `Champions`: R = 3, F = 3 | **match, stop** | no |
| `Loyal`: R ≥ 2, F ≥ 2 | | no |
| `New`: R = 3, F = 1 | | no |
| `At Risk`: R = 1, F ≥ 2 | | **match, stop** |
| otherwise: `Lost` | | |

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

> [!CAUTION]
> ❌ **Viết luật `Loyal` lên trên luật `Champions`**
> ```sql
> CASE WHEN r_score >= 2 AND f_score >= 2 THEN 'Loyal'
>      WHEN r_score = 3 AND f_score = 3   THEN 'Champions'
>      ...
> ```
>
> Alice có R = 3, F = 3. `CASE` xét luật `Loyal` trước: 3 ≥ 2 và 3 ≥ 2 đều đúng, nên Alice nhận nhãn `Loyal` và `CASE` dừng ngay tại đó. Luật `Champions` nằm dưới không bao giờ được xét tới, nên không khách nào thành `Champions`.
>
> → **Sửa:** luật nào đòi hỏi **khắt khe hơn** thì viết lên trên. `Champions` cần R và F đều bằng 3, khắt khe hơn `Loyal` (chỉ cần ≥ 2), nên `Champions` phải đứng trước.

## B5. Tổng hợp theo nhóm (query cuối)

**Ý tưởng:** đếm khách và cộng tiền theo nhóm. Danh sách nhóm lấy từ một bảng **viết tay cố định**, không lấy từ dữ liệu. Nhờ vậy nhóm không có ai vẫn hiện ra với số 0, và các nhóm xếp theo thứ tự nghiệp vụ.

**Ví dụ nhỏ:** 3 khách `Lost` gom thành 1 dòng. Không ai thuộc `New`, nhưng dòng `New` vẫn có.

| name | segment | monetary |
| --- | --- | --- |
| David | Lost | 0 |
| Emma | Lost | 0 |
| Frank | Lost | 120 |
| ... | | |

→

| segment | customers | revenue | revenue_pct |
| --- | --- | --- | --- |
| ... | | | |
| New | 0 | 0 | 0.0 |
| ... | | | |
| Lost | 3 | 120 | 3.8 = 120 / 3120 |

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

`SUM(SUM(l.monetary)) OVER ()`: `SUM` bên trong cộng tiền của từng nhóm, `SUM ... OVER ()` bên ngoài cộng tất cả các nhóm lại. Kết quả là tổng 3120 nằm trên mỗi dòng, dùng làm mẫu số.

> [!CAUTION]
> ❌ **Đếm thẳng từ bảng khách: `FROM labeled GROUP BY segment`**
>
> Chỉ những nhóm có ít nhất 1 khách mới hiện ra. Không ai thuộc `New`, nên dòng `New` không có trong kết quả. Các nhóm còn lại xếp theo bảng chữ cái: `At Risk`, `Champions`, `Lost`, `Loyal`.
>
> → **Sửa:** bắt đầu từ danh sách `segments` (đủ 5 nhóm), `LEFT JOIN` khách vào, rồi `ORDER BY sort_key`.
>
> ---
>
> ❌ **Đếm khách bằng `COUNT(*)`**
>
> Nhóm `New` không có khách, nhưng `LEFT JOIN` vẫn tạo cho nó 1 dòng với phần khách là `NULL`. `COUNT(*)` đếm cả dòng đó nên ra 1.
>
> → **Sửa:** `COUNT(l.segment)`. Hàm này bỏ qua `NULL`, nên `New` ra 0.

## Tổng kết: query đầy đủ

```sql
WITH rfm AS (                                      -- B1 + B2: đơn được tính, R/F/M mỗi khách
  SELECT c.customer_id, c.name,
         DATE '2024-07-01' - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id)                     AS frequency,
         COALESCE(SUM(o.total_amount), 0)      AS monetary
  FROM customers c
  LEFT JOIN orders o
         ON o.customer_id = c.customer_id
        AND o.status = 'Completed'
        AND o.order_date < DATE '2024-07-01'
  GROUP BY c.customer_id, c.name
),
scored AS (                                        -- B3: điểm 1–3
  SELECT *,
         CASE WHEN recency_days <= 30 THEN 3 WHEN recency_days <= 90 THEN 2 ELSE 1 END AS r_score,
         CASE WHEN frequency >= 3 THEN 3 WHEN frequency >= 2 THEN 2 ELSE 1 END       AS f_score,
         CASE WHEN monetary >= 1000 THEN 3 WHEN monetary >= 300 THEN 2 ELSE 1 END    AS m_score
  FROM rfm
),
labeled AS (                                       -- B4: tên nhóm
  SELECT *,
         CASE WHEN r_score = 3 AND f_score = 3   THEN 'Champions'
              WHEN r_score >= 2 AND f_score >= 2 THEN 'Loyal'
              WHEN r_score = 3 AND f_score = 1   THEN 'New'
              WHEN r_score = 1 AND f_score >= 2  THEN 'At Risk'
              ELSE 'Lost' END AS segment
  FROM scored
),
segments(segment, sort_key) AS (                   -- B5: danh sách nhóm cố định
  VALUES ('Champions', 1), ('Loyal', 2), ('New', 3), ('At Risk', 4), ('Lost', 5)
)
SELECT s.segment,                                  -- B5: tổng hợp
       COUNT(l.segment)             AS customers,
       COALESCE(SUM(l.monetary), 0) AS revenue,
       ROUND(100.0 * COALESCE(SUM(l.monetary), 0)
             / NULLIF(SUM(SUM(l.monetary)) OVER (), 0), 1) AS revenue_pct
FROM segments s
LEFT JOIN labeled l ON l.segment = s.segment
GROUP BY s.segment, s.sort_key
ORDER BY s.sort_key;
```

Kết quả từng khách sau B4:

| name | recency_days | frequency | monetary | r_score | f_score | m_score | segment |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Alice | 13 | 3 | 1100 | 3 | 3 | 3 | Champions |
| Ben | 42 | 2 | 650 | 2 | 2 | 2 | Loyal |
| Chloe | 127 | 3 | 1250 | 1 | 3 | 3 | At Risk |
| David | NULL | 0 | 0 | 1 | 1 | 1 | Lost |
| Emma | NULL | 0 | 0 | 1 | 1 | 1 | Lost |
| Frank | 274 | 1 | 120 | 1 | 1 | 1 | Lost |

Kết quả cuối:

| segment | customers | revenue | revenue_pct |
| --- | --- | --- | --- |
| Champions | 1 | 1100 | 35.3 |
| Loyal | 1 | 650 | 20.8 |
| New | 0 | 0 | 0.0 |
| At Risk | 1 | 1250 | 40.1 |
| Lost | 3 | 120 | 3.8 |

---

# Phần 2: Biến thể

Đề thực tế hiếm khi giống hệt mạch chính. Thường đề chỉ đổi một chi tiết: có thêm bảng hoàn tiền, ngưỡng nằm trong bảng, cần so hai thời điểm... Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa. Phần lớn chỉ phải viết lại một CTE của Phần 1: `rfm` (R, F, M mỗi khách), `scored` (điểm) hoặc `labeled` (tên nhóm).

Có hai thay đổi nhỏ không cần mục riêng. Nếu đề không cho ngày chốt, ta tự lấy ngày ngay sau đơn hợp lệ mới nhất: `SELECT MAX(order_date) + 1 FROM orders WHERE status = 'Completed'`. Nếu đề chỉ tính một khoảng thời gian, ví dụ cả năm 2024, ta thêm `order_date >= '2024-01-01' AND order_date < '2025-01-01'` vào `ON`. Viết kiểu "từ ngày đầu, trước ngày sau cuối" như vậy thì vẫn đúng khi cột có cả giờ.

## V1. Khi đơn hàng có thể được hoàn tiền

Đến giờ ta coi `total_amount` là số tiền khách đã trả. Nhưng nếu cửa hàng cho hoàn tiền thì con số đó không còn đúng nữa: một đơn 600 được hoàn 150 thì khách thực ra chỉ trả 450. Đề lúc này yêu cầu M là số tiền khách **thực trả**.

Mỗi lần hoàn tiền được lưu thành một dòng trong bảng `refunds`. Bảng này nối vào `orders` qua `order_id`, và một đơn có thể được hoàn nhiều lần.

```text
customers (customer_id, name)                                        -- như Phần 1
orders    (order_id, customer_id, order_date, total_amount, status)  -- như Phần 1
refunds   (refund_id, order_id, refund_amount)                       -- mới
```

| refund_id | order_id | refund_amount |
| --- | --- | --- |
| 1 | 3 | 100 |
| 2 | 3 | 50 |
| 3 | 8 | 200 |

Trong dữ liệu ví dụ, đơn 3 của Alice (600) được hoàn hai lần, 100 rồi 50. Đơn 8 của Chloe (450) được hoàn 200.

### Thử cách tự nhiên nhất

Cách đầu tiên ai cũng nghĩ tới là nối thêm `refunds` vào CTE `rfm`, ngay dưới `LEFT JOIN orders`, rồi trừ tiền hoàn khi cộng M:

```sql
LEFT JOIN refunds r ON r.order_id = o.order_id
...
COALESCE(SUM(o.total_amount - COALESCE(r.refund_amount, 0)), 0) AS monetary
```

Chạy thử thì Alice ra 4 đơn, M = 1550. Cả hai con số đều sai. Alice chỉ có 3 đơn, và tiền thực trả là 200 + 300 + 450 = 950.

Lỗi nằm ở đơn 3. Đơn này có hai lần hoàn, nên khi nối với `refunds` nó khớp hai dòng và xuất hiện hai lần:

| order_id | total_amount | refund_amount |
| --- | --- | --- |
| 3 | 600 | 100 |
| 3 | 600 | 50 |

`COUNT` vì thế đếm đơn 3 hai lần. `SUM` cũng cộng đơn 3 hai lần: (600 − 100) + (600 − 50) = 1050, trong khi đúng ra chỉ là 450.

Đây là lỗi rất hay gặp khi nối bảng: **nối một dòng với một bảng có nhiều dòng khớp thì dòng đó bị nhân lên**. Trước khi nối, mỗi đơn là một dòng. Nối với `refunds` xong thì không còn như vậy nữa.

### Cách sửa: gộp trước rồi mới nối

Muốn đơn 3 vẫn chỉ có một dòng, ta gộp `refunds` thành **một dòng mỗi đơn** trước, rồi mới nối:

| order_id | refunded |
| --- | --- |
| 3 | 150 = 100 + 50 |
| 8 | 200 |

Bây giờ mỗi đơn khớp nhiều nhất một dòng, nên không còn bị nhân nữa. CTE `rfm` viết lại như sau, các dòng có `-- mới` là chỗ thay đổi so với Phần 1:

```sql
WITH refund_per_order AS (                                          -- mới
  SELECT order_id, SUM(refund_amount) AS refunded                   -- mới
  FROM refunds                                                      -- mới
  GROUP BY order_id                                                 -- mới
),                                                                  -- mới
rfm AS (
  SELECT c.customer_id, c.name,
         DATE '2024-07-01' - MAX(o.order_date)                      AS recency_days,
         COUNT(o.order_id)                                          AS frequency,
         COALESCE(SUM(o.total_amount - COALESCE(r.refunded, 0)), 0) AS monetary  -- mới
  FROM customers c
  LEFT JOIN orders o
         ON o.customer_id = c.customer_id
        AND o.status = 'Completed'
        AND o.order_date < DATE '2024-07-01'
  LEFT JOIN refund_per_order r ON r.order_id = o.order_id         -- mới
  GROUP BY c.customer_id, c.name
)
```

Alice giờ có M = 950. Con số này dưới 1000, nên điểm M của Alice giảm từ 3 xuống 2. Chloe còn 1050 và vẫn giữ 3 điểm. Những khách khác không có đơn nào được hoàn nên không đổi. Alice vẫn thuộc nhóm `Champions`, vì luật đặt tên nhóm chỉ xét R và F.

> [!TIP]
> **Ghi nhớ:** trước khi nối một bảng mà mỗi khóa có thể có nhiều dòng, hãy gộp bảng đó về một dòng mỗi khóa.

## V2. Khi không có ngưỡng: chấm điểm theo thứ hạng

Ở B3, ngưỡng do doanh nghiệp đặt sẵn, ví dụ R ≤ 30 ngày thì được 3 điểm. Nhưng nhiều đề không cho ngưỡng nào cả, mà nói "chia khách thành 4 mức theo số đơn". Khi đó điểm của một khách phụ thuộc vào việc khách đó đứng ở đâu so với những người khác, chứ không phụ thuộc vào một con số cố định.

Ta lấy F làm ví dụ. Số đơn của 6 khách, xếp từ thấp đến cao: David 0, Emma 0, Frank 1, Ben 2, Alice 3, Chloe 3.

### Thử `NTILE`

`NTILE(4)` sinh ra để làm đúng việc này: xếp các dòng theo thứ tự, rồi chia thành 4 phần có số dòng gần bằng nhau. 6 khách chia 4 phần thì được 2, 2, 1, 1 người.

```sql
NTILE(4) OVER (ORDER BY frequency, customer_id) AS f_score
```

| name | frequency | f_score |
| --- | --- | --- |
| David | 0 | 1 |
| Emma | 0 | 1 |
| Frank | 1 | 2 |
| Ben | 2 | 2 |
| Alice | 3 | **3** |
| Chloe | 3 | **4** |

Nhìn hai dòng cuối: Alice và Chloe cùng 3 đơn, nhưng Alice được 3 điểm còn Chloe được 4. `NTILE` chỉ quan tâm mỗi phần có bao nhiêu dòng, không quan tâm hai dòng có bằng nhau hay không. Phần thứ 3 cần đúng một người, nên ranh giới rơi vào giữa Alice và Chloe.

Như vậy có sai không là tùy đề. Nếu đề nói "chia đều số khách" thì `NTILE` là đúng. Khi đó chỉ cần thêm `customer_id` vào `ORDER BY` như trên để biết chắc ai đứng trước, nếu không mỗi lần chạy có thể ra một kiểu. Còn nếu đề nói "bằng nhau thì cùng điểm" thì cần cách khác.

### Khi bằng nhau phải cùng điểm: `CUME_DIST`

Thay vì chia theo số dòng, ta hỏi mỗi khách: "có bao nhiêu phần khách có số đơn nhỏ hơn hoặc bằng mình?". `CUME_DIST()` trả lời đúng câu hỏi đó. Hai người cùng giá trị luôn nhận cùng một tỉ lệ, nên cũng nhận cùng điểm. Để đổi tỉ lệ thành điểm 1–4, ta nhân 4 rồi làm tròn lên:

```sql
CEIL(4 * CUME_DIST() OVER (ORDER BY frequency))::int AS f_score
```

| name | frequency | CUME_DIST | f_score |
| --- | --- | --- | --- |
| David | 0 | 2/6 | CEIL(1.33) = 2 |
| Emma | 0 | 2/6 | CEIL(1.33) = 2 |
| Frank | 1 | 3/6 | CEIL(2) = 2 |
| Ben | 2 | 4/6 | CEIL(2.67) = 3 |
| Alice | 3 | 6/6 | 4 |
| Chloe | 3 | 6/6 | 4 |

Alice và Chloe giờ cùng 4 điểm. Để ý là không ai được 1 điểm. Lý do là hai khách thấp nhất bằng nhau đã chiếm 2/6 số khách, nhiều hơn 1/4, nên cả hai cùng được đẩy lên 2.

Với R thì nhớ đảo chiều: ít ngày mới là tốt, nên viết `ORDER BY recency_days DESC` để người mua gần nhất đứng cuối và nhận điểm cao. Thang điểm giờ là 1–4 thay vì 1–3, nên luật đặt tên nhóm trong `labeled` cũng phải viết lại theo thang mới.

> [!TIP]
> **Ghi nhớ:** `NTILE` chia đều số người, kể cả khi phải tách hai người bằng nhau. `CUME_DIST` cho người bằng nhau cùng điểm. Đọc kỹ đề để chọn.

## V3. Khi ngưỡng nằm trong một bảng

Viết ngưỡng thẳng vào `CASE` thì mỗi lần doanh nghiệp đổi ngưỡng, ta lại phải sửa query. Vì vậy nhiều hệ thống cất ngưỡng trong một bảng riêng:

```text
rfm            (customer_id, name, recency_days, frequency, monetary)  -- CTE ở Phần 1
rfm_thresholds (metric, score, min_value, max_value)                    -- mới
```

| metric | score | min_value | max_value |
| --- | --- | --- | --- |
| R | 3 | 0 | 30 |
| R | 2 | 31 | 90 |
| R | 1 | 91 | NULL |

Đọc bảng này như sau: với R, từ 0 đến 30 ngày được 3 điểm, từ 31 đến 90 được 2 điểm, từ 91 trở lên được 1 điểm. `max_value` là `NULL` nghĩa là không có giới hạn trên. Bảng thật có thêm các dòng cho F và M, ở đây chỉ dùng phần của R.

### Nối theo khoảng

Bảng này không có cột nào để nối bằng dấu `=` với `rfm`. Câu hỏi ở đây không phải "dòng nào có cùng mã với khách", mà là "dòng nào có khoảng chứa số ngày của khách". Vì thế điều kiện nối là phép so sánh lớn nhỏ. Kiểu nối này gọi là non-equi join. Cách viết đầu tiên nghĩ tới là dùng `BETWEEN`:

```sql
LEFT JOIN rfm_thresholds t
       ON t.metric = 'R'
      AND c.recency_days BETWEEN t.min_value AND t.max_value
```

### Cái bẫy `NULL`

Thử từng khách. Alice có 13 ngày, khớp dòng 0–30. Ben có 42 ngày, khớp dòng 31–90. Nhưng Chloe có 127 ngày và không khớp dòng nào. Dòng cuối là 91–`NULL`, và `127 BETWEEN 91 AND NULL` có nghĩa là `127 >= 91 AND 127 <= NULL`. Vế sau so sánh với `NULL` nên không ra `true`, kéo theo cả điều kiện không đúng.

Cách sửa là viết tay điều kiện, và nói rõ rằng `NULL` nghĩa là "không có trần". Khách chưa mua (R là `NULL`) thì không khớp dòng nào, nên ta dùng `COALESCE` để cho họ điểm thấp nhất:

```sql
scored AS (
  SELECT c.*, COALESCE(t.score, 1) AS r_score                       -- mới
  FROM rfm c
  LEFT JOIN rfm_thresholds t                                        -- mới
         ON t.metric = 'R'                                          -- mới
        AND c.recency_days >= t.min_value                           -- mới
        AND (t.max_value IS NULL OR c.recency_days <= t.max_value)  -- mới
)
```

| name | recency_days | matched row | r_score |
| --- | --- | --- | --- |
| Alice | 13 | 0..30 | 3 |
| Ben | 42 | 31..90 | 2 |
| Chloe | 127 | 91..NULL | 1 |
| David | NULL | no match → `COALESCE` | 1 |
| ... | | | |

F và M làm tương tự. Mỗi chỉ số cần một lần `LEFT JOIN rfm_thresholds` riêng, đặt alias khác nhau (`tf`, `tm`) để không lẫn.

> [!TIP]
> **Ghi nhớ:** khi cột giới hạn có thể là `NULL`, đừng dùng `BETWEEN`. Viết tay điều kiện và xử lý `NULL` ngay trong đó.

## V4. Khi luật đặt tên nằm trong một bảng

Giống như ngưỡng ở V3, luật đặt tên nhóm trong CTE `labeled` cũng có thể chuyển vào một bảng:

```text
scored        (customer_id, name, ..., r_score, f_score, m_score)  -- CTE ở Phần 1
segment_rules (priority, segment, pattern)                         -- mới
```

| priority | segment | pattern |
| --- | --- | --- |
| 1 | Champions | `^33` |
| 2 | Loyal | `^[23][23]` |
| 3 | New | `^31` |
| 4 | At Risk | `^1[23]` |

Mỗi luật được viết bằng một regex, áp lên **mã RFM** của khách, tức 3 điểm ghép thành một chuỗi. Alice có mã `'333'`, Ben `'222'`, Chloe `'133'`. Đọc các regex như sau: `^33` là "mã bắt đầu bằng 33", tức R = 3 và F = 3. `^[23][23]` là "hai chữ số đầu đều là 2 hoặc 3". `priority` nhỏ hơn thì được ưu tiên hơn.

### Thử `JOIN` thường

Cách đầu tiên nghĩ tới là nối khách với mọi luật mà mã của khách khớp (`~` nghĩa là "khớp regex"):

```sql
JOIN segment_rules r ON CONCAT(s.r_score, s.f_score, s.m_score) ~ r.pattern
```

| name | rfm_code | matched rule |
| --- | --- | --- |
| Alice | 333 | Champions (1) |
| Alice | 333 | Loyal (2) |
| Ben | 222 | Loyal (2) |
| Chloe | 133 | At Risk (4) |

Có hai chỗ sai. Alice xuất hiện hai lần, vì mã `333` khớp cả `^33` lẫn `^[23][23]`. Còn David, Emma, Frank (mã `111`) không khớp luật nào nên biến mất.

Với `CASE` ở Phần 1 ta không gặp chuyện này, vì `CASE` tự dừng ở nhánh đúng đầu tiên. Trong bảng luật, cột `priority` đóng vai trò thứ tự đó. Việc cần làm là: với mỗi khách, chỉ lấy **một** luật, đó là luật khớp có `priority` nhỏ nhất.

### Lấy một luật tốt nhất cho mỗi khách

Viết bằng lời: "với từng khách, tìm các luật khớp, xếp theo `priority`, lấy luật đầu tiên". Dịch sát câu đó sang SQL là một subquery chạy lại cho từng khách. Đó chính là việc `LATERAL` làm:

```sql
labeled AS (
  SELECT s.*, COALESCE(best.segment, 'Lost') AS segment             -- mới
  FROM scored s
  LEFT JOIN LATERAL (                                               -- mới
    SELECT r.segment                                                -- mới
    FROM segment_rules r                                            -- mới
    WHERE CONCAT(s.r_score, s.f_score, s.m_score) ~ r.pattern       -- mới
    ORDER BY r.priority                                             -- mới
    LIMIT 1                                                         -- mới
  ) best ON TRUE                                                    -- mới
)
```

Đọc từ trong ra ngoài:
- Subquery tìm các luật khớp với mã của khách `s`, xếp theo `priority` và giữ một dòng (`LIMIT 1`).
- Bình thường subquery trong `FROM` không được nhắc tới bảng khác. Chữ `LATERAL` cho phép nó dùng cột của `s`, và vì thế subquery được chạy lại cho từng khách.
- `LEFT JOIN ... ON TRUE` giữ cả những khách mà subquery không trả về gì. Điều kiện đã nằm sẵn trong subquery, nên `ON` chỉ cần `TRUE`. Những khách đó nhận `NULL`, và `COALESCE` đổi thành `'Lost'`.

Alice giờ chỉ còn luật `Champions` (priority 1 thắng priority 2). David, Emma, Frank được giữ lại với nhãn `Lost`. Kết quả giống hệt Phần 1.

> [!TIP]
> **Ghi nhớ:** "mỗi X lấy một dòng tốt nhất trong bảng Y" thì viết `LEFT JOIN LATERAL (... ORDER BY ... LIMIT 1) ON TRUE`.

## V5. Khi cần so sánh hai thời điểm

Đề hỏi: giữa ngày 2024-04-01 (gọi là q1) và ngày 2024-07-01 (q2), những khách nào đã chuyển nhóm?

Cách nghĩ đơn giản nhất là chạy toàn bộ Phần 1 hai lần, mỗi lần với một ngày chốt, rồi đặt hai kết quả cạnh nhau. Ta sẽ làm đúng như vậy, chỉ là gói trong một query.

### Nhân mỗi khách thành hai bản

Trước hết, ta tạo một bảng nhỏ chứa hai ngày chốt bằng `VALUES`:

| snap | snap_date |
| --- | --- |
| q1 | 2024-04-01 |
| q2 | 2024-07-01 |

`CROSS JOIN` khách với bảng này thì mỗi khách thành hai dòng, mỗi ngày chốt một dòng. Sau đó, khi nối với `orders`, ta cho mỗi dòng chỉ thấy các đơn trước ngày chốt của chính nó bằng điều kiện `o.order_date < s.snap_date`, đặt trong `ON` như B1. CTE `rfm` viết lại như sau:

```sql
WITH snapshots(snap, snap_date) AS (                                -- mới
  VALUES ('q1', DATE '2024-04-01'), ('q2', DATE '2024-07-01')       -- mới
),                                                                  -- mới
rfm AS (
  SELECT c.customer_id, c.name, s.snap,                             -- mới: s.snap
         s.snap_date - MAX(o.order_date)  AS recency_days,          -- mới: s.snap_date
         COUNT(o.order_id)                AS frequency,
         COALESCE(SUM(o.total_amount), 0) AS monetary
  FROM customers c
  CROSS JOIN snapshots s                                            -- mới
  LEFT JOIN orders o
         ON o.customer_id = c.customer_id
        AND o.status = 'Completed'
        AND o.order_date < s.snap_date                              -- mới
  GROUP BY c.customer_id, c.name, s.snap, s.snap_date               -- mới
)
```

`scored` và `labeled` giữ nguyên, vì `SELECT *` tự mang cột `snap` theo. Sau `labeled`, mỗi khách có hai dòng:

| name | snap | orders seen | recency_days | frequency | segment |
| --- | --- | --- | --- | --- | --- |
| Alice | q1 | 1 | 22 | 1 | New |
| Alice | q2 | 1, 2, 3 | 13 | 3 | Champions |
| Ben | q1 | (none) | NULL | 0 | Lost |
| Ben | q2 | 4, 5 | 42 | 2 | Loyal |
| ... | | | | | |

Theo dõi Alice. Tại q1, Alice mới có đơn 1 (ngày 03-10), nên R = 22 ngày, F = 1, và thuộc nhóm `New`. Tại q2, Alice đã có 3 đơn và thành `Champions`.

### Đặt hai kết quả cạnh nhau

Giờ ta muốn mỗi khách một dòng, với hai cột: nhóm tại q1 và nhóm tại q2. `MAX(segment) FILTER (WHERE snap = 'q1')` có nghĩa là "lấy `segment` trong các dòng q1". Mỗi khách chỉ có đúng một dòng q1, nên `MAX` ở đây không chọn gì cả. Nó chỉ có mặt vì `GROUP BY` bắt buộc phải có một hàm gộp.

```sql
SELECT customer_id, name, segment_q1, segment_q2
FROM (
  SELECT customer_id, name,
         MAX(segment) FILTER (WHERE snap = 'q1') AS segment_q1,
         MAX(segment) FILTER (WHERE snap = 'q2') AS segment_q2
  FROM labeled
  GROUP BY customer_id, name
) p
WHERE segment_q1 <> segment_q2
ORDER BY customer_id;
```

| name | segment_q1 | segment_q2 |
| --- | --- | --- |
| Alice | New | Champions |
| Ben | Lost | Loyal |
| Chloe | Loyal | At Risk |

David, Emma và Frank ở nhóm `Lost` cả hai lần nên bị lọc ra. Nếu bỏ `WHERE`, rồi `GROUP BY segment_q1, segment_q2` và đếm, ta được bảng "bao nhiêu khách chuyển từ nhóm nào sang nhóm nào".

Có một chỗ dễ sai: viết `o.order_date < s.snap_date` ở `WHERE` thay vì trong `ON`. Ben có 2 đơn (04-05 và 05-20), cả hai đều sau q1. `WHERE` sẽ xóa cả hai dòng của Ben ở q1, nên Ben không còn dòng q1 nào, không có `segment_q1`, và biến mất khỏi kết quả. Đúng ra Ben phải hiện là `Lost → Loyal`.

> [!TIP]
> **Ghi nhớ:** muốn so sánh nhiều thời điểm, hãy `CROSS JOIN` với một bảng thời điểm, rồi dùng `FILTER` để xoay các dòng thành cột.

## V6. Bao nhiêu phần trăm khách tạo ra 80% doanh thu?

Quy tắc 80/20 nói rằng một nhóm nhỏ khách hàng thường tạo ra phần lớn doanh thu. Đề muốn kiểm tra điều đó trên dữ liệu: bao nhiêu phần trăm khách tạo ra 80% doanh thu? Bài này không cần nhóm RFM, chỉ cần tổng tiền của mỗi khách, tức cột `monetary` của CTE `rfm`. Khách chưa mua (M = 0) được bỏ ra.

### Cách nghĩ

Xếp khách từ giàu đến nghèo, rồi đi từ trên xuống. Với mỗi khách, ta hỏi: "những người giàu hơn mình đã tạo ra bao nhiêu?". Nếu con số đó chưa tới 80% tổng doanh thu, tức là vẫn còn thiếu, thì khách này được tính vào nhóm top.

Tổng doanh thu là 3120, nên 80% là 2496:

| name | revenue | higher_revenue | is_top |
| --- | --- | --- | --- |
| Chloe | 1250 | 0 (nobody richer) | true |
| Alice | 1100 | 1250 | true |
| Ben | 650 | 1250 + 1100 = 2350 < 2496 | true |
| Frank | 120 | 3000 ≥ 2496 | **false** |

Ba trên bốn khách (75%) tạo ra 80% doanh thu.

### Phần tinh tế: "giàu hơn hẳn"

Cột `higher_revenue` là tổng doanh thu của những người **giàu hơn hẳn** mình. Nghĩa là không tính chính mình, và cũng không tính những người có doanh thu **bằng** mình. Nếu tính cả người bằng mình, hai khách cùng 650 sẽ bị đối xử khác nhau tùy ai đứng trước: một người được vào top, người kia thì không. Đề muốn công bằng: bằng nhau thì cùng vào hoặc cùng ra.

Khung cửa sổ sau làm đúng điều đó:
- `ORDER BY revenue DESC RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` cộng từ đầu danh sách đến hết nhóm người có cùng doanh thu với dòng hiện tại.
- `EXCLUDE GROUP` bỏ nhóm cùng doanh thu đó ra khỏi phép cộng, kể cả chính mình. Phần còn lại đúng là những người giàu hơn hẳn.

Chloe đứng đầu nên không có ai giàu hơn. Cộng một tập rỗng thì `SUM` ra `NULL` chứ không ra 0, và `NULL < 2496` không ra `true`, nên người giàu nhất lại bị loại khỏi top. Vì vậy cần bọc `COALESCE(..., 0)` bên ngoài.

Giữ CTE `rfm`, thay phần còn lại bằng:

```sql
revenue AS (
  SELECT customer_id, name, monetary AS revenue FROM rfm WHERE monetary > 0
),
ranked AS (
  SELECT *,
         COALESCE(SUM(revenue) OVER (ORDER BY revenue DESC
                  RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW EXCLUDE GROUP), 0) AS higher_revenue,
         SUM(revenue) OVER () AS total_revenue
  FROM revenue
)
SELECT *, higher_revenue < 0.8 * total_revenue AS is_top
FROM ranked
ORDER BY revenue DESC;
```

Nếu đề chỉ cần một dòng kết quả, ví dụ "3 trên 4 khách, 75%", thì gom lại bằng `COUNT(*) FILTER (WHERE is_top)` và `COUNT(*)`.

> [!TIP]
> **Ghi nhớ:** "tổng của những người hơn hẳn mình" thì viết `SUM(...) OVER (ORDER BY ... RANGE ... EXCLUDE GROUP)`, và nhớ bọc `COALESCE(..., 0)` cho người đứng đầu.
