# Subquery và Window function

> Phương ngữ: **PostgreSQL** (đúng engine của `check.py`). Mọi query dưới đây là lời giải mẫu của các bài `window/*` và `subquery/*`, đã chạy qua `q verify`.
> Cách học: đọc bảng chọn công cụ ở Phần 0 → mỗi mục W / S là một dạng, có khung viết, bẫy và bài luyện đi kèm.
> Bẫy chung (NULL, frame mặc định, top-N có hòa…) nằm ở [sql-common-pitfalls.md](sql-common-pitfalls.md); tài liệu này trỏ tới bằng mã mục (A3, E1, F2…). Các dạng phân tích ghép từ window (cohort, RFM, Pareto theo khách…) nằm ở [sql-analytics-patterns.md](sql-analytics-patterns.md).

**Mục lục**

| Mục | Nội dung | Bài tập |
| --- | --- | --- |
| 0 | Chọn subquery hay window | |
| W1 | `ROW_NUMBER` / `RANK` / `DENSE_RANK` | `window/01` |
| W2 | Hàm tổng hợp dùng như window: `AVG / COUNT OVER (PARTITION BY)` | `window/02` |
| W3 | Frame: tổng dồn, `ROWS` và `RANGE`, cửa sổ theo thời gian, frame loại dòng hiện tại | `window/03`, `07`, `11`, `12` |
| W4 | `LAG` / `LEAD` | `window/04`, `09` |
| W5 | `FIRST_VALUE` / `LAST_VALUE` | `window/05` |
| W6 | `NTILE`, `PERCENT_RANK`, `CUME_DIST` | `window/06` |
| W7 | Window trên kết quả `GROUP BY`, lọc ở truy vấn ngoài | `window/08`, `10` |
| S1 | Scalar subquery | `subquery/01`, `07` |
| S2 | Subquery tương quan (correlated) | `subquery/02`, `10`, `12` |
| S3 | Semi-join: `IN` / `EXISTS` | `subquery/03`, `11` |
| S4 | Bảng dẫn xuất: tổng hợp của tổng hợp | `subquery/04`, `09` |
| S5 | `ANY` / `ALL` | `subquery/05` |
| S6 | Giá trị lớn thứ N không dùng window | `subquery/06` |
| S7 | `LATERAL` | `subquery/08` |

---

## 0. Chọn subquery hay window

Cả hai đều trả lời câu hỏi "so dòng này với **một tập dòng khác**". Khác biệt nằm ở chỗ tập đó là gì:

| Tập để so sánh | Công cụ | Ví dụ |
| --- | --- | --- |
| Cả bảng, một giá trị | Scalar subquery (S1) hoặc `AGG() OVER ()` | Lương trên trung bình công ty |
| Nhóm của chính dòng này | `AGG() OVER (PARTITION BY ...)` (W2) hoặc subquery tương quan `=` (S2) | Lương so với trung bình phòng |
| Các dòng **trước** dòng này | Frame `ROWS ... PRECEDING` (W3) hoặc subquery tương quan `<` (S2) | Tổng dồn, trung bình các đơn trước |
| Dòng liền trước / liền sau | `LAG` / `LEAD` (W4) | Ngày từ đơn trước |
| Top N mỗi nhóm | `ROW_NUMBER`/`RANK` rồi lọc ngoài (W1, W7) hoặc `LATERAL ... LIMIT` (S7) | 2 đơn lớn nhất mỗi khách |
| "Có ít nhất một / không có" dòng khớp | `EXISTS` / `NOT EXISTS` (S3, E1) | Khách từng mua đồ điện tử |
| Tổng hợp của các tổng hợp | Bảng dẫn xuất (S4) hoặc `AGG(AGG()) OVER ()` (W7) | Trung bình số đơn mỗi khách |

Quy tắc ngón tay cái: cần **giữ từng dòng** và gắn thêm một con số thì dùng window. Cần **lọc** theo sự tồn tại của dòng khác thì dùng `EXISTS`. Cần một giá trị duy nhất để so sánh thì dùng scalar subquery. Window function thường chỉ đọc bảng một lần, còn subquery tương quan về logic chạy lại cho từng dòng.

