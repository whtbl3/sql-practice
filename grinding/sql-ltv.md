# LTV (giá trị vòng đời khách hàng)

<style>
.markdown-preview tr:has(.drop) td { background: rgba(191, 97, 106, 0.16) !important; }
</style>

> Bài liên quan: `ltv/01`–`04`. Output đều chạy thật bằng `check.py`.

## Bài toán

Cửa hàng muốn biết **trung bình một khách mang về bao nhiêu tiền** trong suốt thời gian mua hàng (Lifetime Value, LTV). Khách mua lần đầu vào tháng nào thì "đáng tiền" hơn? Và họ chi phần lớn tiền ngay tháng đầu, hay chi dần về sau?

Có hai chỗ khiến bài này không đơn giản là "tổng doanh thu chia số khách":
- Khách được chia theo **cohort**, tức tháng mua lần đầu, giống doc cohort. Khách cũ đã có nhiều tháng để mua, khách mới thì chưa, nên phải so sánh trong cùng cohort.
- "Trung bình" có hai nghĩa, và hai cách tính thường ra hai con số khác nhau:
  - **Tỉ số của tổng**: cộng tiền của cả nhóm rồi mới chia. Khách chi nhiều có trọng số lớn hơn.
  - **Trung bình các tỉ số**: tính tỉ số cho từng khách rồi lấy trung bình. Mỗi khách có trọng số như nhau.

## Dữ liệu

Hai bảng, quan hệ **1 khách – nhiều đơn**. Số tiền tính bằng nghìn đồng.

`customers`: mỗi dòng = 1 khách. Cột `channel` chỉ dùng ở V2.

| customer_id | name | channel |
| --- | --- | --- |
| 1 | Alice | Facebook |
| 2 | Ben | Facebook |
| 3 | Chloe | Shopee |
| 4 | David | Shopee |
| 5 | Emma | Zalo |
| 6 | Frank | Referral |

`orders`: mỗi dòng = 1 đơn. Chỉ đơn `delivered` được tính.

| order_id | customer_id | order_date | amount_k | status |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2024-01-10 | 200 | delivered |
| 2 | 2 | 2024-01-20 | 400 | delivered |
| 3 | 1 | 2024-01-25 | 100 | delivered |
| 4 | 3 | 2024-01-28 | 500 | cancelled |
| 5 | 3 | 2024-02-03 | 100 | delivered |
| 6 | 4 | 2024-02-15 | 300 | delivered |
| 7 | 1 | 2024-03-05 | 300 | delivered |
| 8 | 5 | 2024-03-08 | 250 | delivered |
| 9 | 3 | 2024-04-12 | 500 | delivered |
| 10 | 2 | 2024-04-19 | 150 | delivered |
| 11 | 4 | 2024-05-10 | 200 | delivered |

Hai chỗ dễ sai: đơn **đầu tiên** của Chloe (01-28) **đã bị hủy**, và Frank **chưa mua đơn nào**.

## Lộ trình

Câu hỏi của mạch chính: với mỗi cohort, LTV trung bình mỗi khách là bao nhiêu, và bao nhiêu phần trăm doanh thu đến ngay trong tháng đầu?

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Lọc đơn hợp lệ, tìm cohort | CTE `counted` | 1 đơn hợp lệ, kèm cohort |
| B2 | Doanh thu mỗi khách | CTE `per_customer` | **1 khách** |
| B3 | Gộp theo cohort | query cuối | **1 cohort** |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Lọc đơn hợp lệ, tìm cohort (CTE `counted`)

**Ý tưởng:** cohort của khách là tháng của **đơn hợp lệ đầu tiên**. Vì vậy phải bỏ đơn bị hủy **trước**, rồi mới tìm ngày nhỏ nhất. Mỗi đơn mang theo cohort của khách, để B2 biết đơn nào rơi vào tháng đầu.

**Ví dụ nhỏ:** Chloe.

| order_id | order_date | status | reason |
| --- | --- | --- | --- |
| 4 | 2024-01-28 | cancelled | <span class="drop">cancelled, removed</span> |
| 5 | 2024-02-03 | delivered | kept, first valid order → cohort 2024-02 |
| 9 | 2024-04-12 | delivered | kept |

```sql
WITH counted AS (
  SELECT customer_id, order_date, amount_k,
         DATE_TRUNC('month', MIN(order_date) OVER (PARTITION BY customer_id))::date AS cohort
  FROM orders
  WHERE status = 'delivered'
)
```

