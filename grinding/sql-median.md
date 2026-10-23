# Trung vị và phân vị

> Bài liên quan: `median/01`–`04`, `misc/04`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** một khách, một đơn hay một ngày **điển hình** trông thế nào?

**Vì sao không dùng trung bình:** chỉ cần vài giá trị rất lớn là trung bình bị kéo lệch. Ví dụ nhóm Phones có 4 sản phẩm giá 3, 4, 5 và 30 triệu:

| category | n | avg_price | median_price | median_disc |
| --- | --- | --- | --- | --- |
| Headphones | 3 | 300000 | 300000 | 300000 |
| Phones | 4 | **10500000** | **4500000** | 4000000 |

Trung bình 10,5 triệu không đại diện cho sản phẩm nào. Trung vị là giá trị **đứng giữa** khi sắp xếp, nên không bị chiếc điện thoại 30 triệu kéo lên. So sánh trung bình với trung vị cũng cho biết hình dạng dữ liệu: trung bình lớn hơn trung vị nghĩa là có vài giá trị rất lớn (lệch phải).

**Cách nhanh nhất** là dùng hàm có sẵn:
- `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)`: khi số phần tử chẵn, lấy trung bình hai giá trị giữa.
- `PERCENTILE_DISC(0.5) ...`: lấy giá trị giữa thấp hơn, luôn là một giá trị có thật trong dữ liệu.

Hai hàm này dùng với `GROUP BY` như `AVG`. Kết quả có kiểu `double precision`, nên phải ép `::numeric` trước khi `ROUND`.

Các bước dưới đây là cách **tự tìm vị trí giữa**. Cần đến cách này khi đề cấm hàm có sẵn, khi dữ liệu là bảng tần suất, hoặc khi cần trung vị trượt (vì hàm có sẵn không dùng được với `OVER`).

1. Loại `NULL`
2. Đánh số vị trí và đếm tổng
3. Giữ 1 hoặc 2 vị trí giữa
4. Lấy trung bình

Ví dụ chạy xuyên suốt dùng bảng `employees`:

| emp_id | department | salary_vnd |
| --- | --- | --- |
| 1 | Engineering | 25000000 |
| 2 | Engineering | 40000000 |
| 3 | Engineering | 20000000 |
| 4 | Engineering | 25000000 |
| 5 | Sales | 15000000 |
| 6 | Sales | NULL |
| 7 | Sales | 18000000 |
| 8 | Sales | 12000000 |
| 9 | Accounting | 10000000 |
| 10 | Accounting | 14000000 |
| 11 | HR | NULL |

---

## B1. Loại `NULL`

- **Vấn đề:** `NULL` không phải một mức lương, nhưng nếu còn trong dữ liệu thì nó vẫn chiếm một vị trí khi đánh số.
- **Tại sao:** phải lọc trong `WHERE`, tức là **trước** khi window function chạy. Nếu không lọc, Sales ra `n = 4` và vị trí giữa bị lệch:

| department | salary_vnd | rn | n |
| --- | --- | --- | --- |
| Sales | 12000000 | 1 | 4 |
| Sales | 15000000 | 2 | 4 |
| Sales | 18000000 | 3 | 4 |
| Sales | NULL | 4 | 4 |

```sql
WHERE salary_vnd IS NOT NULL
```

## B2. Đánh số vị trí và đếm tổng

- **Vấn đề:** muốn biết dòng nào nằm giữa thì cần biết thứ tự của từng dòng và tổng số dòng `n` trong nhóm.
- **Tại sao:**
  - Phải dùng `ROW_NUMBER`. `RANK` và `DENSE_RANK` cho các giá trị trùng nhau cùng một số, nên dãy số bị đứt quãng (`RANK` cho 1, 2, 2, 4, không có vị trí 3) và có thể không tìm thấy vị trí giữa.
  - `COUNT(*) OVER (PARTITION BY ...)` gắn tổng số dòng của nhóm lên mọi dòng.

```sql
ranked AS (
  SELECT department, salary_vnd,
         ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary_vnd) AS rn,
         COUNT(*)     OVER (PARTITION BY department)                     AS n
  FROM employees
  WHERE salary_vnd IS NOT NULL
)
```

| department | salary_vnd | rn | n |
| --- | --- | --- | --- |
| Accounting | 10000000 | 1 | 2 |
| Accounting | 14000000 | 2 | 2 |
| Engineering | 20000000 | 1 | 4 |
| Engineering | 25000000 | 2 | 4 |
| Engineering | 25000000 | 3 | 4 |
| Engineering | 40000000 | 4 | 4 |
| Sales | 12000000 | 1 | 3 |
| Sales | 15000000 | 2 | 3 |
| Sales | 18000000 | 3 | 3 |

**Khi dữ liệu là bảng tần suất** (giá trị, số lần):
- Không bung ra thành từng dòng. Thay vào đó, tính **khoảng vị trí** mà mỗi giá trị chiếm, bằng tổng lũy kế: từ `cum - freq + 1` đến `cum`.
- `SUM(bigint)` trả về `numeric`. Phải ép `::bigint`, nếu không bước 3 sẽ ra `(10 + 1) / 2 = 5.5`, không nằm trong khoảng nào.

```sql
SUM(orders) OVER (PARTITION BY store ORDER BY items)::bigint - orders + 1 AS pos_from,
SUM(orders) OVER (PARTITION BY store ORDER BY items)::bigint              AS pos_to,
SUM(orders) OVER (PARTITION BY store)::bigint                             AS total
```

