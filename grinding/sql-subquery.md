# Subquery

> Bài liên quan: `subquery/01`–`12`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** làm sao lọc hoặc tính một dòng dựa trên **kết quả của một truy vấn khác**? Ví dụ: đơn lớn hơn trung bình, khách từng mua đồ điện tử, khách chưa mua gì, trung bình số đơn mỗi khách.

**Vì sao không viết thẳng được:**
- `WHERE amount > AVG(amount)` báo lỗi `aggregate functions are not allowed in WHERE`, vì `WHERE` chạy trước khi gộp.
- `AVG(COUNT(*))` báo lỗi `aggregate function calls cannot be nested`.

Cả hai trường hợp đều cần tính một thứ **trước**, rồi mới dùng kết quả đó.

Năm bước, sắp theo thứ tự từ đơn giản đến phức tạp. Mỗi bước trả lời một kiểu câu hỏi:

1. So với **một giá trị** của cả bảng
2. So với **một giá trị riêng** cho từng dòng
3. **Có hoặc không có** dòng khớp
4. Tổng hợp của tổng hợp
5. Mỗi dòng ngoài lấy N dòng bên trong

Ví dụ chạy xuyên suốt:

`customers`: An (1), Binh (2), Chi (3). Chi chưa mua gì.

`orders` (đơn 6 không gắn với khách nào):

| order_id | customer_id | category | amount |
| --- | --- | --- | --- |
| 1 | 1 | Electronics | 500 |
| 2 | 1 | Electronics | 300 |
| 3 | 1 | Books | 100 |
| 4 | 2 | Books | 50 |
| 5 | 2 | Electronics | 250 |
| 6 | NULL | Books | 80 |

---

## B1. So với một giá trị của cả bảng (scalar subquery)

- **Vấn đề:** lấy các đơn lớn hơn giá trị trung bình của mọi đơn.
- **Tại sao:**
  - Subquery trả về **đúng một dòng, một cột** thì dùng được như một hằng số.
  - Subquery này không nhắc tới bảng ngoài, nên chỉ cần tính một lần.

```sql
SELECT order_id, amount
FROM orders
WHERE amount > (SELECT AVG(amount) FROM orders);
```

| order_id | amount | avg_all |
| --- | --- | --- |
| 1 | 500 | 213.3 |
| 2 | 300 | 213.3 |
| 5 | 250 | 213.3 |

- Subquery không trả về dòng nào thì kết quả là `NULL`.
- Subquery trả về hơn một dòng thì báo lỗi `more than one row returned by a subquery used as an expression`.

**Khi đề yêu cầu luôn trả về đúng một dòng, kể cả khi không có đáp án** (ví dụ "lương cao thứ 2, không có thì ra `NULL`"):
- Truy vấn có hàm tổng hợp mà không có `GROUP BY` thì luôn ra đúng một dòng. `MAX` của một tập rỗng là `NULL`.
- Ngược lại, `ORDER BY ... LIMIT 1 OFFSET 1` trả về **0 dòng** khi chỉ có một mức lương, chứ không phải một dòng `NULL`.

```sql
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);
```

## B2. So với một giá trị riêng cho từng dòng (subquery tương quan)

- **Vấn đề:** lấy các đơn lớn hơn trung bình **của chính khách đó**.
- **Tại sao:**
  - Subquery nhắc tới dòng của truy vấn ngoài (`x.customer_id = o.customer_id`).
  - Về mặt logic, subquery chạy lại cho mỗi dòng ngoài.
  - Khi không có dòng nào khớp, `SUM` và `AVG` ra `NULL`, không ra 0. Muốn ra 0 thì dùng `COALESCE`.

```sql
SELECT o.order_id, o.customer_id, o.amount
FROM orders o
WHERE o.amount > (SELECT AVG(x.amount) FROM orders x WHERE x.customer_id = o.customer_id);
```

| order_id | customer_id | amount | cust_avg |
| --- | --- | --- | --- |
| 1 | 1 | 500 | 300.0 |
| 5 | 2 | 250 | 150.0 |

Tổng tiền mỗi khách, viết bằng subquery trong `SELECT`:

| name | SUM thô | COALESCE(..., 0) |
| --- | --- | --- |
| An | 900 | 900 |
| Binh | 300 | 300 |
| Chi | NULL | 0 |