`MIN(order_date) OVER (PARTITION BY customer_id)` tìm ngày nhỏ nhất trong các đơn của khách rồi ghi lên mọi dòng của khách đó. `WHERE` chạy trước hàm cửa sổ, nên đơn bị hủy đã bị bỏ khi tìm ngày nhỏ nhất.

> [!CAUTION]
> ❌ **Tìm `MIN(order_date)` trước, lọc `delivered` sau**
>
> Ví dụ tính `MIN` trong một truy vấn con, rồi mới lọc ở tầng ngoài. Đơn bị hủy ngày 01-28 vẫn tham gia vào `MIN`, nên Chloe bị xếp vào cohort **2024-01**, trong khi đơn hợp lệ đầu tiên của Chloe là tháng 2.
>
> → **Sửa:** đặt `WHERE status = 'delivered'` ở cùng tầng với hàm cửa sổ, để lọc chạy trước.

## B2. Doanh thu mỗi khách (CTE `per_customer`)

**Ý tưởng:** gom các đơn của mỗi khách thành một dòng, kèm hai con số: doanh thu **trong tháng cohort** và doanh thu **cả vòng đời**. `SUM(...) FILTER (WHERE ...)` cho phép tính nhiều "cửa sổ" khác nhau trên cùng một dòng.

**Ví dụ nhỏ:** Alice, cohort 2024-01.

| order_date | amount_k | in cohort month? |
| --- | --- | --- |
| 2024-01-10 | 200 | yes |
| 2024-01-25 | 100 | yes |
| 2024-03-05 | 300 | no |

→

| customer | cohort | first_month | lifetime | share |
| --- | --- | --- | --- | --- |
| Alice | 2024-01 | 300 = 200 + 100 | 600 | 50.0% |
| ... | | | | |

```sql
per_customer AS (
  SELECT customer_id, cohort,
         SUM(amount_k) FILTER (WHERE DATE_TRUNC('month', order_date) = cohort) AS first_month,
         SUM(amount_k)                                                         AS lifetime
  FROM counted
  GROUP BY customer_id, cohort
)
```

`GROUP BY customer_id, cohort`: mỗi khách chỉ có một cohort, nên thêm `cohort` vào `GROUP BY` không làm tách nhóm. Nó chỉ để cột `cohort` được phép xuất hiện trong `SELECT`.

## B3. Gộp theo cohort (query cuối)

**Ý tưởng:** mỗi cohort một dòng. LTV trung bình là `AVG(lifetime)`. Tỉ trọng tháng đầu tính theo cả hai cách ở phần Bài toán, đặt cạnh nhau.

**Ví dụ nhỏ:** cohort 2024-01 có Alice và Ben.

| customer | first_month | lifetime | share |
| --- | --- | --- | --- |
| Alice | 300 | 600 | 50.0% |
| Ben | 400 | 550 | 72.7% |

- Tỉ số của tổng: (300 + 400) / (600 + 550) = 700 / 1150 = **60.9%**.
- Trung bình các tỉ số: (50.0% + 72.7%) / 2 = **61.4%**.

Hai con số gần nhau ở đây, nhưng ở cohort 2024-02 chúng cách nhau xa hơn (36.4% và 38.3%). Đề phải nói rõ muốn cách nào.

```sql
SELECT TO_CHAR(cohort, 'YYYY-MM') AS cohort_month,
       COUNT(*)                     AS customers,
       SUM(lifetime)                AS lifetime_revenue,
       ROUND(AVG(lifetime))         AS avg_ltv,
       SUM(first_month)             AS first_month_revenue,
       ROUND(100.0 * SUM(first_month) / SUM(lifetime), 1) AS share_of_totals_pct,
       ROUND(AVG(100.0 * first_month / lifetime), 1)      AS avg_customer_share_pct
FROM per_customer
GROUP BY cohort
ORDER BY cohort;
```

> [!CAUTION]
> ❌ **Dùng một cách khi đề hỏi cách kia**
>
> "Bao nhiêu phần trăm doanh thu của cohort đến trong tháng đầu" là tỉ số của tổng: `SUM(first_month) / SUM(lifetime)`. "Một khách điển hình chi bao nhiêu phần trăm trong tháng đầu" là trung bình các tỉ số: `AVG(first_month / lifetime)`. Cohort 2024-02 ra 36.4% với cách thứ nhất và 38.3% với cách thứ hai.
>
> → **Sửa:** đọc kỹ đề hỏi về **tổng tiền** hay về **một khách**, rồi chọn công thức tương ứng.