**Thứ tự thực thi logic** (giải thích hầu hết lỗi ở phần này, xem 0.1 của pitfalls):

```
FROM / JOIN → WHERE → GROUP BY → HAVING → WINDOW → SELECT → DISTINCT → ORDER BY → LIMIT
```

Window chạy **sau** `WHERE`, `GROUP BY` và `HAVING`, nên không lọc được kết quả window ở ba chỗ đó (W7, E7). Nhưng vì chạy sau `GROUP BY`, window **dùng được hàm tổng hợp** bên trong (`SUM(SUM(x)) OVER ()`).

---

## W1. `ROW_NUMBER` / `RANK` / `DENSE_RANK` (`window/01`)

```sql
SELECT player, score,
       ROW_NUMBER() OVER (ORDER BY score DESC NULLS LAST, player) AS row_num,
       RANK()       OVER (ORDER BY score DESC NULLS LAST)         AS rnk,
       DENSE_RANK() OVER (ORDER BY score DESC NULLS LAST)         AS dense_rnk
FROM scores
ORDER BY score DESC NULLS LAST, player;
```

Ba hàm chỉ khác nhau khi có dòng **hòa** (cùng giá trị `ORDER BY`):

| Điểm | `ROW_NUMBER` | `RANK` | `DENSE_RANK` |
| --- | --- | --- | --- |
| 90 | 1 | 1 | 1 |
| 90 | 2 | 1 | 1 |
| 80 | 3 | 3 | 2 |

| Cần | Dùng |
| --- | --- |
| Đúng 1 dòng mỗi nhóm (khử trùng, bản ghi mới nhất) | `ROW_NUMBER` + cột phá hòa |
| Top N, ai hòa ở vị trí N cũng được vào | `RANK` |
| "Giá trị lớn thứ N" (theo giá trị khác nhau) | `DENSE_RANK` |

- `ROW_NUMBER` khi có hòa cho thứ tự **tùy ý**, mỗi lần chạy có thể khác. Luôn thêm cột phá hòa (`player`, `id`) để kết quả cố định (E6).
- PostgreSQL coi NULL là **lớn nhất**: `ORDER BY ... DESC` đưa NULL lên đầu. Muốn NULL xuống cuối phải viết `NULLS LAST`, ở cả trong `OVER (...)` lẫn `ORDER BY` cuối câu.
- Top N mỗi nhóm: `PARTITION BY nhóm`, rồi lọc `rn <= N` ở **truy vấn ngoài** (W7, `topn/*`).

## W2. Hàm tổng hợp dùng như window (`window/02`)

`GROUP BY` **gộp** mỗi nhóm thành một dòng. Window tính cùng phép gộp nhưng **giữ nguyên từng dòng** và gắn kết quả vào mỗi dòng:

```sql
SELECT name, department, salary,
       ROUND(AVG(salary) OVER (PARTITION BY department), 1)          AS dept_avg,
       ROUND(salary - AVG(salary) OVER (PARTITION BY department), 1) AS diff_from_avg,
       COUNT(*) OVER (PARTITION BY department)                       AS dept_headcount
FROM employees
ORDER BY department, name;
```

- `OVER (PARTITION BY d)` **không có `ORDER BY`**: cửa sổ là **cả nhóm**. Thêm `ORDER BY` vào thì thành tổng dồn (W3, F2).
- `OVER ()` rỗng: cửa sổ là **cả bảng**, dùng cho "% so với tổng" (`SUM(x) OVER ()`).
- `COUNT(*)` đếm mọi dòng, `COUNT(salary)` bỏ qua NULL (A3). Đề muốn đếm cả người lương NULL thì dùng `COUNT(*)`.
- Cách cũ: `GROUP BY` trong CTE rồi `JOIN` ngược lại bảng gốc. Kết quả giống, nhưng dài hơn và phải đọc bảng hai lần.

## W3. Frame: tổng dồn, `ROWS` và `RANGE`, cửa sổ theo thời gian (`window/03`, `07`, `11`, `12`)

