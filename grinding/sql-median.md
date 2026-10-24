# Trung vị và phân vị

<style>
.markdown-preview tr:has(.drop) td { background: rgba(191, 97, 106, 0.16) !important; }
</style>

> Bài liên quan: `median/01`–`04`, `misc/04`. Output đều chạy thật bằng `check.py`.

## Bài toán

Công ty muốn biết **mức lương điển hình** của mỗi phòng ban. Câu hỏi nghe giống "lương trung bình", nhưng trung bình dễ bị một vài giá trị rất lớn kéo lệch.

Phòng Engineering có 5 người, lương 28, 30, 30, 45 và 90 triệu. Trung bình là 44.6 triệu, cao hơn lương của 4 trên 5 người. **Trung vị** là giá trị **đứng giữa** khi xếp từ thấp đến cao, ở đây là 30 triệu. Một người lương 90 triệu không kéo được nó lên.

Cách tìm trung vị:
- Số giá trị **lẻ**: lấy giá trị ở giữa. Với 5 giá trị, đó là giá trị thứ 3.
- Số giá trị **chẵn**: lấy trung bình hai giá trị ở giữa. Với 4 giá trị 15, 18, 20, 22, trung vị là (18 + 20) / 2 = 19.

PostgreSQL có sẵn hàm tính trung vị (xem V1). Phần 1 trình bày cách **tự tìm vị trí giữa**. Cần đến cách này khi đề cấm dùng hàm có sẵn, khi dữ liệu là bảng tần suất (V2), hoặc khi cần trung vị trượt (V3).

## Dữ liệu

`employees`: mỗi dòng = 1 nhân viên. Lương tính bằng triệu đồng, có thể là `NULL` (chưa nhập).

| emp_id | name | department | salary_m |
| --- | --- | --- | --- |
| 1 | Alice | Engineering | 30 |
| 2 | Ben | Engineering | 45 |
| 3 | Chloe | Engineering | 28 |
| 4 | David | Engineering | 30 |
| 5 | Emma | Engineering | 90 |
| 6 | Frank | Sales | 18 |
| 7 | Grace | Sales | NULL |
| 8 | Henry | Sales | 22 |
| 9 | Ivy | Sales | 15 |
| 10 | Jack | Sales | 20 |
| 11 | Kate | Support | 12 |
| 12 | Leo | Support | 16 |
| 13 | Mia | Legal | NULL |

Ba chỗ dễ sai: Grace (Sales) và Mia (Legal) **chưa có lương**, Alice và David **lương bằng nhau**, và mỗi phòng có số người **chẵn hoặc lẻ** khác nhau.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Bỏ lương `NULL` | `WHERE` trong CTE `ranked` | 1 nhân viên có lương |
| B2 | Đánh số vị trí, đếm tổng | CTE `ranked` | như trên, thêm `rn` và `n` |
| B3 | Giữ 1 hoặc 2 vị trí giữa | `WHERE` ở query cuối | chỉ còn dòng ở giữa |
| B4 | Lấy trung bình | query cuối | **1 phòng ban** |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Bỏ lương `NULL` (`WHERE` trong CTE `ranked`)

**Ý tưởng:** `NULL` không phải một mức lương. Nhưng nếu còn trong dữ liệu, nó vẫn chiếm một vị trí khi đánh số ở B2, làm lệch vị trí giữa. Vì vậy phải bỏ nó trước khi đánh số.

**Ví dụ nhỏ:** Sales có 5 người, nhưng chỉ 4 người có lương.

| name | salary_m | reason |
| --- | --- | --- |
| Ivy | 15 | kept |
| Frank | 18 | kept |
| Jack | 20 | kept |
| Henry | 22 | kept |
| Grace | NULL | <span class="drop">no salary, removed</span> |

```sql
WHERE salary_m IS NOT NULL
```

Điều kiện này đặt trong `WHERE` của cùng CTE với B2. `WHERE` chạy **trước** các hàm cửa sổ, nên khi đánh số, Grace đã không còn.

> [!CAUTION]
> ❌ **Không lọc `NULL`**
>
> Sales thành 5 dòng: `NULL` được xếp cuối và nhận vị trí 5. Vị trí giữa của 5 dòng là vị trí 3, tức lương của Jack (20). Trung vị ra 20, trong khi trung vị đúng của 4 mức lương thật là 19. Phòng Legal (chỉ có Mia, lương `NULL`) cũng hiện ra với trung vị `NULL`.
>
> → **Sửa:** `WHERE salary_m IS NOT NULL` trước khi đánh số.