## Tổng kết: query đầy đủ

```sql
WITH counted AS (                                  -- B1: đơn hợp lệ, kèm cohort
  SELECT customer_id, order_date, amount_k,
         DATE_TRUNC('month', MIN(order_date) OVER (PARTITION BY customer_id))::date AS cohort
  FROM orders
  WHERE status = 'delivered'
),
per_customer AS (                                  -- B2: doanh thu mỗi khách
  SELECT customer_id, cohort,
         SUM(amount_k) FILTER (WHERE DATE_TRUNC('month', order_date) = cohort) AS first_month,
         SUM(amount_k)                                                         AS lifetime
  FROM counted
  GROUP BY customer_id, cohort
)
SELECT TO_CHAR(cohort, 'YYYY-MM') AS cohort_month,  -- B3: gộp theo cohort
       COUNT(*)                     AS customers,
       SUM(lifetime)                AS lifetime_revenue,
       ROUND(AVG(lifetime))         AS avg_ltv,
       SUM(first_month)             AS first_month_revenue,
       ROUND(100.0 * SUM(first_month) / SUM(lifetime), 1) AS share_of_totals_pct,
       ROUND(AVG(100.0 * first_month / lifetime), 1)      AS avg_customer_share_pct
FROM per_customer
GROUP BY cohort
ORDER BY cohort;
```

Doanh thu từng khách sau B2:

| customer | cohort | first_month | lifetime |
| --- | --- | --- | --- |
| Alice | 2024-01 | 300 | 600 |
| Ben | 2024-01 | 400 | 550 |
| Chloe | 2024-02 | 100 | 600 |
| David | 2024-02 | 300 | 500 |
| Emma | 2024-03 | 250 | 250 |

Kết quả cuối:

| cohort_month | customers | lifetime_revenue | avg_ltv | first_month_revenue | share_of_totals_pct | avg_customer_share_pct |
| --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 2 | 1150 | 575 | 700 | 60.9 | 61.4 |
| 2024-02 | 2 | 1100 | 550 | 400 | 36.4 | 38.3 |
| 2024-03 | 1 | 250 | 250 | 250 | 100.0 | 100.0 |

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính: đo giá trị trong N ngày đầu thay vì cả vòng đời, ước tính LTV bằng công thức, hay vẽ đường LTV tăng dần theo tuổi cohort. Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi đo giá trị 90 ngày đầu

So LTV cả vòng đời giữa các cohort là không công bằng: cohort tháng 1 đã có 5 tháng để mua, cohort tháng 3 mới có 3 tháng. Một cách so công bằng hơn: **mỗi khách chỉ tính tiền trong 90 ngày đầu kể từ đơn đầu tiên**. Đề hỏi: tại ngày 2024-05-31, giá trị 90 ngày đầu trung bình của mỗi tháng thu hút khách là bao nhiêu?

### Cửa sổ 90 ngày là từ ngày 0 đến ngày 89

Nếu đơn đầu là ngày `first_date`, thì 90 ngày đầu là `first_date`, `first_date + 1`, ..., `first_date + 89`. Đếm cả ngày đầu là 90 ngày. Ben có đơn đầu ngày 01-20, nên cửa sổ kết thúc ngày 04-18. Đơn 150 của Ben ngày 04-19 là ngày thứ 91, nằm ngoài cửa sổ:

```sql
WITH firsts AS (
  SELECT customer_id, order_date, amount_k,
         MIN(order_date) OVER (PARTITION BY customer_id) AS first_date
  FROM orders
  WHERE status = 'delivered'
),
per_customer AS (
  SELECT customer_id, first_date,
         SUM(amount_k) FILTER (WHERE order_date <= first_date + 89) AS value_90d
  FROM firsts
  GROUP BY customer_id, first_date
)
```

Viết `first_date + 90` là một lỗi rất dễ mắc: cửa sổ thành 91 ngày, và Ben ra 550 thay vì 400.

### Thử cách tự nhiên nhất

Có giá trị 90 ngày của từng khách rồi, gộp theo tháng thu hút khách:

| acquisition_month | customers | avg_value_90d |
| --- | --- | --- |
| 2024-01 | 2 | 500 |
| 2024-02 | 2 | 550 |
| 2024-03 | 1 | **250** |

Tháng 3 trông kém hẳn. Nhưng Emma có đơn đầu ngày 03-08, nên cửa sổ 90 ngày của Emma kéo dài tới 06-05. Tại ngày chốt 05-31, cửa sổ đó **chưa trọn**: Emma vẫn còn gần một tuần để mua thêm. Đem một cửa sổ chưa trọn so với những cửa sổ đã trọn là không công bằng, chính là điều ta đang muốn tránh.

### Cách sửa: chỉ giữ khách đã đi hết cửa sổ

Một khách được tính khi cả cửa sổ đã nằm trước ngày chốt: `first_date + 89 <= ngày_chốt`. Khách nào chưa đủ thì bỏ hẳn:

| customer | first_date | window ends | ≤ 05-31? |
| --- | --- | --- | --- |
| Alice | 2024-01-10 | 2024-04-08 | yes |
| Ben | 2024-01-20 | 2024-04-18 | yes |
| Chloe | 2024-02-03 | 2024-05-02 | yes |
| David | 2024-02-15 | 2024-05-14 | yes |
| Emma | 2024-03-08 | 2024-06-05 | <span class="drop">no, left out</span> |

```sql
SELECT TO_CHAR(first_date, 'YYYY-MM') AS acquisition_month,
       COUNT(*) AS customers,
       ROUND(AVG(value_90d)) AS avg_value_90d
FROM per_customer
WHERE first_date + 89 <= DATE '2024-05-31'
GROUP BY 1
ORDER BY 1;
```

| acquisition_month | customers | avg_value_90d |
| --- | --- | --- |
| 2024-01 | 2 | 500 |
| 2024-02 | 2 | 550 |

> [!TIP]
> **Ghi nhớ:** cửa sổ N ngày là `first_date + (N − 1)`. Chỉ so những khách đã đi hết cửa sổ: `first_date + N − 1 <= ngày_chốt`.

## V2. Khi ước tính LTV bằng công thức

Nhiều công ty ước tính LTV theo từng kênh thu hút khách bằng một công thức quen thuộc:

```text
LTV = AOV × tần suất mua mỗi năm × số năm khách ở lại
```

- **AOV** (giá trị đơn trung bình) = doanh thu / số đơn.
- **Tần suất** = số đơn / số khách.
- **Số năm ở lại** = 1 / tỉ lệ rời bỏ mỗi năm. Rời bỏ 50% mỗi năm thì trung bình ở lại 2 năm.

Tỉ lệ rời bỏ của mỗi kênh nằm trong một bảng riêng:

```text
channel_churn (channel, annual_churn_rate)   -- mới
```

| channel | annual_churn_rate |
| --- | --- |
| Facebook | 0.50 |
| Shopee | 0.25 |
| Zalo | 0.00 |
| Referral | 0.20 |

### Thử cách tự nhiên nhất

Cách nghĩ nhanh cho AOV của kênh là tính AOV của từng khách, rồi lấy trung bình:

| channel | customer | AOV of customer | `AVG` of these |
| --- | --- | --- | --- |
| Facebook | Alice | 200 (600 / 3 orders) | 237.5 |
| Facebook | Ben | 275 (550 / 2 orders) | 237.5 |

Kết quả 237.5 là trung bình các tỉ số. Nhưng AOV theo định nghĩa là "doanh thu / số đơn" của cả kênh, tức tỉ số của tổng: (600 + 550) / (3 + 2) = **230**. Ben có ít đơn hơn, nhưng cách lấy trung bình cho Ben trọng số bằng Alice.

### Cách đúng: cộng trước, chia sau

Tính tổng số khách, số đơn, doanh thu cho mỗi kênh, rồi mới chia. Có thêm ba chỗ cần cẩn thận:
- Đi **từ bảng kênh** (`channel_churn`) rồi `LEFT JOIN` đơn hàng, để kênh chưa có khách nào (Referral) vẫn hiện ra.
- Mọi phép chia bọc `NULLIF(mẫu, 0)`. Kênh không có đơn thì AOV là `NULL`, không gây lỗi chia cho 0. Zalo có tỉ lệ rời bỏ bằng 0 thì số năm ở lại là `NULL` (không xác định), không phải vô cực.
- Nhân các giá trị **chưa làm tròn**, rồi mới làm tròn một lần ở cuối. Làm tròn AOV trước rồi mới nhân thì sai số bị nhân lên.