**Frame** là tập dòng mà hàm nhìn thấy, tính tương đối so với dòng hiện tại:

```
<hàm> OVER (PARTITION BY ... ORDER BY ... {ROWS | RANGE} BETWEEN <bắt đầu> AND <kết thúc>)
   bắt đầu / kết thúc: UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
```

**a) Tổng dồn với giao dịch cùng ngày** (`window/03`). Có `ORDER BY` mà không ghi frame thì frame mặc định là `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. `RANGE` coi các dòng có **cùng** giá trị `ORDER BY` là ngang hàng (peers) và cộng tất cả cùng lúc, nên hai giao dịch cùng ngày ra cùng một số dư (F2b).

```sql
SELECT txn_id, txn_date, amount,
       SUM(amount) OVER (ORDER BY txn_date, txn_id
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
FROM transactions
ORDER BY txn_date, txn_id;
```

Sửa bằng một trong hai cách (làm cả hai càng chắc): thêm cột phá hòa để `ORDER BY` là duy nhất, hoặc dùng `ROWS`. Thói quen tốt: tổng dồn luôn ghi rõ `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.

**b) Cửa sổ 7 ngày lịch khi thiếu ngày** (`window/07`). `ROWS 6 PRECEDING` là 6 **dòng**, không phải 6 **ngày**. `RANGE` với `INTERVAL` lọc theo **giá trị** của cột `ORDER BY` (F2c):

```sql
SELECT sale_date, revenue,
       SUM(revenue) OVER (ORDER BY sale_date
                          RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW) AS rolling_7d
FROM daily_sales
ORDER BY sale_date;
```

`RANGE` có độ lệch cần **đúng một** cột `ORDER BY` kiểu số / ngày / timestamp. Cách khác: sinh đủ ngày bằng `generate_series`, `LEFT JOIN` điền 0, rồi dùng `ROWS` (`misc/05`). Biến thể theo tháng: `window/14`.

**c) Tổng dồn chia tổng cả bảng: Pareto** (`window/11`). Hai cửa sổ trong cùng một câu: tổng dồn và tổng toàn bảng.

```sql
WITH running AS (
    SELECT product, revenue,
           SUM(revenue) OVER w AS running_sum,
           SUM(revenue) OVER () AS total
    FROM product_sales
    WINDOW w AS (ORDER BY revenue DESC, product ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
SELECT product, revenue, ROUND(100.0 * running_sum / total, 1) AS cumulative_pct
FROM running
WHERE 100.0 * (running_sum - revenue) / total < 80
ORDER BY revenue DESC, product;
```

"Phần trăm **trước khi** thêm sản phẩm này" là `(running_sum − revenue) / total`. Điều kiện `< 80` giữ cả sản phẩm **vượt** qua mốc 80%. Nhân `100.0` trước khi chia để tránh chia số nguyên (A5). Biến thể theo khách, có hòa đi cùng nhau: analytics 2.11.

**d) Frame không gồm dòng hiện tại: tháng phá kỷ lục** (`window/12`).

```sql
WITH x AS (
    SELECT month, revenue,
           MAX(revenue) OVER (ORDER BY month
                              ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS previous_best
    FROM monthly_revenue
)
SELECT month, revenue, previous_best
FROM x
WHERE previous_best IS NULL OR revenue > previous_best
ORDER BY month;
```

Frame kết thúc ở `1 PRECEDING` nên là "kỷ lục tính đến tháng trước", và tháng đầu có frame rỗng nên ra NULL. Dùng frame mặc định (tới `CURRENT ROW`) rồi so `revenue >= running_max` sẽ tính nhầm tháng **hòa** kỷ lục là kỷ lục mới. Các frame khác nên biết: `ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING` (cửa sổ trượt 5 dòng có tâm), `ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` (từ đây tới cuối), `EXCLUDE GROUP` (bỏ các dòng hòa, analytics 2.11). Đỉnh lũy kế và drawdown: F4.

## W4. `LAG` / `LEAD` (`window/04`, `09`)