## B2. Đánh số vị trí, đếm tổng (CTE `ranked`)

**Ý tưởng:** muốn biết dòng nào ở giữa thì cần hai thứ: vị trí của từng dòng khi xếp theo lương (`rn`), và tổng số dòng của phòng (`n`).

**Ví dụ nhỏ:** Engineering.

| name | salary_m | rn | n |
| --- | --- | --- | --- |
| Chloe | 28 | 1 | 5 |
| David | 30 | 2 | 5 |
| Alice | 30 | 3 | 5 |
| Ben | 45 | 4 | 5 |
| Emma | 90 | 5 | 5 |

```sql
WITH ranked AS (
  SELECT department, name, salary_m,
         ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary_m) AS rn,
         COUNT(*)     OVER (PARTITION BY department)                   AS n
  FROM employees
  WHERE salary_m IS NOT NULL
)
```

`COUNT(*) OVER (PARTITION BY department)` đếm số dòng của phòng rồi ghi con số đó lên **mọi dòng** của phòng. Nhờ vậy mỗi dòng biết được tổng `n` mà không phải gộp lại.

> [!CAUTION]
> ❌ **Dùng `RANK()` thay cho `ROW_NUMBER()`**
>
> Alice và David cùng lương 30. `RANK` cho hai người cùng hạng 2, rồi nhảy sang hạng 4: dãy hạng là 1, 2, 2, 4, 5, **không có số 3**. Vị trí giữa của 5 người là 3, nên không tìm thấy dòng nào, và Engineering mất trung vị.
>
> → **Sửa:** `ROW_NUMBER()`, vì nó luôn đánh số liền mạch 1, 2, 3, ..., kể cả khi giá trị bằng nhau.

## B3. Giữ 1 hoặc 2 vị trí giữa (`WHERE` ở query cuối)

**Ý tưởng:** `n` lẻ thì có một vị trí giữa, `n` chẵn thì có hai. Hai biểu thức `(n + 1) / 2` và `(n + 2) / 2`, dùng **phép chia số nguyên**, cho ra đúng các vị trí cần giữ trong cả hai trường hợp.

**Ví dụ nhỏ:**

| department | n | (n + 1) / 2 | (n + 2) / 2 | kept |
| --- | --- | --- | --- | --- |
| Engineering | 5 | 3 | 3 | rn = 3 (Alice, 30) |
| Sales | 4 | 2 | 3 | rn = 2, 3 (Frank 18, Jack 20) |
| Support | 2 | 1 | 2 | rn = 1, 2 (Kate 12, Leo 16) |

Với `n = 5`, cả hai biểu thức đều ra 3 (6 / 2 = 3, 7 / 2 = 3 khi chia số nguyên), nên chỉ giữ một dòng. Với `n = 4`, chúng ra 2 và 3, nên giữ hai dòng.

```sql
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
```

`n` là số nguyên (kết quả của `COUNT`), nên phép chia ở đây là chia số nguyên: phần lẻ bị bỏ.

## B4. Lấy trung bình (query cuối)

**Ý tưởng:** sau B3, mỗi phòng còn 1 hoặc 2 dòng. `AVG` của 1 dòng là chính giá trị đó, `AVG` của 2 dòng là trung bình của chúng. Vì vậy cùng một câu lệnh dùng được cho cả `n` lẻ lẫn `n` chẵn.

```sql
SELECT department, ROUND(AVG(salary_m), 1) AS median_salary
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
GROUP BY department
ORDER BY department;
```

| department | kept rows | median_salary |
| --- | --- | --- |
| Engineering | 30 | 30.0 |
| Sales | 18, 20 | 19.0 = (18 + 20) / 2 |
| ... | | |

Legal không có lương nào sau B1, nên tự biến mất khỏi kết quả.

## Tổng kết: query đầy đủ

```sql
WITH ranked AS (                                   -- B1 + B2: bỏ NULL, đánh số, đếm tổng
  SELECT department, name, salary_m,
         ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary_m) AS rn,
         COUNT(*)     OVER (PARTITION BY department)                   AS n
  FROM employees
  WHERE salary_m IS NOT NULL
)
SELECT department, ROUND(AVG(salary_m), 1) AS median_salary   -- B4: trung bình 1 hoặc 2 dòng giữa
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)                         -- B3: giữ vị trí giữa
GROUP BY department
ORDER BY department;
```

