# Subquery

> Bài liên quan: `subquery/01`–`12`. Output đều chạy thật bằng `check.py`.

## Bài toán

Nhiều câu hỏi cần **kết quả của một truy vấn khác** để lọc hoặc tính một dòng: đơn lớn hơn trung bình, khách từng mua đồ điện tử, khách chưa mua gì, trung bình mỗi khách có bao nhiêu đơn.

Những câu hỏi này không viết thẳng được trong một tầng `SELECT`:
- `WHERE amount > AVG(amount)` báo lỗi `aggregate functions are not allowed in WHERE`, vì `WHERE` chạy **trước** khi gộp, nên lúc đó chưa có `AVG`.
- `AVG(COUNT(*))` báo lỗi `aggregate function calls cannot be nested`: không lồng hàm gộp vào hàm gộp được.

Cả hai đều cần tính một thứ **trước**, rồi mới dùng kết quả đó. Truy vấn con (subquery) làm việc này. Có năm dạng truy vấn con, mỗi dạng trả lời một kiểu câu hỏi. Phần 1 trình bày cả năm dạng trên cùng một bộ dữ liệu.

## Dữ liệu

Hai bảng, quan hệ **1 khách – nhiều đơn**.

`customers`: mỗi dòng = 1 khách. Có **hai khách cùng tên Alice** (id 1 và id 4).

| customer_id | name |
| --- | --- |
| 1 | Alice |
| 2 | Ben |
| 3 | Chloe |
| 4 | Alice |

`orders`: mỗi dòng = 1 đơn. Đơn 6 là khách vãng lai, `customer_id` là `NULL`.

| order_id | customer_id | category | amount |
| --- | --- | --- | --- |
| 1 | 1 | Electronics | 500 |
| 2 | 1 | Electronics | 300 |
| 3 | 1 | Books | 100 |
| 4 | 2 | Books | 50 |
| 5 | 2 | Electronics | 250 |
| 6 | NULL | Books | 80 |
| 7 | 4 | Electronics | 120 |

Ba chỗ dễ sai: hai khách **cùng tên**, Chloe **chưa mua gì**, và đơn 6 **không gắn với khách nào**.

## Năm dạng subquery

Mỗi dạng độc lập với nhau: gặp câu hỏi kiểu nào thì dùng dạng đó, không cần đi lần lượt.

| Dạng | Câu hỏi | Kiểu truy vấn con | Đặt ở đâu |
| --- | --- | --- | --- |
| D1 | So với **một giá trị** của cả bảng | vô hướng (scalar) | `WHERE`, `SELECT` |
| D2 | So với **một giá trị riêng** cho từng dòng | tương quan (correlated) | `WHERE`, `SELECT` |
| D3 | **Có hay không có** dòng khớp | `EXISTS` / `NOT EXISTS` | `WHERE` |
| D4 | Gộp của gộp | bảng dẫn xuất (derived table) | `FROM` |
| D5 | Mỗi dòng ngoài lấy N dòng bên trong | `LATERAL` | `FROM` / `JOIN` |

Ví dụ trong từng dạng chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại.

---

# Phần 1: Năm dạng subquery

## D1. So với một giá trị của cả bảng (truy vấn con vô hướng)

**Ý tưởng:** đề hỏi các đơn lớn hơn **trung bình của mọi đơn**. Tính trung bình bằng một truy vấn con, rồi dùng kết quả như một hằng số. Truy vấn con trả về **đúng một dòng, một cột** gọi là truy vấn con vô hướng. Nó không nhắc tới bảng bên ngoài, nên chỉ cần tính một lần.

**Ví dụ nhỏ:** trung bình 7 đơn là 1400 / 7 = 200.

| order_id | amount | > 200? |
| --- | --- | --- |
| 1 | 500 | yes |
| 2 | 300 | yes |
| 3 | 100 | no |
| 5 | 250 | yes |
| ... | | |

```sql
SELECT order_id, amount
FROM orders
WHERE amount > (SELECT AVG(amount) FROM orders);
```

Kết quả: đơn 1, 2, 5. Nếu truy vấn con không trả về dòng nào, giá trị của nó là `NULL`.