```sql
SELECT customer, order_date,
       LAG(order_date)  OVER w              AS prev_order_date,
       order_date - LAG(order_date) OVER w  AS days_since_prev,
       LEAD(order_date) OVER w              AS next_order_date
FROM orders
WINDOW w AS (PARTITION BY customer ORDER BY order_date)
ORDER BY customer, order_date;
```

- `LAG(x)` lấy `x` của dòng **trước**, `LEAD(x)` của dòng **sau**, theo `ORDER BY` trong `OVER`. `LAG(x, 2)` lấy dòng cách 2; `LAG(x, 1, 0)` dùng 0 thay cho NULL ở biên (F3).
- **Quên `PARTITION BY`** thì đơn đầu của khách này bị so với đơn cuối của khách khác.
- `WINDOW w AS (...)` đặt tên cho cửa sổ dùng lại nhiều lần.
- `DATE − DATE` ra số ngày (`integer`). Đơn đầu tiên có `LAG` là NULL nên `days_since_prev` tự ra NULL.

**Chỉ giữ dòng thay đổi** (`window/09`): đưa giá trị trước lên cùng dòng, rồi so sánh **an toàn với NULL**:

```sql
WITH x AS (
    SELECT product, changed_on, price,
           LAG(price)   OVER w AS old_price,
           ROW_NUMBER() OVER w AS rn
    FROM price_history
    WINDOW w AS (PARTITION BY product ORDER BY changed_on)
)
SELECT product, changed_on, old_price, price AS new_price
FROM x
WHERE rn = 1 OR price IS DISTINCT FROM old_price
ORDER BY product, changed_on;
```

`price <> old_price` loại mất dòng đầu (`10 <> NULL` ra UNKNOWN) và mọi lần đổi sang hoặc từ NULL. `IS DISTINCT FROM` coi NULL là một giá trị (A2, A4). Cần thêm `rn = 1` vì nếu bản ghi đầu tiên có giá NULL thì `NULL IS DISTINCT FROM NULL` ra FALSE. Lọc phải làm ở truy vấn **ngoài** (W7). Áp dụng cho chuỗi trạng thái: analytics 14.

## W5. `FIRST_VALUE` / `LAST_VALUE` (`window/05`)

```sql
SELECT name, department, salary,
       FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name) AS top_earner,
       FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary ASC,  name) AS lowest_earner
FROM employees
ORDER BY department, name;
```

- `FIRST_VALUE` luôn đúng, vì frame mặc định luôn bắt đầu từ đầu partition.
- `LAST_VALUE(name) OVER (... ORDER BY salary DESC, name)` thì **sai**: frame mặc định chỉ chạy tới dòng hiện tại, nên "dòng cuối" chính là dòng đang xét. Muốn dùng `LAST_VALUE` phải mở frame ra cả nhóm: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` (F3, `window/13`).
- Mẹo: **đảo chiều sắp xếp rồi dùng `FIRST_VALUE`**, không phải nhớ frame.
- Phá hòa bằng `name` trong `ORDER BY` để chọn được người đứng đầu bảng chữ cái.

## W6. `NTILE`, `PERCENT_RANK`, `CUME_DIST` (`window/06`)

```sql
SELECT customer, total_spent,
       NTILE(4) OVER (ORDER BY total_spent DESC, customer) AS quartile,
       ROUND((PERCENT_RANK() OVER (ORDER BY total_spent DESC))::numeric, 2) AS pct_rank