```sql
WITH counted AS (
  SELECT c.channel, o.customer_id, o.amount_k
  FROM customers c
  JOIN orders o ON o.customer_id = c.customer_id
  WHERE o.status = 'delivered'
    AND o.order_date >= DATE '2024-01-01' AND o.order_date < DATE '2025-01-01'
),
by_channel AS (
  SELECT ch.channel, ch.annual_churn_rate,
         COUNT(DISTINCT co.customer_id)  AS customers,
         COUNT(co.customer_id)           AS orders,
         COALESCE(SUM(co.amount_k), 0)   AS revenue
  FROM channel_churn ch
  LEFT JOIN counted co ON co.channel = ch.channel
  GROUP BY ch.channel, ch.annual_churn_rate
),
metrics AS (
  SELECT channel, customers, orders, revenue,
         revenue::numeric / NULLIF(orders, 0)    AS aov,
         orders::numeric  / NULLIF(customers, 0) AS annual_frequency,
         1 / NULLIF(annual_churn_rate, 0)        AS lifespan_years
  FROM by_channel
)
SELECT channel, customers, orders, revenue,
       ROUND(aov) AS aov,
       ROUND(annual_frequency, 2) AS annual_frequency,
       ROUND(lifespan_years, 2) AS lifespan_years,
       ROUND(aov * annual_frequency * lifespan_years) AS ltv
FROM metrics
ORDER BY channel;
```

| channel | customers | orders | revenue | aov | annual_frequency | lifespan_years | ltv |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Facebook | 2 | 5 | 1150 | 230 | 2.50 | 2.00 | 1150 |
| Referral | 0 | 0 | 0 | NULL | NULL | 5.00 | NULL |
| Shopee | 2 | 4 | 1100 | 275 | 2.00 | 4.00 | 2200 |
| Zalo | 1 | 1 | 250 | 250 | 1.00 | NULL | NULL |

Đơn bị hủy của Chloe bị loại ở `counted`, nên Shopee có 4 đơn chứ không phải 5. `revenue::numeric` ép kiểu để phép chia không bị chia số nguyên.

> [!TIP]
> **Ghi nhớ:** AOV và tần suất là tỉ số của tổng (cộng trước, chia sau). Bọc mọi mẫu số trong `NULLIF(..., 0)`, và chỉ làm tròn ở bước cuối.

## V3. Khi vẽ đường LTV theo tuổi cohort

Đề muốn biết LTV của mỗi cohort **tăng dần thế nào theo từng tháng tuổi**: sau 0, 1, 2, ... tháng kể từ tháng cohort, trung bình mỗi khách đã mang về bao nhiêu? Báo cáo tính tới hết tháng 2024-05, và tháng nào cũng phải có dòng, kể cả tháng không có doanh thu.

Đây là doanh thu **cộng dồn** chia cho **số khách của cohort**:

| cohort | month | revenue that month | cumulative | cum_ltv = cumulative / 2 |
| --- | --- | --- | --- | --- |
| 2024-01 | 2024-01 | 700 | 700 | 350 |
| 2024-01 | 2024-02 | 0 | 700 | 350 |
| 2024-01 | 2024-03 | 300 | 1000 | 500 |
| 2024-01 | 2024-04 | 150 | 1150 | 575 |
| 2024-01 | 2024-05 | 0 | 1150 | 575 |

### Thử cách tự nhiên nhất

Cách nghĩ nhanh là tính doanh thu theo (cohort, tháng) bằng `GROUP BY`, rồi cộng dồn:

| cohort | month | revenue | cumulative |
| --- | --- | --- | --- |
| 2024-01 | 2024-01 | 700 | 700 |
| 2024-01 | 2024-03 | 300 | 1000 |
| 2024-01 | 2024-04 | 150 | 1150 |
| ... | | | |

Tháng 2 và tháng 5 của cohort 2024-01 biến mất, vì không ai trong cohort mua gì trong hai tháng đó. `GROUP BY` chỉ tạo dòng cho tháng có dữ liệu. Nhưng đường LTV cần đủ mọi tháng: ở tháng 2, LTV vẫn là 350, chứ không phải "không có".