> [!CAUTION]
> ❌ **Truy vấn con trả về nhiều dòng: `amount > (SELECT amount FROM orders WHERE category = 'Electronics')`**
>
> ```text
> ERROR:  more than one row returned by a subquery used as an expression
> ```
>
> Có 4 đơn Electronics, nên truy vấn con ra 4 giá trị, và `>` không biết so với giá trị nào.
>
> → **Sửa:** gộp về một giá trị (`MAX`, `AVG`...), hoặc dùng `> ALL (...)` / `> ANY (...)` (xem V5).

## D2. So với một giá trị riêng cho từng dòng (truy vấn con tương quan)

**Ý tưởng:** đề hỏi các đơn lớn hơn **trung bình của chính khách đó**. Mỗi đơn cần một trung bình khác nhau. Truy vấn con nhắc tới dòng của truy vấn ngoài (`x.customer_id = o.customer_id`), nên về mặt logic nó chạy lại cho từng đơn, với khách của đơn đó. Kiểu này gọi là truy vấn con **tương quan**.

**Ví dụ nhỏ:**

| order_id | customer | amount | avg of this customer | kept? |
| --- | --- | --- | --- | --- |
| 1 | 1 | 500 | 300 = (500 + 300 + 100) / 3 | yes |
| 3 | 1 | 100 | 300 | no |
| 5 | 2 | 250 | 150 = (50 + 250) / 2 | yes |
| 6 | NULL | 80 | NULL (no matching rows) | no |
| ... | | | | |

```sql
SELECT o.order_id, o.customer_id, o.amount
FROM orders o
WHERE o.amount > (SELECT AVG(x.amount) FROM orders x WHERE x.customer_id = o.customer_id);
```

Kết quả: đơn 1 và đơn 5. Với đơn 6, `x.customer_id = NULL` không khớp dòng nào, nên trung bình là `NULL` và đơn 6 tự bị loại.

Truy vấn con tương quan cũng đặt được trong `SELECT`, để thêm một cột tính riêng cho mỗi dòng, ví dụ tổng tiền của mỗi khách:

```sql
SELECT c.customer_id, c.name,
       COALESCE((SELECT SUM(o.amount) FROM orders o WHERE o.customer_id = c.customer_id), 0) AS total
FROM customers c;
```

| customer_id | name | `SUM` alone | total |
| --- | --- | --- | --- |
| 1 | Alice | 900 | 900 |
| 2 | Ben | 300 | 300 |
| 3 | Chloe | NULL | 0 |
| 4 | Alice | 120 | 120 |

> [!CAUTION]
> ❌ **Quên `COALESCE` khi khách không có dòng nào**
>
> Chloe chưa mua gì. `SUM` của một tập rỗng là `NULL`, không phải 0. Cột tổng tiền của Chloe ra `NULL`, và mọi phép tính sau đó với Chloe (cộng, so sánh) cũng ra `NULL`.
>
> → **Sửa:** `COALESCE((SELECT SUM(...) ...), 0)`.

## D3. Có hay không có dòng khớp (`EXISTS` / `NOT EXISTS`)

**Ý tưởng:** đề hỏi **những khách từng mua đồ điện tử**, mỗi khách một dòng. `EXISTS (truy vấn con)` chỉ hỏi "có ít nhất một dòng khớp hay không", và ra `true` / `false`. Nó không nhân dòng của truy vấn ngoài, dù khớp bao nhiêu dòng.

**Ví dụ nhỏ:**

| customer_id | name | Electronics orders | `EXISTS` |
| --- | --- | --- | --- |
| 1 | Alice | 1, 2 | true |
| 2 | Ben | 5 | true |
| 3 | Chloe | (none) | false |
| 4 | Alice | 7 | true |

```sql
SELECT c.customer_id, c.name
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o
              WHERE o.customer_id = c.customer_id AND o.category = 'Electronics')
ORDER BY c.name, c.customer_id;
```

Kết quả: Alice (1), Alice (4), Ben. `SELECT 1` bên trong chỉ là quy ước: `EXISTS` không quan tâm lấy cột gì, chỉ quan tâm có dòng hay không.