FROM customer_spend
ORDER BY total_spent DESC, customer;
```

| Hàm | Công thức | Dòng hòa | Dùng khi |
| --- | --- | --- | --- |
| `NTILE(k)` | Chia các dòng đã sắp thành k nhóm gần bằng nhau; dòng dư dồn cho các nhóm **đầu** (6 dòng / 4 nhóm thành 2, 2, 1, 1) | Có thể rơi vào hai nhóm khác nhau | Cần k nhóm đều nhau |
| `PERCENT_RANK()` | `(rank − 1) / (n − 1)`, từ 0 đến 1 | Cùng giá trị | Thứ hạng tương đối, dòng đầu là 0 |
| `CUME_DIST()` | Tỷ lệ số dòng ≤ dòng hiện tại (tính cả dòng hòa), từ 1/n đến 1 | Cùng giá trị | Phân vị: "thuộc top bao nhiêu %" |

- `NTILE` không quan tâm dòng hòa, nên thêm cột phá hòa để kết quả cố định. Nếu nghiệp vụ đòi "bằng nhau thì cùng nhóm" thì dùng `CEIL(k * CUME_DIST())` (analytics 2.12).
- `PERCENT_RANK` và `CUME_DIST` trả về `double precision`, mà `ROUND(double precision, int)` **không tồn tại**: `function round(double precision, integer) does not exist`. Phải ép `::numeric` trước khi `ROUND`.

## W7. Window trên kết quả `GROUP BY`, lọc ở truy vấn ngoài (`window/08`, `10`)

Window chạy **sau** `GROUP BY`, nên trong `OVER` dùng được hàm tổng hợp. Nhưng nó cũng chạy sau `WHERE` / `HAVING`, nên muốn lọc theo kết quả window thì phải bọc vào CTE hoặc subquery rồi lọc ở ngoài (E7):

```sql
WITH ranked AS (
    SELECT TO_CHAR(sale_date, 'YYYY-MM') AS month,
           product,
           SUM(qty) AS total_qty,
           DENSE_RANK() OVER (PARTITION BY TO_CHAR(sale_date, 'YYYY-MM')
                              ORDER BY SUM(qty) DESC) AS rank_in_month
    FROM sales
    GROUP BY TO_CHAR(sale_date, 'YYYY-MM'), product
)
SELECT month, product, total_qty, rank_in_month
FROM ranked
WHERE rank_in_month <= 2
ORDER BY month, rank_in_month, product;
```

- `ORDER BY SUM(qty) DESC` trong `OVER` là xếp hạng theo **tổng của nhóm**.
- `WHERE rank_in_month <= 2` trong **cùng** câu `SELECT` báo lỗi. `HAVING` cũng không thấy window function.
- Dùng `ROW_NUMBER` thay `DENSE_RANK` thì hai sản phẩm hòa hạng 1 chỉ còn lại một.

**Đếm khác nhau lũy kế** (`window/10`): `COUNT(DISTINCT customer) OVER (ORDER BY order_date)` báo lỗi `DISTINCT is not implemented for window functions`. Mẹo chuẩn: "số khách khác nhau tính đến ngày D" = "số khách có ngày mua **đầu tiên** ≤ D".

```sql
WITH first_order AS (
    SELECT customer, MIN(order_date) AS first_date FROM orders GROUP BY customer
),
days AS (
    SELECT DISTINCT order_date FROM orders
)
SELECT d.order_date,
       COUNT(f.customer) AS new_customers,
       SUM(COUNT(f.customer)) OVER (ORDER BY d.order_date) AS cumulative_customers
FROM days d
LEFT JOIN first_order f ON f.first_date = d.order_date
GROUP BY d.order_date
ORDER BY d.order_date;
```

`SUM(COUNT(...)) OVER (...)`: `COUNT` bên trong chạy ở bước `GROUP BY`, `SUM` bên ngoài là window chạy trên các dòng đã gộp. Bảng `days` riêng (`LEFT JOIN`) để ngày không có khách mới vẫn hiện với 0. Bước tìm ngày đầu cũng viết được bằng `ROW_NUMBER() OVER (PARTITION BY customer ORDER BY order_date) = 1`.

---

## S1. Scalar subquery (`subquery/01`, `07`)

Subquery trả về **đúng một giá trị** (một dòng, một cột) dùng được như một hằng số:

```sql
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC, name;
```

- Subquery **không tương quan** (không nhắc tới bảng ngoài): DB tính một lần rồi dùng lại.
- `WHERE salary > AVG(salary)` báo lỗi: hàm tổng hợp không dùng được trong `WHERE`, vì `WHERE` chạy trước khi gộp.
- Scalar subquery **không có dòng nào** thì ra NULL. Trả về **hơn một dòng** thì báo lỗi `more than one row returned by a subquery used as an expression`.

**Luôn trả về đúng một dòng, kể cả khi không có đáp án** (`subquery/07`): truy vấn có hàm tổng hợp mà không có `GROUP BY` luôn ra một dòng, và `MAX` của tập rỗng là NULL (A6).

```sql
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);
```

`SELECT DISTINCT salary ... ORDER BY salary DESC LIMIT 1 OFFSET 1` trả về **0 dòng** khi chỉ có một mức lương, không phải một dòng NULL. Muốn giữ cách viết đó thì bọc nó thành scalar subquery: `SELECT (SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT 1 OFFSET 1) AS second_highest`.

## S2. Subquery tương quan (`subquery/02`, `10`, `12`)

Subquery **tham chiếu dòng của truy vấn ngoài**. Về logic, nó chạy lại cho từng dòng ngoài:

```sql
SELECT name, units_sold,
       ROUND(100.0 * units_sold / NULLIF((SELECT SUM(qty) FROM order_items), 0), 1) AS pct_of_units