Một lỗi khác cũng hay gặp là chia cho **số khách có mua trong tháng đó** thay vì số khách của cả cohort. Tháng 3, chỉ Alice mua, nên chia cho 1 ra 1000, gấp đôi giá trị đúng là 500. LTV là giá trị **mỗi khách của cohort**, kể cả những khách tháng đó không mua.

### Cách sửa: dựng lưới cohort × tháng

Tạo sẵn một lưới: mỗi cohort một dòng cho mỗi tháng, từ tháng cohort tới tháng cuối báo cáo. Sau đó `LEFT JOIN` doanh thu vào lưới. Tháng không có doanh thu nhận `NULL`, và `COALESCE(..., 0)` đổi nó thành 0.

```sql
WITH counted AS (
  SELECT customer_id, order_date, amount_k,
         DATE_TRUNC('month', MIN(order_date) OVER (PARTITION BY customer_id))::date AS cohort
  FROM orders
  WHERE status = 'delivered'
    AND order_date <= DATE '2024-05-31'
),
sizes AS (                                         -- số khách mỗi cohort
  SELECT cohort, COUNT(DISTINCT customer_id) AS cohort_size
  FROM counted
  GROUP BY cohort
),
monthly AS (                                       -- doanh thu mỗi (cohort, tháng)
  SELECT cohort, DATE_TRUNC('month', order_date)::date AS m, SUM(amount_k) AS revenue
  FROM counted
  GROUP BY cohort, DATE_TRUNC('month', order_date)
),
grid AS (                                          -- lưới cohort × mọi tháng tới cuối báo cáo
  SELECT s.cohort, s.cohort_size, g.m::date AS m
  FROM sizes s
  CROSS JOIN LATERAL generate_series(s.cohort, DATE '2024-05-01', INTERVAL '1 month') AS g(m)
)
SELECT TO_CHAR(g.cohort, 'YYYY-MM') AS cohort_month,
       (EXTRACT(YEAR FROM g.m)::int * 12 + EXTRACT(MONTH FROM g.m)::int)
     - (EXTRACT(YEAR FROM g.cohort)::int * 12 + EXTRACT(MONTH FROM g.cohort)::int) AS month_offset,
       g.cohort_size,
       COALESCE(mo.revenue, 0) AS revenue,
       ROUND(SUM(COALESCE(mo.revenue, 0)) OVER (PARTITION BY g.cohort ORDER BY g.m)
             / g.cohort_size::numeric) AS cum_ltv
FROM grid g
LEFT JOIN monthly mo ON mo.cohort = g.cohort AND mo.m = g.m
ORDER BY g.cohort, g.m;
```

`CROSS JOIN LATERAL generate_series(s.cohort, ...)`: với mỗi cohort, sinh dãy tháng **bắt đầu từ chính tháng cohort đó**. `LATERAL` cho phép `generate_series` dùng cột `s.cohort` của dòng bên trái. Nhờ vậy cohort 2024-03 bắt đầu từ tháng 3, không bị sinh thừa tháng 1 và 2.

| cohort_month | month_offset | cohort_size | revenue | cum_ltv |
| --- | --- | --- | --- | --- |
| 2024-01 | 0 | 2 | 700 | 350 |
| 2024-01 | 1 | 2 | 0 | 350 |
| 2024-01 | 2 | 2 | 300 | 500 |
| 2024-01 | 3 | 2 | 150 | 575 |
| 2024-01 | 4 | 2 | 0 | 575 |
| 2024-02 | 0 | 2 | 400 | 200 |
| 2024-02 | 1 | 2 | 0 | 200 |
| 2024-02 | 2 | 2 | 500 | 450 |
| 2024-02 | 3 | 2 | 200 | 550 |
| 2024-03 | 0 | 1 | 250 | 250 |
| 2024-03 | 1 | 1 | 0 | 250 |
| 2024-03 | 2 | 1 | 0 | 250 |

Đường LTV cộng dồn không bao giờ đi xuống. Nếu thấy nó giảm, gần như chắc chắn là mẫu số đã sai. So sánh các cohort ở **cùng tuổi**, tức cùng `month_offset`: sau 2 tháng, cohort 2024-01 đạt 500, cohort 2024-02 đạt 450, cohort 2024-03 đạt 250.

> [!TIP]
> **Ghi nhớ:** đường LTV cần một lưới cohort × tháng (`CROSS JOIN LATERAL generate_series`) để tháng trống vẫn có dòng. Cộng dồn doanh thu rồi chia cho số khách của **cả cohort**.