| department | median_salary |
| --- | --- |
| Engineering | 30.0 |
| Sales | 19.0 |
| Support | 14.0 |

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính: cho phép dùng hàm có sẵn, dữ liệu đã gom thành bảng tần suất, hoặc cần trung vị trên một cửa sổ trượt. Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi được dùng hàm có sẵn

Nếu đề không cấm, PostgreSQL có hai hàm tính trung vị, dùng với `GROUP BY` giống `AVG`:
- `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)`: khi số giá trị chẵn, lấy **trung bình** hai giá trị giữa. Đây là trung vị theo định nghĩa thông thường.
- `PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY x)`: khi số giá trị chẵn, lấy giá trị giữa **thấp hơn**. Kết quả luôn là một giá trị có thật trong dữ liệu.

`0.5` nghĩa là "điểm 50%". Đổi thành `0.25` hay `0.9` thì ra phân vị 25% hay 90%. `WITHIN GROUP (ORDER BY x)` cho hàm biết xếp theo cột nào. Cả hai hàm tự bỏ qua `NULL`.

Một đề hay gặp: **so sánh trung bình với trung vị để đoán hình dạng dữ liệu**. Trung bình lớn hơn trung vị nhiều nghĩa là có vài giá trị rất lớn kéo lên (lệch phải). Trung bình nhỏ hơn trung vị nhiều nghĩa là có vài giá trị rất nhỏ kéo xuống (lệch trái).

### Thử cách tự nhiên nhất

Viết như mọi hàm gộp khác, rồi làm tròn:

```sql
SELECT department, ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_m), 1)
FROM employees
GROUP BY department;
```

```text
ERROR:  function round(double precision, integer) does not exist
```

`PERCENTILE_CONT` trả về kiểu `double precision`. Hàm `ROUND(x, số_chữ_số)` của PostgreSQL chỉ nhận kiểu `numeric`. Phải ép kiểu trước: `(PERCENTILE_CONT(...))::numeric`.

### Viết đầy đủ

```sql
SELECT department,
       COUNT(salary_m) AS employees,
       ROUND(AVG(salary_m), 1) AS avg_salary,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_m))::numeric, 1) AS median_cont,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY salary_m) AS median_disc,
       CASE WHEN AVG(salary_m) > 1.2 * PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_m) THEN 'right-skewed'
            WHEN AVG(salary_m) < 0.8 * PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_m) THEN 'left-skewed'
            ELSE 'balanced' END AS shape
FROM employees
WHERE salary_m IS NOT NULL
GROUP BY department
ORDER BY department;
```

| department | employees | avg_salary | median_cont | median_disc | shape |
| --- | --- | --- | --- | --- | --- |
| Engineering | 5 | 44.6 | 30.0 | 30 | right-skewed |
| Sales | 4 | 18.8 | 19.0 | 18 | balanced |
| Support | 2 | 14.0 | 14.0 | 12 | balanced |

Đọc kết quả:
- Engineering: trung bình 44.6 lớn hơn 1.2 × 30 = 36, nên lệch phải. Đó là lương 90 triệu của Emma.
- Sales có 4 người, nên hai hàm cho kết quả khác nhau. `PERCENTILE_CONT` lấy trung bình (18 + 20) / 2 = 19. `PERCENTILE_DISC` lấy giá trị giữa thấp hơn là 18.
- `CASE` so sánh bằng các giá trị **chưa làm tròn**, đúng như đề thường yêu cầu.
- `WHERE salary_m IS NOT NULL` loại phòng Legal. Nếu bỏ dòng này, Legal vẫn hiện ra với `employees = 0` và mọi cột khác là `NULL`.

> [!TIP]
> **Ghi nhớ:** trung vị có sẵn là `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)`. Nhớ ép `::numeric` trước khi `ROUND`.

## V2. Khi dữ liệu là bảng tần suất

Một chuỗi trà sữa không lưu từng đơn, mà lưu sẵn **bao nhiêu đơn có 1 món, bao nhiêu đơn có 2 món...**:

```text
basket_sizes (store, items, orders)   -- mới; orders có thể là 0, các dòng không theo thứ tự
```

