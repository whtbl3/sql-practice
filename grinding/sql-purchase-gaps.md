# Khoảng cách giữa các lần mua

<style>
.markdown-preview tr:has(.drop) td { background: rgba(191, 97, 106, 0.16) !important; }
</style>

> Bài liên quan: `gaps/01`–`05`. Output đều chạy thật bằng `check.py`.

## Bài toán

Cửa hàng muốn biết **khách bao lâu thì mua một lần**: có người mua hằng tuần, có người mỗi tháng một lần, có người mua rồi im luôn. Từ đó trả lời các câu như: nhịp mua của từng khách là bao nhiêu ngày, ai đang vắng lâu bất thường, kênh nào kéo khách quay lại nhanh nhất.

Đơn vị đo ở đây là **số ngày giữa hai lần mua liền nhau** của cùng một khách, gọi là một *khoảng cách* (gap). Chủ đề này khác hai chủ đề gần giống:
- **Gaps & Islands** hỏi một chuỗi liên tiếp dài bao nhiêu.
- **Churn** hỏi có hoạt động trong một tháng hay không.

## Dữ liệu

Hai bảng, quan hệ **1 khách – nhiều đơn** (`orders.customer_id` → `customers.customer_id`).

`customers`: mỗi dòng = 1 khách. Cột `channel` (kênh thu hút khách) chỉ dùng ở V4.

| customer_id | name | channel |
| --- | --- | --- |
| 1 | Alice | Facebook |
| 2 | Ben | Facebook |
| 3 | Chloe | TikTok |
| 4 | David | TikTok |
| 5 | Emma | Shopee |
| 6 | Frank | Referral |

`orders`: mỗi dòng = 1 đơn.

| order_id | customer_id | order_date |
| --- | --- | --- |
| 1 | 3 | 2024-01-02 |
| 2 | 3 | 2024-01-04 |
| 3 | 2 | 2024-01-15 |
| 4 | 2 | 2024-01-15 |
| 5 | 2 | 2024-02-15 |
| 6 | 4 | 2024-03-01 |
| 7 | 2 | 2024-03-15 |
| 8 | 2 | 2024-04-15 |
| 9 | 3 | 2024-04-20 |
| 10 | 1 | 2024-05-08 |
| 11 | 1 | 2024-05-15 |
| 12 | 2 | 2024-05-15 |
| 13 | 1 | 2024-05-22 |
| 14 | 1 | 2024-05-29 |
| 15 | 5 | 2024-06-01 |
| 16 | 5 | 2024-06-03 |
| 17 | 5 | 2024-06-05 |
| 18 | 5 | 2024-06-07 |
| 19 | 2 | 2024-06-14 |
| 20 | 3 | 2024-07-10 |

Theo từng khách: Alice mua **hằng tuần**, Ben **hằng tháng** (và có 2 đơn cùng ngày 01-15), Chloe mua **thất thường**, David mua **đúng 1 lần**, Emma mua **2 ngày một lần**, Frank **chưa mua**.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Bỏ trùng ngày mua | CTE `days` | 1 khách × 1 ngày có mua |
| B2 | Tính khoảng cách tới lần mua trước | CTE `gaps` | như trên, thêm cột `gap` |
| B3 | Thống kê khoảng cách theo khách | query cuối | **1 khách** |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Bỏ trùng ngày mua (CTE `days`)

**Ý tưởng:** "một lần mua" ở đây là **một ngày có mua hàng**, không phải một đơn. Hai đơn trong cùng một ngày vẫn chỉ là một lần ghé cửa hàng.

**Ví dụ nhỏ:** Ben có 2 đơn ngày 01-15.

| order_id | customer | order_date | reason |
| --- | --- | --- | --- |
| 3 | Ben | 2024-01-15 | kept |
| 4 | Ben | 2024-01-15 | <span class="drop">same day as order 3, merged</span> |
| 5 | Ben | 2024-02-15 | kept |
| ... | | | |

```sql
WITH days AS (
  SELECT DISTINCT customer_id, order_date
  FROM orders
)
```

> [!CAUTION]
> ❌ **Bỏ qua bước này, tính thẳng trên `orders`**
>
> Hai đơn ngày 01-15 của Ben tạo ra một khoảng cách bằng **0**. Ben thật ra mua đều đặn mỗi tháng, nhưng khoảng cách nhỏ nhất của Ben ra 0 ngày, và trung bình cũng bị kéo xuống.
>
> → **Sửa:** `SELECT DISTINCT customer_id, order_date` trước khi tính khoảng cách.