FROM (
    SELECT p.name,
           COALESCE((SELECT SUM(i.qty) FROM order_items i WHERE i.product_id = p.product_id), 0) AS units_sold
    FROM products p
) t
ORDER BY units_sold DESC, name;
```

- Không có dòng nào khớp thì `SUM` ra **NULL**, không phải 0, nên phải `COALESCE(..., 0)`.
- Alias trong `SELECT` không dùng lại được trong chính `SELECT` đó hay trong `WHERE` cùng cấp. Bọc vào bảng dẫn xuất (`t`) rồi dùng ở ngoài.
- Cách thường nhanh hơn trên bảng lớn: `products LEFT JOIN (SELECT product_id, SUM(qty) ... GROUP BY product_id) s`.

**Tương quan không nhất thiết là dấu `=`** (`subquery/10`): `x.txn_id <= t.txn_id` nghĩa là "mọi giao dịch từ đầu tới giao dịch hiện tại", tức là tổng dồn không cần window:

```sql
SELECT t.txn_id, t.amount,
       (SELECT SUM(x.amount) FROM transactions x WHERE x.txn_id <= t.txn_id) AS running_total
FROM transactions t
ORDER BY t.txn_id;
```

Chi phí khoảng O(n²), trong khi `SUM() OVER (ORDER BY txn_id)` chỉ quét một lần. Vẫn nên biết cách này cho DB cũ không có window (MySQL < 8), và vì kiểu tư duy "tập các dòng thỏa điều kiện so với dòng hiện tại" được dùng lại ở rất nhiều bài.

**Hai điều kiện: cùng khách và đứng trước** (`subquery/12`), dùng so sánh bộ:

```sql
SELECT order_id, customer, amount, ROUND(prev_avg, 1) AS prev_avg
FROM (
    SELECT o.order_id, o.customer, o.amount,
           (SELECT AVG(x.amount)
            FROM orders x
            WHERE x.customer = o.customer
              AND (x.order_date, x.order_id) < (o.order_date, o.order_id)) AS prev_avg
    FROM orders o
) t
WHERE amount > 2 * prev_avg
ORDER BY order_id;
```

- `(a, b) < (c, d)` nghĩa là `a < c`, hoặc `a = c AND b < d`: "trước" theo ngày, hòa thì theo id.
- Đơn đầu tiên có `prev_avg` là NULL, nên `amount > 2 * NULL` ra UNKNOWN và tự bị loại.
- Cách bằng window: `AVG(amount) OVER (PARTITION BY customer ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)` (frame của W3d).

## S3. Semi-join: `IN` / `EXISTS` (`subquery/03`, `11`)

"Có **ít nhất một** dòng khớp" là **semi-join**: mỗi dòng bảng trái xuất hiện tối đa một lần, dù bên phải khớp bao nhiêu dòng.

```sql
SELECT c.name
FROM customers c
WHERE c.customer_id IN (
    SELECT o.customer_id
    FROM orders o
    JOIN products p ON p.product_id = o.product_id
    WHERE p.category = 'Electronics'
)
ORDER BY c.name, c.customer_id;
```

- `customers JOIN orders JOIN products` làm khách có 3 đơn điện tử hiện 3 lần.
- "Chữa" bằng `SELECT DISTINCT name` thì **sai theo kiểu khác**: hai khách khác nhau cùng tên bị gộp làm một (C5). `DISTINCT` trên cột hiển thị không thay thế được việc giữ đúng số dòng của bảng gốc.
- Viết bằng `EXISTS`: `WHERE EXISTS (SELECT 1 FROM orders o JOIN products p ON ... WHERE o.customer_id = c.customer_id AND p.category = 'Electronics')`. `IN` an toàn với NULL, còn **`NOT IN` thì không** (E1b).

**Nhiều điều kiện trên nhiều dòng của cùng một thực thể** (`subquery/11`): một dòng không thể vừa ở tháng 1 vừa ở tháng 2, nên mỗi điều kiện là một `EXISTS` riêng:

```sql
SELECT DISTINCT o.customer
FROM orders o
WHERE EXISTS (SELECT 1 FROM orders x WHERE x.customer = o.customer
                AND x.order_date >= DATE '2024-01-01' AND x.order_date < DATE '2024-02-01')
  AND EXISTS (SELECT 1 FROM orders x WHERE x.customer = o.customer
                AND x.order_date >= DATE '2024-02-01' AND x.order_date < DATE '2024-03-01')
  AND NOT EXISTS (SELECT 1 FROM orders x WHERE x.customer = o.customer
                AND x.order_date >= DATE '2024-03-01' AND x.order_date < DATE '2024-04-01')