| store | items | orders |
| --- | --- | --- |
| Downtown | 3 | 1 |
| Downtown | 1 | 4 |
| Downtown | 5 | 1 |
| Downtown | 2 | 2 |
| Airport | 2 | 3 |
| Airport | 1 | 1 |
| Airport | 4 | 1 |
| Mall | 3 | 0 |

Đề hỏi: **mỗi cửa hàng, một đơn điển hình có bao nhiêu món** (trung vị số món mỗi đơn)? Đề cấm bung bảng ra thành từng đơn một (`generate_series`, `unnest`...).

Downtown có 8 đơn. Nếu liệt kê từng đơn theo số món, ta được: 1, 1, 1, 1, 2, 2, 3, 5. Hai đơn ở giữa (vị trí 4 và 5) có 1 và 2 món, nên trung vị là 1.5. Câu hỏi là làm sao tìm ra vị trí 4 và 5 mà không liệt kê.

### Mỗi giá trị chiếm một khoảng vị trí

Xếp các dòng theo `items`, rồi cộng dồn `orders`. Mỗi giá trị chiếm một **khoảng vị trí** liên tiếp. Ví dụ ở Downtown, 4 đơn 1 món chiếm vị trí 1–4, 2 đơn 2 món chiếm vị trí 5–6:

| items | orders | running total | pos_from = running − orders + 1 | pos_to = running |
| --- | --- | --- | --- | --- |
| 1 | 4 | 4 | 1 | 4 |
| 2 | 2 | 6 | 5 | 6 |
| 3 | 1 | 7 | 7 | 7 |
| 5 | 1 | 8 | 8 | 8 |

Tổng là 8 đơn, nên hai vị trí giữa là (8 + 1) / 2 = 4 và (8 + 2) / 2 = 5, theo đúng công thức ở B3. Vị trí 4 nằm trong khoảng của `items = 1`, vị trí 5 nằm trong khoảng của `items = 2`. Giữ hai dòng đó rồi lấy trung bình, giống B4: (1 + 2) / 2 = 1.5.

### Thử cách tự nhiên nhất

```sql
SUM(orders) OVER (PARTITION BY store ORDER BY items) - orders + 1 AS pos_from,
SUM(orders) OVER (PARTITION BY store ORDER BY items)              AS pos_to,
SUM(orders) OVER (PARTITION BY store)                             AS total
```

Chạy thử thì Downtown ra trung vị **2.0** thay vì 1.5. Lý do: cột `orders` có kiểu `bigint`, và `SUM` của `bigint` trả về `numeric`, tức số thập phân. `total` lúc này là `8` kiểu `numeric`, nên `(total + 1) / 2` ra **4.5** chứ không phải 4. Vị trí 4.5 không nằm trong khoảng nào, nên `items = 1` không được giữ, chỉ còn `items = 2` ở vị trí 5.

### Cách sửa: ép về số nguyên

Thêm `::bigint` sau mỗi `SUM`, để phép chia ở B3 lại là chia số nguyên:

```sql
WITH positions AS (
  SELECT store, items, orders,
         SUM(orders) OVER (PARTITION BY store ORDER BY items)::bigint - orders + 1 AS pos_from,
         SUM(orders) OVER (PARTITION BY store ORDER BY items)::bigint              AS pos_to,
         SUM(orders) OVER (PARTITION BY store)::bigint                             AS total
  FROM basket_sizes
)
SELECT store, total AS total_orders, ROUND(AVG(items), 1) AS median_items
FROM positions
WHERE total > 0
  AND ((total + 1) / 2 BETWEEN pos_from AND pos_to
    OR (total + 2) / 2 BETWEEN pos_from AND pos_to)
GROUP BY store, total
ORDER BY store;
```

| store | total_orders | median_items |
| --- | --- | --- |
| Airport | 5 | 2.0 |
| Downtown | 8 | 1.5 |

Airport có 5 đơn, nên chỉ có một vị trí giữa là 3, nằm trong khoảng 2–4 của `items = 2`. Mall không có đơn nào (`total = 0`), nên bị `WHERE total > 0` loại.

> [!TIP]
> **Ghi nhớ:** với bảng tần suất, cộng dồn số lần để mỗi giá trị có một khoảng vị trí, rồi giữ giá trị có khoảng chứa vị trí giữa. Nhớ ép `SUM(...)::bigint` để phép chia vẫn là chia số nguyên.