> [!CAUTION]
> ❌ **Dùng `JOIN` rồi `DISTINCT name`**
>
> `JOIN` cho Alice (1) hai dòng, vì Alice có hai đơn Electronics. Thêm `DISTINCT name` để bỏ trùng thì lại gộp **hai khách khác nhau** cùng tên Alice thành một dòng: kết quả chỉ còn Alice, Ben.
>
> → **Sửa:** `EXISTS`. Mỗi khách xuất hiện đúng một lần, và hai khách cùng tên vẫn là hai dòng.
>
> ---
>
> ❌ **Tìm khách chưa mua bằng `customer_id NOT IN (SELECT customer_id FROM orders)`**
>
> Kết quả ra **0 dòng**, dù Chloe chưa mua gì. Đơn 6 có `customer_id` là `NULL`, nên danh sách là (1, 1, 1, 2, 2, NULL, 4). Với Chloe, `3 NOT IN (..., NULL, ...)` phải so `3 <> NULL`, ra `NULL` chứ không ra `true`, nên Chloe bị loại.
>
> → **Sửa:** `WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)`, ra đúng Chloe.

## D4. Gộp của gộp (bảng dẫn xuất)

**Ý tưởng:** đề hỏi **trung bình mỗi khách có bao nhiêu đơn**. Cần gộp hai lần: đếm đơn của mỗi khách, rồi lấy trung bình các con số đó. Viết thành hai tầng: tầng trong là một truy vấn con đặt trong `FROM` (gọi là bảng dẫn xuất), gộp theo khách; tầng ngoài gộp tiếp kết quả của tầng trong. Bảng dẫn xuất bắt buộc phải có tên (alias).

**Ví dụ nhỏ:** tầng trong.

| customer_id | order_count |
| --- | --- |
| 1 | 3 |
| 2 | 2 |
| 3 | 0 |
| 4 | 1 |

→ tầng ngoài: trung bình (3 + 2 + 0 + 1) / 4 = 1.50.

```sql
SELECT COUNT(*) AS customers, ROUND(AVG(order_count), 2) AS avg_orders, MAX(order_count) AS max_orders
FROM (
  SELECT c.customer_id, COUNT(o.order_id) AS order_count
  FROM customers c
  LEFT JOIN orders o ON o.customer_id = c.customer_id
  GROUP BY c.customer_id
) per_customer;
```

| customers | avg_orders | max_orders |
| --- | --- | --- |
| 4 | 1.50 | 3 |

> [!CAUTION]
> ❌ **Tầng trong chỉ đếm trên bảng `orders`**
>
> Chloe không có đơn nào nên không xuất hiện trong `orders`. Tầng trong chỉ còn 3 khách, và trung bình ra (3 + 2 + 1) / 3 = 2.00 thay vì 1.50.
>
> → **Sửa:** tầng trong đi từ `customers LEFT JOIN orders`, và đếm bằng `COUNT(o.order_id)`. `COUNT(*)` sẽ đếm dòng `NULL` của Chloe thành 1.

## D5. Mỗi dòng ngoài lấy N dòng bên trong (`LATERAL`)

**Ý tưởng:** đề hỏi **2 đơn lớn nhất của mỗi khách**. Ta cần một truy vấn con có `ORDER BY ... LIMIT 2` chạy **riêng cho từng khách**. Truy vấn con trong `FROM` bình thường không được nhắc tới bảng đứng trước nó. Thêm chữ `LATERAL` thì nó được dùng cột của dòng bên trái, và chạy lại cho từng dòng.

**Ví dụ nhỏ:**

| customer | orders (by amount desc) | 2 largest |
| --- | --- | --- |
| Alice (1) | 500, 300, 100 | 500, 300 |
| Ben | 250, 50 | 250, 50 |
| Chloe | (none) | NULL |
| Alice (4) | 120 | 120 |

```sql
SELECT c.customer_id, c.name, t.order_id, t.amount
FROM customers c
LEFT JOIN LATERAL (
  SELECT o.order_id, o.amount
  FROM orders o
  WHERE o.customer_id = c.customer_id
  ORDER BY o.amount DESC, o.order_id
  LIMIT 2
) t ON true
ORDER BY c.customer_id, t.amount DESC;
```

`LEFT JOIN ... ON true` giữ cả khách không có đơn nào (Chloe, với `order_id` và `amount` là `NULL`). Điều kiện nối đã nằm trong truy vấn con, nên `ON` chỉ cần `true`.