ORDER BY o.customer;
```

Dùng khoảng nửa mở `[đầu tháng, đầu tháng sau)` thay cho `EXTRACT(MONTH ...)`: tự đúng với năm, không phải nhớ tháng 2 có 28 hay 29 ngày, và dùng được index (B2, B3). Hai cách tương đương: `GROUP BY customer HAVING BOOL_OR(tháng 1) AND BOOL_OR(tháng 2) AND NOT BOOL_OR(tháng 3)`, hoặc phép tập hợp `INTERSECT` / `EXCEPT` (G2, G3).

## S4. Bảng dẫn xuất: tổng hợp của tổng hợp (`subquery/04`, `09`)

`AVG(COUNT(*))` báo lỗi `aggregate function calls cannot be nested`. Đặt tầng 1 vào subquery trong `FROM` (bảng dẫn xuất, **bắt buộc có alias**), tầng 2 ở ngoài:

```sql
SELECT COUNT(*) AS customers,
       ROUND(AVG(order_count), 2) AS avg_orders,
       MAX(order_count) AS max_orders
FROM (
    SELECT c.customer_id, COUNT(o.order_id) AS order_count
    FROM customers c
    LEFT JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
) per_customer;
```

- Chỉ đếm trên `orders` thì khách 0 đơn biến mất, nên trung bình bị **đội lên**. Phải xuất phát từ `customers` và `LEFT JOIN`.
- Sau `LEFT JOIN`, `COUNT(*)` đếm cả dòng NULL (khách 0 đơn thành 1). Dùng `COUNT(o.order_id)`.
- CTE (`WITH per_customer AS (...)`) chỉ là bảng dẫn xuất có đặt tên, dễ đọc hơn khi lồng nhiều tầng.

**So mỗi nhóm với trung bình các nhóm** (`subquery/09`):

```sql
SELECT category, SUM(amount) AS revenue
FROM sales
GROUP BY category
HAVING SUM(amount) > (
    SELECT AVG(category_total)
    FROM (SELECT SUM(amount) AS category_total FROM sales GROUP BY category) totals
)
ORDER BY revenue DESC, category;
```

`HAVING SUM(amount) > (SELECT AVG(amount) FROM sales)` so với trung bình mỗi **dòng**, không phải trung bình mỗi **nhóm** (E3). Cách khác bằng window: `AVG(SUM(amount)) OVER ()` trong cùng câu `GROUP BY`, rồi lọc ở truy vấn ngoài (W7).

## S5. `ANY` / `ALL` (`subquery/05`)

```sql
SELECT name, price
FROM products
WHERE category <> 'Budget'
  AND price IS NOT NULL
  AND price > ALL (SELECT price FROM products
                   WHERE category = 'Budget' AND price IS NOT NULL)