## B2. Tính khoảng cách tới lần mua trước (CTE `gaps`)

**Ý tưởng:** khoảng cách là hiệu giữa **hai dòng liền nhau** của cùng một khách. `LAG(order_date)` đưa ngày mua trước lên cùng dòng với ngày mua hiện tại, rồi trừ hai ngày cho nhau.

**Ví dụ nhỏ:**

| customer | order_date | `LAG(order_date)` | gap |
| --- | --- | --- | --- |
| Chloe | 2024-01-02 | NULL | NULL (first purchase) |
| Chloe | 2024-01-04 | 2024-01-02 | 2 |
| Chloe | 2024-04-20 | 2024-01-04 | 107 |
| Chloe | 2024-07-10 | 2024-04-20 | 81 |
| ... | | | |

```sql
gaps AS (
  SELECT customer_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS gap
  FROM days
)
```

Trừ hai giá trị kiểu `date` ra số ngày, kiểu số nguyên. Lần mua đầu tiên của mỗi khách không có lần trước, nên `gap` là `NULL`.

> [!CAUTION]
> ❌ **Quên `PARTITION BY customer_id`**
>
> Khi đó mọi ngày mua của mọi khách bị xếp chung một hàng, và `LAG` lấy luôn ngày mua của khách **khác**. Lần mua đầu của Alice (05-08) bị trừ cho ngày 04-20 của Chloe, ra khoảng cách 18 ngày, dù Alice chưa từng mua trước đó.
>
> → **Sửa:** `PARTITION BY customer_id`, để mỗi khách chỉ so với chính mình.

## B3. Thống kê khoảng cách theo khách (query cuối)

**Ý tưởng:** gom các khoảng cách của mỗi khách thành một dòng: nhỏ nhất, trung bình, trung vị, lớn nhất. Các hàm `MIN`, `AVG`, `MAX`, `PERCENTILE_CONT` đều bỏ qua `NULL`, nên dòng mua đầu tiên (không có khoảng cách) tự bị loại khỏi phép tính.

**Ví dụ nhỏ:** Chloe có 4 ngày mua, tức 3 khoảng cách: 2, 107, 81.

| customer | purchase_days | gaps | avg_gap | median_gap |
| --- | --- | --- | --- | --- |
| Chloe | 4 | 2, 81, 107 | 63.3 = (2 + 81 + 107) / 3 | 81.0 (middle value) |
| ... | | | | |