| items | orders | pos_from | pos_to | total |
| --- | --- | --- | --- | --- |
| 1 | 5 | 1 | 5 | 10 |
| 2 | 3 | 6 | 8 | 10 |
| 3 | 1 | 9 | 9 | 10 |
| 4 | 1 | 10 | 10 | 10 |

## B3. Giữ 1 hoặc 2 vị trí giữa

- **Vấn đề:** `n` lẻ thì có một dòng giữa, `n` chẵn thì có hai.
- **Tại sao:** `(n + 1) / 2` và `(n + 2) / 2` với **phép chia số nguyên** cho ra đúng các vị trí cần giữ:
  - `n = 3`: cả hai ra 2, giữ một dòng.
  - `n = 4`: ra 2 và 3, giữ hai dòng.

```sql
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
```

| department | salary_vnd | rn | n | lo | hi |
| --- | --- | --- | --- | --- | --- |
| Accounting | 10000000 | 1 | 2 | 1 | 2 |
| Accounting | 14000000 | 2 | 2 | 1 | 2 |
| Engineering | 25000000 | 2 | 4 | 2 | 3 |
| Engineering | 25000000 | 3 | 4 | 2 | 3 |
| Sales | 15000000 | 2 | 3 | 2 | 2 |

**Với bảng tần suất:** giữ những giá trị có khoảng vị trí chứa `lo` hoặc `hi`, tức `lo BETWEEN pos_from AND pos_to OR hi BETWEEN pos_from AND pos_to`. Ví dụ District 1 có `total = 10`, nên lấy vị trí 5 và 6, tức giá trị 1 và 2.

## B4. Lấy trung bình

- **Vấn đề:** gộp 1 hoặc 2 dòng giữa thành một con số.
- **Tại sao:** `AVG` của 1 dòng là chính dòng đó, của 2 dòng là trung bình hai dòng. Nhờ vậy cùng một câu lệnh dùng được cho cả `n` chẵn và `n` lẻ.

```sql
SELECT department, ROUND(AVG(salary_vnd), 1) AS median_salary
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
GROUP BY department;
```

| department | median_salary |
| --- | --- |
| Accounting | 12000000.0 |
| Engineering | 25000000.0 |
| Sales | 15000000.0 |

HR không có lương nào sau khi lọc `NULL`, nên tự biến mất khỏi kết quả.

## Tổng kết: query đầy đủ

Ghép B1 → B4 thành một câu:

```sql
WITH ranked AS (                                   -- B1 + B2: bỏ NULL, đánh số, đếm tổng
  SELECT department, salary_vnd,
         ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary_vnd) AS rn,
         COUNT(*)     OVER (PARTITION BY department)                     AS n
  FROM employees
  WHERE salary_vnd IS NOT NULL
)
SELECT department, ROUND(AVG(salary_vnd), 1) AS median_salary   -- B4: trung bình 1 hoặc 2 dòng giữa
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)                           -- B3: giữ vị trí giữa
GROUP BY department
ORDER BY department;
```

| department | median_salary |
| --- | --- |
| Accounting | 12000000.0 |
| Engineering | 25000000.0 |
| Sales | 15000000.0 |


---

## Khi cần trung vị trượt

- **Vấn đề:** `AVG(...) OVER (ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)` chạy được, nhưng `PERCENTILE_CONT ... OVER` thì báo lỗi `OVER is not supported for ordered-set aggregate percentile_cont`.
- **Tại sao:** `PERCENTILE_CONT` không có dạng window. Muốn có trung vị trượt thì phải chạy lại phép tính trung vị cho **từng dòng**, trên các dòng lân cận của nó:
  - Đánh số các dòng bằng `ROW_NUMBER`.
  - Với mỗi dòng, dùng `LATERAL` để tính trung vị trên các dòng có `rn` cách nó không quá 2.

```sql
WITH numbered AS (
  SELECT sale_date, revenue_m, ROW_NUMBER() OVER (ORDER BY sale_date) AS rn FROM daily_sales
)
SELECT d.sale_date, d.revenue_m,
       ROUND(AVG(d.revenue_m) OVER (ORDER BY d.sale_date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 1) AS rolling_avg,
       ROUND(w.med::numeric, 1) AS rolling_median
FROM numbered d
CROSS JOIN LATERAL (
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n.revenue_m) AS med
  FROM numbered n
  WHERE n.rn BETWEEN d.rn - 2 AND d.rn + 2
) w;
```

| sale_date | revenue_m | rolling_avg | rolling_median |
| --- | --- | --- | --- |
| 2024-02-01 | 100 | 110.0 | 110.0 |
| 2024-02-02 | 120 | 307.5 | 115.0 |
| 2024-02-03 | 110 | 272.0 | 120.0 |
| 2024-02-04 | 900 | 277.0 | 125.0 |
| 2024-02-05 | 130 | 281.0 | 130.0 |
| 2024-02-06 | 125 | 286.0 | 135.0 |
| 2024-02-08 | 140 | 132.5 | 132.5 |
| 2024-02-09 | 135 | 133.3 | 135.0 |

Ngày 900 đẩy trung bình trượt của 5 dòng xung quanh lên gần 300, còn trung vị trượt gần như không đổi.

Đề nói "5 dòng" thì lọc theo `rn`. Nếu đề nói "5 **ngày**" thì lọc theo `n.sale_date BETWEEN d.sale_date - 2 AND d.sale_date + 2`, khi đó ngày bị thiếu cũng được tính là một ngày trong cửa sổ.