> [!CAUTION]
> ❌ **Quên chữ `LATERAL`**
>
> ```text
> ERROR:  invalid reference to FROM-clause entry for table "c"
> HINT:  To reference that table, you must mark this subquery with LATERAL.
> ```
>
> → **Sửa:** `LEFT JOIN LATERAL (...)`.
>
> ---
>
> ❌ **Quên điều kiện `o.customer_id = c.customer_id`**
>
> Truy vấn con không còn phụ thuộc vào khách, nên mọi khách đều nhận 2 đơn lớn nhất của **cả bảng** (đơn 1 và đơn 2 của Alice). Chloe cũng "có" đơn 500 và 300.
>
> → **Sửa:** giữ điều kiện tương quan bên trong truy vấn con.

---

# Phần 2: Biến thể

Mỗi biến thể dưới đây là một bài hay gặp, dùng một trong năm dạng truy vấn con ở Phần 1 theo cách dễ sai. Mỗi mục kể một tình huống, thử cách làm quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

Các biến thể V1, V2 dùng bảng nhân viên:

```text
staff (name, department, salary)   -- mới
```

| name | department | salary |
| --- | --- | --- |
| Alice | Engineering | 100 |
| Ben | Engineering | 300 |
| Chloe | Engineering | 300 |
| David | Engineering | 200 |
| Frank | Sales | 90 |
| Grace | Sales | 80 |
| Henry | Sales | 70 |
| Ivy | Sales | 60 |
| Jack | Sales | NULL |
| Emma | Legal | 150 |

## V1. Khi cần mức lương cao thứ hai, không có thì ra `NULL`

Đề: trả về **đúng một dòng** chứa mức lương cao thứ hai (khác nhau) của một phòng. Nếu phòng không có mức thứ hai, vẫn phải trả về một dòng với giá trị `NULL`.

### Thử cách tự nhiên nhất

Lấy các mức lương khác nhau, xếp giảm dần, bỏ qua mức đầu, lấy mức kế tiếp:

```sql
SELECT DISTINCT salary FROM staff
WHERE department = 'Legal' AND salary IS NOT NULL
ORDER BY salary DESC
LIMIT 1 OFFSET 1;
```

Với Engineering, cách này ra 200, đúng. Với Legal (chỉ có Emma, 150), nó ra **0 dòng**, không phải một dòng `NULL`. `LIMIT ... OFFSET` bỏ qua dòng đầu, rồi không còn dòng nào để lấy.

### Cách sửa: dùng hàm gộp không có `GROUP BY`

Một truy vấn có hàm gộp mà không có `GROUP BY` **luôn ra đúng một dòng**, kể cả khi không có dòng nào thỏa điều kiện: `MAX` của một tập rỗng là `NULL`. Mức lương cao thứ hai là **mức lớn nhất trong những mức nhỏ hơn mức cao nhất**:

```sql
SELECT MAX(salary) AS second_highest
FROM staff
WHERE department = 'Legal'
  AND salary < (SELECT MAX(salary) FROM staff WHERE department = 'Legal');
```

| department | the query returns |
| --- | --- |
| Engineering | one row: 200 (largest below 300) |
| Legal | one row: NULL (nothing below 150) |

Ben và Chloe cùng 300 không gây vấn đề: điều kiện `salary < 300` bỏ cả hai.

> [!TIP]
> **Ghi nhớ:** cần "luôn một dòng, không có thì `NULL`" thì dùng hàm gộp không `GROUP BY` (`MAX`, `MIN`...), không dùng `LIMIT ... OFFSET`.

## V2. Khi tìm mức lương cao thứ N mà không dùng hàm cửa sổ

Đề: với mỗi phòng, trả về **mức lương cao thứ ba** (khác nhau). Phòng có ít hơn 3 mức thì bỏ. Đề cấm hàm cửa sổ, `LIMIT` và `OFFSET`.

**Ý tưởng:** lương L là mức cao thứ ba khi có **đúng 2 mức lương khác nhau** lớn hơn L trong cùng phòng. Đếm số mức lớn hơn bằng một truy vấn con tương quan (D2).

### Thử cách tự nhiên nhất

Đếm số **người** lương cao hơn bằng `COUNT(x.salary)`, rồi giữ người có đúng 2 người cao hơn:

| department | name | salary | people above | distinct levels above |
| --- | --- | --- | --- | --- |
| Engineering | Ben | 300 | 0 | 0 |
| Engineering | Chloe | 300 | 0 | 0 |
| Engineering | David | 200 | **2** | 1 |
| Engineering | Alice | 100 | 3 | **2** |
| Sales | Henry | 70 | 2 | 2 |
| ... | | | | |

Engineering ra David (200), nhưng 200 là mức **thứ hai**: Ben và Chloe cùng 300 chỉ là một mức. Đếm người thì hai người cùng lương bị đếm thành hai.

### Cách sửa: đếm mức lương, không đếm người

`COUNT(DISTINCT x.salary)` đếm số **mức** lương khác nhau lớn hơn:

```sql
SELECT DISTINCT e.department, e.salary AS third_highest
FROM staff e
WHERE e.salary IS NOT NULL
  AND (SELECT COUNT(DISTINCT x.salary) FROM staff x
       WHERE x.department = e.department AND x.salary > e.salary) = 2
ORDER BY e.department;
```

| department | third_highest |
| --- | --- |
| Engineering | 100 |
| Sales | 70 |

Legal chỉ có một mức nên không có dòng nào. `DISTINCT` ở tầng ngoài để phòng hờ: nếu hai người cùng có mức lương thứ ba, nó chỉ hiện một lần.

> [!TIP]
> **Ghi nhớ:** mức cao thứ N (không dùng hàm cửa sổ) là giá trị có đúng N − 1 **giá trị khác nhau** lớn hơn nó: `COUNT(DISTINCT ...)` trong truy vấn con tương quan.

## V3. Khi so với các dòng trước mà không dùng hàm cửa sổ

Điều kiện tương quan ở D2 không nhất thiết là `=`. Dùng `<` hay `<=`, ta có "mọi dòng từ đầu tới dòng này", tức là tổng cộng dồn hay lịch sử, không cần hàm cửa sổ.

### Tổng cộng dồn

```text
transactions (txn_id, amount)   -- mới
```

Tổng cộng dồn tới giao dịch `t` là tổng các giao dịch có `txn_id <= t.txn_id`:

```sql
SELECT t.txn_id, t.amount,
       (SELECT SUM(x.amount) FROM transactions x WHERE x.txn_id <= t.txn_id) AS running_total
FROM transactions t
ORDER BY t.txn_id;
```

| txn_id | amount | running_total |
| --- | --- | --- |
| 1 | 100 | 100 |
| 2 | −30 | 70 |
| 4 | 50 | 120 |
| 7 | 20 | 140 |

Các `txn_id` không liên tục (thiếu 3, 5, 6), nhưng điều kiện `<=` không quan tâm. Nó chỉ cần thứ tự.

### Đơn lớn bất thường so với lịch sử của khách

Đề: một đơn là **bất thường** nếu lớn hơn 2 lần trung bình các đơn **trước đó** của cùng khách. "Trước đó" là ngày nhỏ hơn, hoặc cùng ngày mà `order_id` nhỏ hơn. Đơn đầu tiên không bao giờ bất thường.

```text
purchases (order_id, customer, order_date, amount)   -- mới
```

| order_id | customer | order_date | amount |
| --- | --- | --- | --- |
| 1 | Alice | 2024-01-01 | 100 |
| 2 | Alice | 2024-01-05 | 120 |
| 3 | Alice | 2024-01-05 | 400 |
| 4 | Alice | 2024-01-20 | 200 |
| 5 | Ben | 2024-01-02 | 60 |
| 6 | Ben | 2024-01-03 | 60 |
| 7 | Ben | 2024-01-04 | 130 |

Cách nghĩ nhanh là lấy trung bình các đơn có `order_date <= o.order_date`. Nhưng `<=` gồm cả **chính đơn đang xét**. Với đơn 3 (400), trung bình ra (100 + 120 + 400) / 3 = 206.7, và 400 không lớn hơn 413.3, nên đơn 3 bị bỏ sót.

Định nghĩa "trước đó" của đề là so **cặp** (ngày, id). PostgreSQL so được hai cặp giá trị theo thứ tự từ trái sang: `(x.order_date, x.order_id) < (o.order_date, o.order_id)` nghĩa là ngày nhỏ hơn, hoặc cùng ngày mà id nhỏ hơn:

```sql
SELECT order_id, customer, amount, ROUND(prev_avg, 1) AS prev_avg
FROM (
  SELECT o.order_id, o.customer, o.amount,
         (SELECT AVG(x.amount) FROM purchases x
          WHERE x.customer = o.customer
            AND (x.order_date, x.order_id) < (o.order_date, o.order_id)) AS prev_avg
  FROM purchases o
) t
WHERE amount > 2 * prev_avg
ORDER BY order_id;
```

| order_id | earlier orders | prev_avg | 2 × prev_avg | unusual? |
| --- | --- | --- | --- | --- |
| 2 | 1 | 100.0 | 200 | no |
| 3 | 1, 2 | 110.0 | 220 | **yes** (400) |
| 4 | 1, 2, 3 | 206.7 | 413.3 | no |
| 7 | 5, 6 | 60.0 | 120 | **yes** (130) |
| ... | | | | |

Kết quả: đơn 3 và đơn 7. Đơn đầu tiên của mỗi khách có `prev_avg` là `NULL`, và `amount > NULL` không ra `true`, nên tự bị loại.

> [!TIP]
> **Ghi nhớ:** "các dòng trước dòng này" thì dùng điều kiện tương quan `<` (không phải `<=`). Khi thứ tự gồm nhiều cột, so cả cặp: `(x.d, x.id) < (o.d, o.id)`.

## V4. Khi có nhiều điều kiện trên các dòng khác nhau

Đề: những khách **có mua trong tháng 1/2024 và trong tháng 2/2024, nhưng không mua trong tháng 3/2024**.

```text
visits (customer, order_date)   -- mới
```

| customer | order_date |
| --- | --- |
| Alice | 2024-01-05 |
| Alice | 2024-02-10 |
| Ben | 2024-01-07 |
| Ben | 2024-02-01 |
| Ben | 2024-03-03 |
| Chloe | 2024-02-20 |
| David | 2024-01-01 |
| David | 2024-01-31 |
| David | 2024-02-29 |
| Emma | 2024-01-15 |
| Emma | 2023-02-10 |

### Thử cách tự nhiên nhất

Viết các điều kiện vào cùng một `WHERE`: ngày trong tháng 1 **và** ngày trong tháng 2. Kết quả ra **0 dòng**. Mỗi điều kiện được kiểm tra trên **cùng một dòng**, mà một dòng chỉ có một ngày, không thể vừa thuộc tháng 1 vừa thuộc tháng 2.

### Cách sửa: mỗi điều kiện một `EXISTS`

Mỗi điều kiện hỏi về một **dòng khác** của cùng khách: "có dòng nào trong tháng 1 không", "có dòng nào trong tháng 2 không", "không có dòng nào trong tháng 3". Mỗi câu hỏi là một `EXISTS` hoặc `NOT EXISTS` riêng:

```sql
SELECT DISTINCT v.customer
FROM visits v
WHERE EXISTS (SELECT 1 FROM visits a WHERE a.customer = v.customer
                AND a.order_date >= DATE '2024-01-01' AND a.order_date < DATE '2024-02-01')
  AND EXISTS (SELECT 1 FROM visits b WHERE b.customer = v.customer
                AND b.order_date >= DATE '2024-02-01' AND b.order_date < DATE '2024-03-01')
  AND NOT EXISTS (SELECT 1 FROM visits c WHERE c.customer = v.customer
                    AND c.order_date >= DATE '2024-03-01' AND c.order_date < DATE '2024-04-01')
ORDER BY v.customer;
```

| customer | Jan 2024? | Feb 2024? | Mar 2024? | kept? |
| --- | --- | --- | --- | --- |
| Alice | yes | yes | no | **yes** |
| Ben | yes | yes | yes | no |
| Chloe | no | yes | no | no |
| David | yes | yes (02-29) | no | **yes** |
| Emma | yes | no (2023-02) | no | no |