## V3. Khi cần trung vị trượt

Một cửa hàng có doanh thu mỗi ngày (triệu đồng). Có một ngày bất thường, 400 triệu, do một đơn sỉ lớn:

```text
daily_sales (sale_date, revenue_m)   -- mới; một dòng mỗi ngày có bán, có ngày bị thiếu
```

| sale_date | revenue_m |
| --- | --- |
| 2024-03-01 | 50 |
| 2024-03-02 | 55 |
| 2024-03-03 | 52 |
| 2024-03-04 | 400 |
| 2024-03-05 | 58 |
| 2024-03-07 | 60 |
| 2024-03-08 | 57 |

Đề muốn, với mỗi ngày, so **trung bình trượt** và **trung vị trượt** trên cửa sổ 5 dòng: chính dòng đó, 2 dòng trước và 2 dòng sau. Ở hai đầu, cửa sổ chỉ có 3 hoặc 4 dòng.

### Thử cách tự nhiên nhất

Trung bình trượt thì dễ: `AVG(...) OVER (ORDER BY sale_date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)`. Viết trung vị trượt theo cùng kiểu:

```sql
SELECT sale_date,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue_m)
         OVER (ORDER BY sale_date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)
FROM daily_sales;
```

```text
ERROR:  OVER is not supported for ordered-set aggregate percentile_cont
```

`PERCENTILE_CONT` không có dạng hàm cửa sổ: không gắn `OVER (...)` vào nó được.

### Cách sửa: tính lại trung vị cho từng dòng

Không dùng được `OVER`, thì ta tự làm việc đó: với **mỗi dòng**, chạy một truy vấn con tính trung vị trên các dòng lân cận của nó.
- Đánh số các dòng theo ngày bằng `ROW_NUMBER`, để biết dòng nào cách dòng nào bao nhiêu.
- `CROSS JOIN LATERAL (truy vấn con)`: truy vấn con được chạy lại cho từng dòng `d` bên trái, và được dùng cột của `d`. Ở đây nó lấy các dòng có `rn` cách `d.rn` không quá 2, rồi tính trung vị.

```sql
WITH numbered AS (
  SELECT sale_date, revenue_m, ROW_NUMBER() OVER (ORDER BY sale_date) AS rn
  FROM daily_sales
)
SELECT d.sale_date, d.revenue_m,
       ROUND(AVG(d.revenue_m) OVER (ORDER BY d.sale_date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 1) AS rolling_avg,
       ROUND(w.med::numeric, 1) AS rolling_median
FROM numbered d
CROSS JOIN LATERAL (
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n.revenue_m) AS med
  FROM numbered n
  WHERE n.rn BETWEEN d.rn - 2 AND d.rn + 2
) w
ORDER BY d.sale_date;
```

| sale_date | revenue_m | rolling_avg | rolling_median |
| --- | --- | --- | --- |
| 2024-03-01 | 50 | 52.3 | 52.0 |
| 2024-03-02 | 55 | 139.3 | 53.5 |
| 2024-03-03 | 52 | 123.0 | 55.0 |
| 2024-03-04 | 400 | 125.0 | 58.0 |
| 2024-03-05 | 58 | 125.4 | 58.0 |
| 2024-03-07 | 60 | 143.8 | 59.0 |
| 2024-03-08 | 57 | 58.3 | 58.0 |

Ngày 400 triệu đẩy trung bình trượt của mọi dòng xung quanh lên hơn 120, trong khi doanh thu bình thường chỉ khoảng 55. Trung vị trượt gần như không đổi, vẫn quanh mức 52–59.

Đề nói "5 **dòng**" thì lọc theo `rn` như trên. Ngày 03-06 bị thiếu, nên cửa sổ của 03-05 đi thẳng sang 03-07. Nếu đề nói "5 **ngày**" thì lọc theo ngày: `n.sale_date BETWEEN d.sale_date - 2 AND d.sale_date + 2`. Khi đó ngày bị thiếu vẫn chiếm một chỗ trong cửa sổ, nên cửa sổ có ít dòng hơn.

> [!TIP]
> **Ghi nhớ:** `PERCENTILE_CONT` không dùng được với `OVER`. Muốn trung vị trượt thì đánh số dòng, rồi `CROSS JOIN LATERAL` một truy vấn con tính trung vị trên các dòng lân cận.