**Điều kiện tương quan không nhất thiết là `=`:**
- `x.id <= t.id` nghĩa là "mọi dòng từ đầu tới dòng này", tức là tổng dồn mà không cần window.
- `(x.d, x.id) < (o.d, o.id)` nghĩa là "các dòng đứng trước" theo ngày, khi trùng ngày thì theo id.

Window function thường làm việc này nhanh hơn, vì chỉ cần đọc bảng một lần.

**Khi tìm giá trị lớn thứ N mà không được dùng window:**
- Lương L là lương cao thứ 3 trong phòng khi có **đúng 2 mức lương khác nhau** lớn hơn L trong cùng phòng.
- Đếm bằng `COUNT(DISTINCT ...)`, vì hai người cùng lương 200 chỉ là một mức.
- Hai người cùng có lương thứ 3 đều thỏa điều kiện, nên tầng ngoài phải `SELECT DISTINCT`.

```sql
SELECT DISTINCT e.department, e.salary AS third_highest
FROM employees e
WHERE e.salary IS NOT NULL
  AND (SELECT COUNT(DISTINCT x.salary) FROM employees x
       WHERE x.department = e.department AND x.salary > e.salary) = 2;
```

| department | salary | số mức lương cao hơn |
| --- | --- | --- |
| HR | 60 | 0 |
| HR | 50 | 1 |
| IT | 400 | 0 |
| IT | 300 | 1 |
| IT | 200 | **2** |
| IT | 200 | **2** |
| IT | 100 | 3 |
| Ops | 30 | 0 |
| Ops | 20 | 1 |
| Ops | 10 | **2** |

## B3. Có hoặc không có dòng khớp (`EXISTS` / `NOT EXISTS`)

- **Vấn đề:** liệt kê khách từng mua đồ điện tử. Kết quả phải là **mỗi khách một dòng**, dù họ mua bao nhiêu lần.
- **Tại sao:**
  - `JOIN` làm khách xuất hiện một lần cho **mỗi** đơn khớp, nên An ra hai lần.
  - Thêm `DISTINCT name` để chữa thì lại gộp nhầm hai khách khác nhau có cùng tên.
  - `EXISTS` chỉ hỏi "có ít nhất một dòng khớp hay không", nên mỗi khách ra đúng một dòng.

`JOIN`:

| name |
| --- |
| An |
| An |
| Binh |

`EXISTS`:

```sql
SELECT c.name FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.category = 'Electronics');
```

| name |
| --- |
| An |
| Binh |

**Khi tìm khách không có đơn nào:** dùng `NOT EXISTS`, đừng dùng `NOT IN`.
- `orders.customer_id` có một giá trị `NULL` (đơn 6).
- Khi đó `3 NOT IN (1, 1, 1, 2, 2, NULL)` ra `NULL` thay vì `true`, nên `NOT IN` trả về **0 dòng**.
- `NOT EXISTS` vẫn ra đúng Chi.

```sql
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
```

| name |
| --- |
| Chi |

**Khi đề yêu cầu nhiều điều kiện, mỗi điều kiện trên một dòng khác nhau** (ví dụ mua tháng 1 **và** tháng 2 **nhưng không** mua tháng 3): viết mỗi điều kiện thành một `EXISTS` hoặc `NOT EXISTS` riêng. Một dòng đơn hàng không thể vừa thuộc tháng 1 vừa thuộc tháng 2.

**`ANY` / `ALL`:**
- `x > ALL (tập)` nghĩa là x lớn hơn mọi phần tử. `x = ANY (tập)` giống `IN`.
- Với tập rỗng, `x > ALL (rỗng)` là `true`.
- Tập có `NULL` thì kết quả là `NULL`. Phải lọc `IS NOT NULL` bên trong subquery.

## B4. Tổng hợp của tổng hợp (bảng dẫn xuất)

- **Vấn đề:** cần biết trung bình mỗi khách có bao nhiêu đơn.
- **Tại sao:** tách làm hai tầng. Tầng trong gộp theo khách. Tầng ngoài gộp tiếp kết quả của tầng trong. Subquery trong `FROM` bắt buộc phải có alias.