Viết điều kiện tháng bằng khoảng ngày cụ thể (`>= '2024-02-01' AND < '2024-03-01'`). Nếu chỉ so `EXTRACT(MONTH FROM order_date) = 2`, đơn tháng 2/**2023** của Emma cũng khớp, và Emma bị đưa nhầm vào kết quả.

> [!TIP]
> **Ghi nhớ:** điều kiện trên **các dòng khác nhau** của cùng một đối tượng thì viết mỗi điều kiện thành một `EXISTS` / `NOT EXISTS` riêng.

## V5. Khi so với tất cả giá trị của một tập (`ALL` / `ANY`)

Đề: những sản phẩm không thuộc nhóm `Budget` mà **đắt hơn mọi sản phẩm `Budget`**. Bỏ qua giá `NULL` ở cả hai phía.

```text
products (name, category, price)   -- mới
```

| name | category | price |
| --- | --- | --- |
| B1 | Budget | 15 |
| B2 | Budget | 30 |
| B3 | Budget | NULL |
| P1 | Pro | 40 |
| P2 | Pro | 30 |
| P3 | Pro | NULL |
| L1 | Lux | 60 |

`x > ALL (tập)` nghĩa là x lớn hơn **mọi** phần tử của tập. `x > ANY (tập)` nghĩa là x lớn hơn **ít nhất một** phần tử (`= ANY` giống `IN`).

### Thử cách tự nhiên nhất

```sql
SELECT name, price FROM products
WHERE category <> 'Budget'
  AND price > ALL (SELECT price FROM products WHERE category = 'Budget');
```

Kết quả ra **0 dòng**, dù P1 (40) và L1 (60) rõ ràng đắt hơn 15 và 30. Tập giá Budget là (15, 30, `NULL`). Với L1, `60 > NULL` ra `NULL`, nên `60 > ALL (15, 30, NULL)` không thể chắc chắn là `true`, và cũng ra `NULL`.

### Cách sửa: lọc `NULL` bên trong

```sql
SELECT name, price
FROM products
WHERE category <> 'Budget'
  AND price IS NOT NULL
  AND price > ALL (SELECT price FROM products WHERE category = 'Budget' AND price IS NOT NULL)
ORDER BY price DESC, name;
```

| name | price |
| --- | --- |
| L1 | 60 |
| P1 | 40 |

P2 (30) bằng chứ không lớn hơn B2 (30), nên không được giữ.

Một điểm khác cần biết: với **tập rỗng**, `x > ALL (rỗng)` là `true`. Nếu không có sản phẩm Budget nào, mọi sản phẩm có giá đều được giữ, và đề thường muốn đúng như vậy. Viết `price > (SELECT MAX(price) ...)` thì khác: `MAX` của tập rỗng là `NULL`, và kết quả ra 0 dòng.

> [!TIP]
> **Ghi nhớ:** `> ALL` trên một tập có `NULL` không bao giờ ra `true`. Luôn lọc `IS NOT NULL` bên trong truy vấn con.

## V6. Khi so mỗi nhóm với trung bình của các nhóm

Đề: những nhóm hàng có **tổng doanh thu cao hơn trung bình tổng doanh thu của các nhóm**.

```text
sales (category, amount)   -- mới
```

| category | amount |
| --- | --- |
| Tea | 120 |
| Tea | 80 |
| Coffee | 300 |
| Cocoa | 40 |
| Juice | 160 |

Tổng mỗi nhóm: Tea 200, Coffee 300, Cocoa 40, Juice 160. Trung bình của **4 nhóm** là 700 / 4 = 175.

### Thử cách tự nhiên nhất

```sql
HAVING SUM(amount) > (SELECT AVG(amount) FROM sales)
```

Kết quả ra Coffee, Tea, **Juice**. `AVG(amount)` là trung bình của **5 dòng**, tức 700 / 5 = 140, không phải trung bình của 4 nhóm. Juice (160) lớn hơn 140 nhưng nhỏ hơn 175.

### Cách sửa: tính tổng mỗi nhóm trước, rồi mới lấy trung bình

Đây là "gộp của gộp" (D4): một bảng dẫn xuất tính tổng mỗi nhóm, rồi lấy `AVG` của các tổng đó:

```sql
SELECT category, SUM(amount) AS revenue
FROM sales
GROUP BY category
HAVING SUM(amount) > (
  SELECT AVG(total) FROM (SELECT SUM(amount) AS total FROM sales GROUP BY category) per_category
)
ORDER BY revenue DESC, category;
```

| category | revenue |
| --- | --- |
| Coffee | 300 |
| Tea | 200 |

> [!TIP]
> **Ghi nhớ:** "trung bình của các nhóm" khác "trung bình của các dòng". Tính tổng mỗi nhóm trong một bảng dẫn xuất, rồi mới `AVG`.