Trung bình và trung vị của Chloe khác nhau khá xa. Một khoảng rất ngắn (2 ngày) kéo trung bình xuống, còn trung vị chỉ lấy giá trị đứng giữa nên không bị ảnh hưởng. Khi đo "nhịp quen thuộc" của khách, trung vị thường đáng tin hơn.

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
ORDER BY customer_id;
```

Đọc từng phần:
- `COUNT(*)` đếm số ngày mua. `COUNT(gap)` đếm số khoảng cách, luôn ít hơn 1 vì bỏ qua dòng `NULL` đầu tiên.
- `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap)` là trung vị. Nếu số khoảng cách là chẵn, nó lấy trung bình của hai giá trị ở giữa.
- `PERCENTILE_CONT` trả về kiểu `double precision`, mà `ROUND(double precision, 1)` không tồn tại trong PostgreSQL. Phải ép `::numeric` trước khi làm tròn.
- `HAVING COUNT(gap) >= 1` bỏ khách chưa có khoảng cách nào.

> [!CAUTION]
> ❌ **Bỏ `HAVING COUNT(gap) >= 1`**
>
> David chỉ mua một lần, nên không có khoảng cách nào. David vẫn hiện ra với `min_gap`, `avg_gap`, `max_gap` đều là `NULL`, một dòng không mang thông tin gì.
>
> → **Sửa:** giữ `HAVING COUNT(gap) >= 1`, hoặc đúng điều kiện đề yêu cầu (ví dụ "ít nhất 2 ngày mua").

## Tổng kết: query đầy đủ

```sql
WITH days AS (                                     -- B1: bỏ trùng ngày mua
  SELECT DISTINCT customer_id, order_date
  FROM orders
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

Khoảng cách của từng khách sau B2:

| customer | gaps |
| --- | --- |
| Alice | 7, 7, 7 |
| Ben | 31, 29, 31, 30, 30 |
| Chloe | 2, 107, 81 |
| David | (none) |
| Emma | 2, 2, 2 |

Kết quả cuối:

| customer_id | purchase_days | min_gap | avg_gap | median_gap | max_gap |
| --- | --- | --- | --- | --- | --- |
| 1 | 4 | 7 | 7.0 | 7.0 | 7 |
| 2 | 6 | 29 | 30.2 | 30.0 | 31 |
| 3 | 4 | 2 | 63.3 | 81.0 | 107 |
| 5 | 4 | 2 | 2.0 | 2.0 | 2 |

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính: tính cả quãng vắng đang kéo dài tới hôm nay, chia khoảng cách thành nhóm, so mỗi khách với nhịp của chính họ, hay đo thời gian tới lần mua thứ hai. Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi tìm quãng vắng dài nhất, kể cả quãng đang mở

Đề: **tại ngày 2024-06-30, quãng vắng dài nhất của mỗi khách là bao lâu?** Quãng vắng gồm hai loại:
- Khoảng giữa hai lần mua liền nhau. Đây là quãng **đã đóng**.
- Khoảng từ lần mua cuối cùng tới ngày chốt. Đây là quãng **đang mở**, vì khách chưa quay lại.

Mạch chính chỉ có loại thứ nhất. `LAG` nhìn về lần mua **trước**, nên lần mua cuối không có dòng nào mô tả "từ đây đến hôm nay". David chỉ mua một lần, nên không có khoảng cách nào cả, dù đã vắng 4 tháng.

### Nhìn về phía trước bằng `LEAD`

Đổi góc nhìn: mỗi ngày mua là **điểm bắt đầu** của một quãng vắng, và quãng đó kết thúc ở lần mua **kế tiếp**. `LEAD(order_date)` lấy ngày mua kế tiếp. Lần mua cuối không có lần kế tiếp, và tham số thứ ba của `LEAD` là giá trị dùng trong trường hợp đó, ở đây là ngày chốt:

```sql
WITH days AS (
  SELECT DISTINCT customer_id, order_date
  FROM orders
  WHERE order_date <= DATE '2024-06-30'
),
silences AS (
  SELECT customer_id,
         order_date AS gap_start,
         LEAD(order_date, 1, DATE '2024-06-30') OVER w AS gap_end,
         LEAD(order_date) OVER w IS NULL                AS is_open
  FROM days
  WINDOW w AS (PARTITION BY customer_id ORDER BY order_date)
)
```

| customer | gap_start | gap_end | gap_days | is_open |
| --- | --- | --- | --- | --- |
| Chloe | 2024-01-02 | 2024-01-04 | 2 | false |
| Chloe | 2024-01-04 | 2024-04-20 | 107 | false |
| Chloe | 2024-04-20 | 2024-06-30 | 71 | **true** |
| David | 2024-03-01 | 2024-06-30 | 121 | **true** |
| ... | | | | |

David giờ có một dòng: quãng đang mở, 121 ngày. Để biết quãng nào đang mở, ta gọi `LEAD` thêm một lần nữa nhưng **không có** giá trị mặc định. Lần mua cuối nhận `NULL`, nên `IS NULL` đúng ở đúng dòng đó.

### Đừng quên lọc theo ngày chốt

Chloe có một đơn ngày 07-10, sau ngày chốt. Nếu quên `WHERE order_date <= ngày chốt` ở `days`, đơn này vẫn được tính:

| customer | gap_start | gap_end | gap_days | is_open |
| --- | --- | --- | --- | --- |
| Chloe | 2024-04-20 | 2024-07-10 | 81 | false |
| Chloe | <span class="drop">2024-07-10</span> | <span class="drop">2024-06-30</span> | <span class="drop">−10</span> | <span class="drop">true</span> |

Quãng 04-20 → 06-30, lẽ ra đang mở, bị đơn tương lai "đóng" lại thành 81 ngày. Thêm vào đó là một quãng âm vô nghĩa. Dữ liệu sau ngày chốt phải bị loại ngay từ đầu, trước khi gọi `LAG` hay `LEAD`.

### Chọn quãng dài nhất của mỗi khách

Đây là bài "mỗi khách lấy một dòng tốt nhất". Đánh số các quãng của mỗi khách từ dài đến ngắn bằng `ROW_NUMBER`, rồi giữ dòng số 1. Ben có hai quãng cùng 31 ngày. Thêm `gap_start` vào `ORDER BY` để khi bằng nhau thì luôn chọn quãng sớm hơn:

```sql
ranked AS (
  SELECT *, gap_end - gap_start AS gap_days,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY gap_end - gap_start DESC, gap_start) AS rn
  FROM silences
)
SELECT customer_id, gap_start, gap_end, gap_days,
       CASE WHEN is_open THEN 'open' ELSE 'closed' END AS gap_type
FROM ranked
WHERE rn = 1
ORDER BY customer_id;
```

| customer | gap_start | gap_end | gap_days | gap_type |
| --- | --- | --- | --- | --- |
| Alice | 2024-05-29 | 2024-06-30 | 32 | open |
| Ben | 2024-01-15 | 2024-02-15 | 31 | closed |
| Chloe | 2024-01-04 | 2024-04-20 | 107 | closed |
| David | 2024-03-01 | 2024-06-30 | 121 | open |
| Emma | 2024-06-07 | 2024-06-30 | 23 | open |

> [!TIP]
> **Ghi nhớ:** muốn tính cả quãng đang mở thì dùng `LEAD(ngày, 1, ngày_chốt)`. Kiểm tra quãng mở bằng `LEAD(ngày) IS NULL`, và lọc dữ liệu sau ngày chốt trước khi gọi hàm cửa sổ.

## V2. Khi chia khoảng cách thành nhóm

Đề: **chia tất cả khoảng cách vào các nhóm 1–7 ngày, 8–14, 15–30, 31–90, 91+; mỗi nhóm có bao nhiêu khoảng cách và chiếm bao nhiêu phần trăm?** Phải liệt kê **đủ 5 nhóm**, theo đúng thứ tự trên, kể cả nhóm trống.

### Thử cách tự nhiên nhất

Gắn tên nhóm cho mỗi khoảng cách bằng `CASE`, rồi `GROUP BY` tên nhóm:

```sql
SELECT CASE WHEN gap <= 7  THEN '1-7 days'
            WHEN gap <= 14 THEN '8-14 days'
            WHEN gap <= 30 THEN '15-30 days'
            WHEN gap <= 90 THEN '31-90 days'
            ELSE '91+ days' END AS bucket,
       COUNT(*) AS gaps
FROM gaps
WHERE gap IS NOT NULL
GROUP BY 1
ORDER BY 1;
```

| bucket | gaps |
| --- | --- |
| 1-7 days | 7 |
| 15-30 days | 3 |
| 31-90 days | 3 |
| 91+ days | 1 |

Nhóm `8-14 days` biến mất, vì không có khoảng cách nào rơi vào đó. `GROUP BY` chỉ tạo nhóm từ dữ liệu có thật. Thứ tự cũng chỉ trông đúng nhờ may mắn: `ORDER BY 1` xếp theo chữ, nên nếu nhóm `8-14 days` có mặt, nó sẽ đứng **sau** `31-90 days`, vì ký tự `'8'` đứng sau `'3'`.

### Cách sửa: một bảng nhóm viết tay

Viết danh sách nhóm thành một bảng bằng `VALUES`, kèm thứ tự hiển thị và hai cận của mỗi nhóm. Sau đó đi **từ bảng nhóm**, `LEFT JOIN` các khoảng cách vào theo khoảng giá trị:

```sql
buckets (bucket, sort_key, lo, hi) AS (
  VALUES ('1-7 days', 1, 1, 7), ('8-14 days', 2, 8, 14), ('15-30 days', 3, 15, 30),
         ('31-90 days', 4, 31, 90), ('91+ days', 5, 91, NULL)
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
| 1-7 days | 7 | 50.0 |
| 8-14 days | 0 | 0.0 |
| 15-30 days | 3 | 21.4 |
| 31-90 days | 3 | 21.4 |
| 91+ days | 1 | 7.1 |

Đọc từng phần:
- Nhóm `91+` có `hi` là `NULL`, nghĩa là không có trần. Vì vậy điều kiện viết `(b.hi IS NULL OR g.gap <= b.hi)`, không dùng `BETWEEN`.
- Dòng `gap` là `NULL` (lần mua đầu) không khớp nhóm nào, nên tự rơi ra.
- `COUNT(g.gap)` đếm số khoảng cách thật. Nhóm trống chỉ có một dòng `NULL`, nên ra 0.
- `SUM(COUNT(g.gap)) OVER ()` cộng số đếm của mọi nhóm, ra tổng 14 khoảng cách, dùng làm mẫu số.

> [!TIP]
> **Ghi nhớ:** muốn đủ mọi nhóm theo đúng thứ tự thì viết bảng nhóm bằng `VALUES`, có cột thứ tự và cận, rồi `LEFT JOIN` dữ liệu vào bảng đó.

## V3. Khi tìm khách vắng lâu bất thường

Đề: **tại ngày 2024-06-30, ai đang vắng lâu bất thường so với nhịp mua của chính họ?** Đề định nghĩa: khách "trễ hẹn" khi số ngày kể từ lần mua cuối lớn hơn **2 lần trung vị khoảng cách** của họ. Chỉ xét khách có ít nhất 3 khoảng cách, vì ít hơn thì chưa đủ để nói họ có nhịp.

### Thử một ngưỡng chung

Cách đơn giản nhất là đặt một ngưỡng cho tất cả, ví dụ "vắng hơn 30 ngày là trễ":

| customer | days since last | > 30? | reality |
| --- | --- | --- | --- |
| Alice | 32 | yes | weekly buyer, 32 days is very unusual |
| Ben | 16 | no | monthly buyer, 16 days is normal |
| Chloe | 71 | yes | irregular buyer, not enough data |
| David | 121 | yes | bought once, no rhythm to be late on |
| Emma | 23 | **no** | buys every 2 days, 23 days is extremely unusual |

Một ngưỡng chung không hợp với cả người mua hằng tuần lẫn người mua hằng tháng. Emma, người trễ nặng nhất, lại không bị phát hiện.

### Cách sửa: so mỗi khách với chính họ

Với mỗi khách, tính ba con số: số khoảng cách, trung vị khoảng cách, và số ngày kể từ lần mua cuối. Dữ liệu sau ngày chốt bị loại ngay ở `days`, như V1.

```sql
WITH days AS (
  SELECT DISTINCT customer_id, order_date
  FROM orders
  WHERE order_date <= DATE '2024-06-30'
),
gaps AS (
  SELECT customer_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS gap
  FROM days
),
rhythm AS (
  SELECT customer_id,
         COUNT(gap) AS n_gaps,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap) AS median_gap,
         DATE '2024-06-30' - MAX(order_date) AS days_since_last
  FROM gaps
  GROUP BY customer_id
)
SELECT customer_id,
       ROUND(median_gap::numeric, 1) AS median_gap,
       days_since_last,
       ROUND((days_since_last / median_gap)::numeric, 1) AS ratio