Tầng trong phải đi từ `customers LEFT JOIN orders`, nếu không khách 0 đơn sẽ biến mất và trung bình bị đội lên:
- Chỉ đếm trên `orders`: trung bình là 2.50.
- Tính cả Chi: trung bình là 1.67.

Sau `LEFT JOIN`, phải đếm bằng `COUNT(o.order_id)`. `COUNT(*)` sẽ đếm dòng `NULL` của Chi thành 1.

```sql
SELECT COUNT(*) AS customers, ROUND(AVG(order_count), 2) AS avg_orders, MAX(order_count) AS max_orders
FROM (
  SELECT c.customer_id, COUNT(o.order_id) AS order_count
  FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
  GROUP BY c.customer_id
) per_customer;
```

Tầng trong:

| customer_id | order_count |
| --- | --- |
| 1 | 3 |
| 2 | 2 |
| 3 | 0 |

Tầng ngoài:

| customers | avg_orders | max_orders |
| --- | --- | --- |
| 3 | 1.67 | 3 |

**Khi so mỗi nhóm với trung bình của các nhóm:** đặt bảng dẫn xuất vào `HAVING SUM(x) > (SELECT AVG(t) FROM (SELECT SUM(x) AS t ... GROUP BY ...) s)`. Nếu viết `(SELECT AVG(x) FROM ...)` thì đang so với trung bình của mỗi **dòng**, không phải của mỗi **nhóm**.

## B5. Mỗi dòng ngoài lấy N dòng bên trong (`LATERAL`)

- **Vấn đề:** với mỗi khách, lấy 2 đơn lớn nhất.
- **Tại sao:**
  - Subquery trong `FROM` bình thường không nhìn thấy bảng đứng trước nó.
  - Thêm `LATERAL` thì subquery tham chiếu được dòng ngoài và chạy lại cho mỗi dòng. Nhờ vậy `ORDER BY ... LIMIT 2` áp dụng **riêng cho từng khách**.
  - Dùng `LEFT JOIN LATERAL ... ON true` để giữ khách không có đơn (Chi).

```sql
SELECT c.name, t.order_id, t.amount
FROM customers c
LEFT JOIN LATERAL (
  SELECT o.order_id, o.amount FROM orders o
  WHERE o.customer_id = c.customer_id
  ORDER BY o.amount DESC, o.order_id LIMIT 2
) t ON true;
```

| name | order_id | amount |
| --- | --- | --- |
| An | 1 | 500 |
| An | 2 | 300 |
| Binh | 5 | 250 |
| Binh | 4 | 50 |
| Chi | NULL | NULL |

Nếu quên điều kiện `o.customer_id = c.customer_id`, mọi khách đều nhận 2 đơn lớn nhất của **cả bảng**.

---

## Tổng kết: query đầy đủ

Một câu dùng cả 5 loại subquery trên cùng dữ liệu:

```sql
SELECT c.name,
       COALESCE((SELECT SUM(o.amount) FROM orders o
                 WHERE o.customer_id = c.customer_id), 0)             AS total,          -- B2
       (SELECT SUM(o.amount) FROM orders o WHERE o.customer_id = c.customer_id)
         > (SELECT AVG(t.total) FROM (SELECT SUM(amount) AS total FROM orders
                                      WHERE customer_id IS NOT NULL
                                      GROUP BY customer_id) t)        AS above_avg_customer,  -- B1 + B4
       EXISTS (SELECT 1 FROM orders o
               WHERE o.customer_id = c.customer_id
                 AND o.category = 'Electronics')                      AS bought_electronics,  -- B3
       top.order_id AS biggest_order, top.amount AS biggest_amount                         -- B5
FROM customers c
LEFT JOIN LATERAL (
  SELECT o.order_id, o.amount FROM orders o
  WHERE o.customer_id = c.customer_id
  ORDER BY o.amount DESC, o.order_id LIMIT 1
) top ON true
ORDER BY c.customer_id;
```

| name | total | above_avg_customer | bought_electronics | biggest_order | biggest_amount |
| --- | --- | --- | --- | --- | --- |
| An | 900 | True | True | 1 | 500 |
| Binh | 300 | False | True | 5 | 250 |
| Chi | 0 | NULL | False | NULL | NULL |