ORDER BY price DESC, name;
```

| Biểu thức | Đúng khi | Tương đương |
| --- | --- | --- |
| `x > ALL (tập)` | x lớn hơn **mọi** phần tử | `x > (SELECT MAX ...)` trừ khi tập rỗng |
| `x > ANY (tập)` | x lớn hơn **ít nhất một** phần tử | `x > (SELECT MIN ...)` trừ khi tập rỗng |
| `x = ANY (tập)` | | `x IN (tập)` |
| `x <> ALL (tập)` | | `x NOT IN (tập)` (cùng bẫy NULL, E1b) |

- **Tập rỗng**: `x > ALL (rỗng)` là TRUE (không có phần tử nào để thua), kể cả khi `x` là NULL. Vì vậy phải tự thêm `price IS NOT NULL` ở ngoài. Ngược lại, `price > (SELECT MAX(price) ...)` với tập rỗng ra `price > NULL`, loại hết. Hai cách **khác nhau** đúng ở trường hợp biên này (E5).
- **Tập có NULL**: `30 > ALL (10, NULL)` ra UNKNOWN, nên không dòng nào qua. Phải lọc `IS NOT NULL` **bên trong** subquery.

## S6. Giá trị lớn thứ N không dùng window (`subquery/06`)

Lương L là cao thứ N (theo giá trị khác nhau) khi có **đúng N − 1** mức lương khác nhau lớn hơn L trong cùng nhóm:

```sql
SELECT DISTINCT e.department, e.salary AS third_highest
FROM employees e
WHERE e.salary IS NOT NULL
  AND (SELECT COUNT(DISTINCT x.salary)
       FROM employees x
       WHERE x.department = e.department
         AND x.salary > e.salary) = 2
ORDER BY e.department;
```

- `COUNT(DISTINCT ...)`: hai người cùng lương 200 chỉ là **một mức**. Đếm `COUNT(*)` thì thứ hạng bị lệch.
- `SELECT DISTINCT` ở ngoài: hai nhân viên cùng lương thứ 3 đều thỏa điều kiện, nên phải gộp thành một dòng.
- Độ phức tạp khoảng O(n²) mỗi nhóm. Phỏng vấn hay hỏi cách này (thường kèm "không dùng window / `LIMIT`"), còn thực tế dùng `DENSE_RANK() ... = N` (W1, `topn/*`) gọn và nhanh hơn.

## S7. `LATERAL` (`subquery/08`)

Subquery trong `FROM` bình thường **không nhìn thấy** bảng đứng trước nó. Thêm `LATERAL` thì subquery tham chiếu được dòng của bảng trước và chạy lại cho từng dòng, nên `ORDER BY ... LIMIT` áp dụng **riêng cho mỗi nhóm**:

```sql
SELECT c.name, t.order_id, t.amount
FROM customers c
LEFT JOIN LATERAL (
    SELECT o.order_id, o.amount
    FROM orders o
    WHERE o.customer_id = c.customer_id
    ORDER BY o.amount DESC, o.order_id
    LIMIT 2
) t ON true
ORDER BY c.name, t.amount DESC, t.order_id;
```

- `LEFT JOIN LATERAL ... ON true` giữ khách không có đơn (cột bên phải NULL). `CROSS JOIN LATERAL` loại khách đó.
- Quên điều kiện tương quan (`WHERE o.customer_id = c.customer_id`) thì mọi khách đều nhận 2 đơn lớn nhất của **toàn bảng**.
- So với `ROW_NUMBER() OVER (PARTITION BY ...) <= 2`: kết quả giống nhau. `LATERAL` mạnh hơn khi có index `(customer_id, amount)` và mỗi khách có rất nhiều đơn, vì DB chỉ cần đọc 2 dòng đầu mỗi khách.
- Các dạng khác của "một dòng tốt nhất cho mỗi dòng ngoài": giá có hiệu lực tại ngày (analytics 12.6), luật phân khúc ưu tiên cao nhất (analytics 2.13).