FROM rhythm
WHERE n_gaps >= 3
  AND days_since_last > 2 * median_gap
ORDER BY ratio DESC, customer_id;
```

`rhythm`, mỗi khách một dòng:

| customer | n_gaps | median_gap | days_since_last | late? |
| --- | --- | --- | --- | --- |
| Alice | 3 | 7.0 | 32 | 32 > 14, **yes** |
| Ben | 5 | 30.0 | 16 | 16 ≤ 60, no |
| Chloe | 2 | 54.5 | 71 | fewer than 3 gaps, skipped |
| David | 0 | NULL | 121 | fewer than 3 gaps, skipped |
| Emma | 3 | 2.0 | 23 | 23 > 4, **yes** |

| customer_id | median_gap | days_since_last | ratio |
| --- | --- | --- | --- |
| 5 | 2.0 | 23 | 11.5 |
| 1 | 7.0 | 32 | 4.6 |

Emma giờ đứng đầu danh sách: vắng gấp 11.5 lần nhịp bình thường. Đề dùng trung vị chứ không dùng trung bình vì một lần nghỉ dài bất thường sẽ kéo trung bình lên rất cao, làm "nhịp quen thuộc" trông chậm hơn thực tế. Ví dụ với các khoảng 10, 100, 12, 14 ngày, trung bình là 34, còn trung vị chỉ là 13.

> [!TIP]
> **Ghi nhớ:** "bất thường" thì so với nhịp của chính khách đó (`days_since_last > k × median_gap`), không dùng một ngưỡng chung cho mọi người.

## V4. Khi đo thời gian tới lần mua thứ hai theo kênh

Đề: **với mỗi kênh thu hút khách, có bao nhiêu khách đã mua, bao nhiêu khách quay lại mua lần hai, và họ mất bao lâu để quay lại?** Lần mua thứ hai là **ngày mua thứ hai**: đơn thứ hai trong cùng ngày đầu tiên không tính.

### Lấy ngày mua thứ nhất và thứ hai

Đánh số các ngày mua (đã bỏ trùng) của mỗi khách bằng `ROW_NUMBER`, rồi đưa ngày số 1 và ngày số 2 lên cùng một dòng bằng `MAX(...) FILTER (WHERE rn = k)`. Đây cũng là cách làm ở V2 của doc cohort:

```sql
WITH days AS (
  SELECT DISTINCT customer_id, order_date
  FROM orders
),
numbered AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
  FROM days
),
per_customer AS (
  SELECT customer_id,
         MAX(order_date) FILTER (WHERE rn = 2) - MAX(order_date) FILTER (WHERE rn = 1) AS days_to_return
  FROM numbered
  GROUP BY customer_id
)
```

Bước bỏ trùng ở `days` rất quan trọng. Nếu đánh số thẳng trên `orders`, hai đơn ngày 01-15 của Ben thành đơn số 1 và số 2, nên Ben "quay lại sau **0** ngày", trong khi thực ra Ben quay lại sau 31 ngày.

### Ba mẫu số khác nhau

Đi từ `customers` rồi `LEFT JOIN per_customer`, để kênh nào cũng hiện ra, kể cả kênh chưa có ai mua:

| customer | channel | `p.customer_id` | days_to_return |
| --- | --- | --- | --- |
| Alice | Facebook | 1 | 7 |
| Ben | Facebook | 2 | 31 |
| Chloe | TikTok | 3 | 2 |
| David | TikTok | 4 | NULL (only 1 purchase day) |
| Emma | Shopee | 5 | 2 |
| Frank | Referral | NULL (no orders) | NULL |

Mỗi kênh có ba con số đếm khác nhau, và đề dùng mỗi con số cho một mục đích:
- `COUNT(*)`: số khách của kênh, kể cả người chưa mua (Frank).
- `COUNT(p.customer_id)`: số khách **đã mua**. Frank có `p.customer_id` là `NULL` nên không được đếm.
- `COUNT(p.days_to_return)`: số khách **đã quay lại**. David có `days_to_return` là `NULL` nên không được đếm.

`AVG` và `PERCENTILE_CONT` cũng bỏ qua `NULL`, nên tự chỉ tính trên những người đã quay lại.

```sql
SELECT c.channel,
       COUNT(p.customer_id)    AS buyers,
       COUNT(p.days_to_return) AS returned,
       ROUND(100.0 * COUNT(p.days_to_return) / NULLIF(COUNT(p.customer_id), 0), 1) AS return_rate_pct,
       ROUND(AVG(p.days_to_return), 1) AS avg_days,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.days_to_return))::numeric, 1) AS median_days
FROM customers c
LEFT JOIN per_customer p ON p.customer_id = c.customer_id
GROUP BY c.channel
ORDER BY c.channel;
```

| channel | buyers | returned | return_rate_pct | avg_days | median_days |
| --- | --- | --- | --- | --- | --- |
| Facebook | 2 | 2 | 100.0 | 19.0 | 19.0 |
| Referral | 0 | 0 | NULL | NULL | NULL |
| Shopee | 1 | 1 | 100.0 | 2.0 | 2.0 |
| TikTok | 2 | 1 | 50.0 | 2.0 | 2.0 |

Nếu đếm `buyers` bằng `COUNT(*)`, kênh Referral ra 1 người mua, vì Frank vẫn có một dòng từ `LEFT JOIN`. Thực tế kênh này chưa có ai mua.

> [!TIP]
> **Ghi nhớ:** "lần mua thứ k" thì đánh số trên các **ngày đã bỏ trùng**. Khi một dòng có nhiều tỉ lệ, chọn đúng cột để đếm cho từng mẫu số: `COUNT(*)`, `COUNT(id)`, hay `COUNT(giá trị)`.
