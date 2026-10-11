# Các lỗi thường gặp khi viết SQL

> Tổng hợp các lỗi logic/hiệu năng phổ biến, nhóm theo **nguyên nhân gốc**. Mỗi lỗi trình bày như một bài test SQL:
> **Nguyên nhân → Input → Task → Expected Output → Wrong Query → Output → Correct Query (✔ khớp Expected Output).**
>
> Quy ước: cú pháp theo SQL chuẩn / PostgreSQL, ghi chú riêng khi DBMS khác nhau. Mọi `Output` được suy ra bằng tay từ dữ liệu mẫu, chưa chạy trên DBMS thật. Số liệu thời gian ở mục hiệu năng chỉ mang tính minh họa.

---

## 0. Nền tảng: hai mô hình cần nắm trước

### 0.1 Thứ tự thực thi logic (khác thứ tự viết)

```
FROM / JOIN → WHERE → GROUP BY → HAVING → SELECT (+ window function) → DISTINCT → ORDER BY → LIMIT
```

Hệ quả: `WHERE` không thấy kết quả tổng hợp; window function chỉ thấy dữ liệu *sau* `GROUP BY`; `WHERE` sau `LEFT JOIN` lọc trên kết quả đã nối.

### 0.2 Logic ba giá trị (Three-Valued Logic)

Mọi phép so sánh với `NULL` cho ra `UNKNOWN`. `WHERE` và `ON` chỉ giữ dòng có kết quả `TRUE`.

| Biểu thức | Kết quả |
| --- | --- |
| `NULL = NULL`, `NULL <> 1` | `UNKNOWN` |
| `NOT UNKNOWN` | `UNKNOWN` |
| `TRUE AND UNKNOWN` | `UNKNOWN` |
| `TRUE OR UNKNOWN` | `TRUE` |
| `FALSE OR UNKNOWN` | `UNKNOWN` |

### 0.3 Bản đồ lỗi

| Nhóm | Lỗi | Triệu chứng chính |
| --- | --- | --- |
| **A. Kiểu dữ liệu & NULL** | A1–A7 | Sai/thiếu dòng một cách "im lặng", chia sai, `NULL` lan truyền |
| **B. Điều kiện lọc** | B1–B3 | Sai kết quả hoặc mất index |
| **C. JOIN** | C1–C5 | Nhân bản dòng, mất dòng, `DISTINCT` che lỗi |
| **D. Gom nhóm** | D1–D2 | Lỗi cú pháp hoặc chậm |
| **E. Subquery, tập hợp & xếp hạng** | E1–E7 | Rỗng bất ngờ, so sánh sai phạm vi, top-N không ổn định |
| **F. Window function** | F1–F3 | Lỗi lớp dữ liệu, tổng dồn ngoài ý muốn, frame sai |
| **G. Tư duy tập hợp** | G1–G5 | Ép điều kiện "vừa A vừa B" vào một dòng, `NULL` và trùng lặp trong `INTERSECT`/`EXCEPT`/`UNION` |

---

## A. Kiểu dữ liệu và NULL

### A1. So sánh khác kiểu dữ liệu (Implicit Conversion)

**Nguyên nhân.** So sánh `TEXT` với số làm DB so theo thứ tự từ điển (từng ký tự). Với cột có index, ép kiểu *cột* còn làm mất index (ví dụ `WHERE varchar_col = 123`).

**Input** — Table `Invoices` (`amount` kiểu `TEXT`)

| invoice_id | amount |
| --- | --- |
| INV01 | '100' |
| INV02 | '20' |
| INV03 | '9' |

**Task:** Tìm các hóa đơn có `amount` > 50.

**Expected Output**

| invoice_id | amount |
| --- | --- |
| INV01 | 100 |

**Wrong Query**

```sql
SELECT * FROM Invoices WHERE amount > '50';
```

**Output**

| invoice_id | amount |
| --- | --- |
| INV03 | 9 |

`'9' > '5'` vì ký tự đầu `'9'` đứng sau `'5'`; `'100'` và `'20'` bắt đầu bằng `'1'`, `'2'` < `'5'` nên bị loại.

**Correct Query** — chuẩn hóa schema: đổi `amount` sang `INT`/`DECIMAL`

```sql
SELECT * FROM Invoices WHERE amount > 50;   -- amount là INT
```

 Nếu chưa đổi được schema, ép kiểu ở phía *giá trị*, hoặc `CAST(amount AS INT) > 50` (chấp nhận mất index).

---

### A2. Dùng `= NULL` / `<> NULL`

**Nguyên nhân.** Kết quả luôn là `UNKNOWN` (xem 0.2).

**Input** — Table `Employees`

| name | bonus |
| --- | --- |
| Michael | 500 |
| Danny | NULL |

**Task:** Tìm nhân viên chưa có thưởng.

**Expected Output**

| name | bonus |
| --- | --- |
| Danny | NULL |

**Wrong Query**

```sql
SELECT * FROM Employees WHERE bonus = NULL;
```

**Output**

```
Empty set (0 rows)
```

**Correct Query**

```sql
SELECT * FROM Employees WHERE bonus IS NULL;
```

 Khi cần coi hai `NULL` là bằng nhau, dùng `IS NOT DISTINCT FROM` (PostgreSQL, SQL Server 2022+).

---

### A3. Hàm tổng hợp bỏ qua NULL

**Nguyên nhân.** `COUNT(cột)`, `SUM`, `AVG`, `MIN`, `MAX` bỏ qua `NULL`. Chỉ `COUNT(*)` đếm mọi dòng.

**Input** — Table `Scores`

| student | score |
| --- | --- |
| Alice | 10 |
| Bob | NULL |

(Bob chưa nộp bài.)

**Task:** Tính điểm trung bình, coi bài chưa nộp là 0 điểm.

**Expected Output**

| avg_score |
| --- |
| 5.0 |

**Wrong Query**

```sql
SELECT AVG(score) AS avg_score FROM Scores;
```

**Output**

| avg_score |
| --- |
| 10.0 |

`AVG` chia cho 1 người có điểm (10 / 1), bỏ qua `NULL`.

**Correct Query**

```sql
SELECT AVG(COALESCE(score, 0)) AS avg_score FROM Scores;
```

 Tham chiếu: `COUNT(*) = 2`, `COUNT(score) = 1`. Chọn cách xử lý `NULL` theo **nghiệp vụ** và ghi rõ trong code.

---

### A4. Phủ định với NULL (`<>`, `NOT`)

**Nguyên nhân.** `NULL <> 'London'` là `UNKNOWN` nên dòng bị loại. (Với `NOT IN`, xem E1b.)

**Input** — Table `Customers`

| name | city |
| --- | --- |
| Alice | London |
| Bob | Paris |
| Carol | NULL |

**Task:** Tìm khách hàng không ở London (gồm cả người chưa cập nhật thành phố).

**Expected Output**

| name | city |
| --- | --- |
| Bob | Paris |
| Carol | NULL |

**Wrong Query**

```sql
SELECT * FROM Customers WHERE city <> 'London';   -- tương đương NOT (city = 'London')
```

**Output**

| name | city |
| --- | --- |
| Bob | Paris |

**Correct Query**

```sql
SELECT * FROM Customers WHERE city <> 'London' OR city IS NULL;
```



> Mỗi khi viết điều kiện phủ định, hỏi: *"`NULL` có nên nằm trong kết quả không?"*

---

### A5. Chia số nguyên và chia cho 0

**Nguyên nhân.** SQL Server, PostgreSQL, SQLite chia *số nguyên cho số nguyên* ra số nguyên (cắt phần thập phân). MySQL và Oracle trả số thập phân, nhưng không nên dựa vào điều đó. Mẫu số bằng 0 làm query lỗi (SQL Server, PostgreSQL) hoặc trả `NULL` (MySQL, SQLite).

**Input** — Table `Courses`

| course_name | passed | enrolled |
| --- | --- | --- |
| Python | 1 | 4 |
| SQL | 0 | 0 |

**Task:** Tính tỷ lệ đạt (%) của từng khóa học; khóa chưa có ai đăng ký thì `NULL`.

**Expected Output**

| course_name | pass_rate |
| --- | --- |
| Python | 25.00 |
| SQL | NULL |

**Wrong Query**

```sql
SELECT course_name, passed / enrolled * 100 AS pass_rate FROM Courses;
```

**Output**

```
ERROR: division by zero      -- SQL Server / PostgreSQL (do dòng SQL)
```

Nếu loại dòng `SQL` khỏi dữ liệu, `Python` ra `0` (vì `1 / 4 = 0` trong chia số nguyên).

**Correct Query** — nhân `100.0` ở đầu biểu thức để ép kiểu, bọc mẫu số bằng `NULLIF`

```sql
SELECT course_name, 100.0 * passed / NULLIF(enrolled, 0) AS pass_rate FROM Courses;
```



---

### A6. Hàm tổng hợp trên tập rỗng

**Nguyên nhân.** Trên tập 0 dòng, `SUM`/`AVG`/`MIN`/`MAX` trả `NULL` còn `COUNT` trả `0`. Có `GROUP BY` thì tập rỗng cho **0 dòng kết quả**; không có `GROUP BY` thì luôn trả đúng **1 dòng**.

**Input** — Table `Orders`

| customer | amount |
| --- | --- |
| Alice | 100 |

**Task:** Tổng tiền và số đơn của khách `Bob` (chưa có đơn nào); tổng tiền hiển thị `0`.

**Expected Output**

| total | order_count |
| --- | --- |
| 0 | 0 |

**Wrong Query**

```sql
SELECT SUM(amount) AS total, COUNT(*) AS order_count FROM Orders WHERE customer = 'Bob';
```

**Output**

| total | order_count |
| --- | --- |
| NULL | 0 |

**Correct Query**

```sql
SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS order_count
FROM Orders WHERE customer = 'Bob';
```



---

### A7. Nối chuỗi với NULL, khoảng trắng và collation

**Nguyên nhân.** Trong PostgreSQL, SQLite (toán tử `||`), MySQL (`CONCAT`) và SQL Server (toán tử `+`), nối chuỗi với `NULL` ra `NULL`. Oracle coi chuỗi rỗng là `NULL` và bỏ qua `NULL` khi nối bằng `||`, nên cho kết quả khác (dư khoảng trắng). Trên MySQL mặc định `||` là toán tử `OR`, không phải nối chuỗi.

**Input** — Table `Employees`

| first_name | middle_name | last_name |
| --- | --- | --- |
| John | Edward | Smith |
| Mary | NULL | Jones |

**Task:** Hiển thị họ tên đầy đủ.

**Expected Output**

| full_name |
| --- |
| John Edward Smith |
| Mary Jones |

**Wrong Query**

```sql
SELECT first_name || ' ' || middle_name || ' ' || last_name AS full_name FROM Employees;
```

**Output**

| full_name |
| --- |
| John Edward Smith |
| NULL |

**Correct Query** — `CONCAT_WS` bỏ qua `NULL`, không để lại khoảng trắng thừa

```sql
SELECT CONCAT_WS(' ', first_name, middle_name, last_name) AS full_name FROM Employees;
```

 (`CONCAT_WS` có trên MySQL, PostgreSQL, SQL Server 2017+. Nếu không có: `COALESCE(middle_name || ' ', '')`.)

**Các bẫy chuỗi đi kèm**

| Bẫy | Hệ quả | Cách xử lý |
| --- | --- | --- |
| Kiểu `CHAR(n)` đệm khoảng trắng | `LENGTH` khác, so sánh với client có thể lệch | Dùng `VARCHAR`, hoặc `TRIM` / `RTRIM` |
| Collation phân biệt hoa/thường | `'an' = 'An'` đúng trên MySQL / SQL Server (mặc định), sai trên PostgreSQL | Chuẩn hóa `LOWER()` ở cả hai vế hoặc khai báo collation tường minh (lưu ý B3: bọc hàm làm mất index) |
| Khoảng trắng đầu/cuối trong dữ liệu import | JOIN không khớp dù nhìn giống nhau | Làm sạch (`TRIM`) ở bước ingest |

---

## B. Điều kiện lọc

### B1. `AND`/`OR` thiếu ngoặc

**Nguyên nhân.** `AND` được ưu tiên hơn `OR` (như `*` hơn `+`).

**Input** — Table `Employees`

| name | department | salary |
| --- | --- | --- |
| Anna | IT | 15000 |
| Ben | HR | 25000 |
| Carl | IT | 8000 |

**Task:** Tìm nhân viên thuộc phòng IT hoặc HR **và** có lương > 20000.

**Expected Output**

| name | department | salary |
| --- | --- | --- |
| Ben | HR | 25000 |

**Wrong Query**

```sql
-- Được hiểu là: department = 'IT' OR (department = 'HR' AND salary > 20000)
SELECT * FROM Employees
WHERE department = 'IT' OR department = 'HR' AND salary > 20000;
```

**Output**

| name | department | salary |
| --- | --- | --- |
| Anna | IT | 15000 |
| Ben | HR | 25000 |
| Carl | IT | 8000 |

**Correct Query**

```sql
SELECT * FROM Employees
WHERE (department = 'IT' OR department = 'HR') AND salary > 20000;
```

 Luôn thêm ngoặc khi trộn `AND`/`OR`.

---

### B2. Sai biên khoảng lọc (`BETWEEN` với cột có giờ)

**Nguyên nhân.** `BETWEEN a AND b` đóng cả hai đầu; `'2024-01-31'` được hiểu là `2024-01-31 00:00:00`, nên mọi bản ghi sau 00:00 ngày 31 bị sót.

**Input** — Table `Orders`

| order_id | created_at |
| --- | --- |
| O1 | 2024-01-31 00:00:00 |
| O2 | 2024-01-31 14:30:00 |
| O3 | 2024-02-01 09:00:00 |

**Task:** Lấy toàn bộ đơn hàng tháng 01/2024.

**Expected Output**

| order_id | created_at |
| --- | --- |
| O1 | 2024-01-31 00:00:00 |
| O2 | 2024-01-31 14:30:00 |

**Wrong Query**

```sql
SELECT * FROM Orders WHERE created_at BETWEEN '2024-01-01' AND '2024-01-31';
```

**Output**

| order_id | created_at |
| --- | --- |
| O1 | 2024-01-31 00:00:00 |

O2 bị sót vì `14:30:00` > `00:00:00`.

**Correct Query** — khoảng nửa mở `[from, to)`

```sql
SELECT * FROM Orders WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01';
```



---

### B3. Hàm bọc cột làm mất index (Non-sargable)

**Nguyên nhân.** `f(cột) = giá trị` buộc DB tính `f` cho từng dòng (Table Scan) thay vì tra index (Index Seek).

**Input** — Table `Orders` (bản thật: 1.000.000 dòng, cột `order_date` đã có index; sample rút gọn)

| order_id | order_date |
| --- | --- |
| 1 | 2023-12-31 |
| 2 | 2024-03-15 |
| 3 | 2024-12-31 |
| 4 | 2025-01-01 |

**Task:** Lấy các đơn hàng năm 2024.

**Expected Output**

| order_id | order_date |
| --- | --- |
| 2 | 2024-03-15 |
| 3 | 2024-12-31 |

**Wrong Query**

```sql
SELECT * FROM Orders WHERE EXTRACT(YEAR FROM order_date) = 2024;   -- SQL Server: YEAR(order_date)
```

**Output** — dữ liệu đúng, nhưng:

| | Wrong Query | Correct Query |
| --- | --- | --- |
| Dữ liệu trả về | order_id 2, 3 | order_id 2, 3 |
| Cách truy cập | Table Scan (tính hàm cho mọi dòng) | Index Seek |
| Số dòng phải duyệt (bản 1M dòng) | 1.000.000 | chỉ các dòng trong khoảng |
| Thời gian (minh họa) | ~3–5 giây | vài ms |

**Correct Query** — cột để trần, hằng số ở phía còn lại

```sql
SELECT * FROM Orders WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';
```



**Các dạng non-sargable tương tự**

| Dạng | Cách sửa |
| --- | --- |
| `WHERE col + 1 = 10` | `WHERE col = 9` |
| `WHERE LOWER(col) = 'a'` | Dùng collation không phân biệt hoa/thường, hoặc functional index |
| `WHERE col LIKE '%abc'` | Tránh wildcard đứng đầu, hoặc dùng full-text/trigram index |
| `WHERE COALESCE(col, 0) = 5` | Viết lại `col = 5` (kèm `OR col IS NULL` nếu cần) |

---

## C. JOIN

### C1. Thiếu hoặc sai điều kiện `ON` (Tích Descartes)

**Nguyên nhân.** Không có điều kiện nối → ghép mọi cặp dòng, số dòng = N × M.

**Input**

Table `Customers` (N = 3)

| customer_id | name |
| --- | --- |
| C01 | Alice |
| C02 | Bob |
| C03 | Carol |

Table `Orders` (M = 3)

| order_id | customer_id | total |
| --- | --- | --- |
| O101 | C01 | 150 |
| O102 | C02 | 300 |
| O103 | C01 | 500 |

**Task:** Ghép mỗi đơn hàng với khách hàng đã đặt.

**Expected Output** (3 dòng)

| customer_id | name | order_id | total |
| --- | --- | --- | --- |
| C01 | Alice | O101 | 150 |
| C01 | Alice | O103 | 500 |
| C02 | Bob | O102 | 300 |

**Wrong Query**

```sql
SELECT * FROM Customers JOIN Orders;   -- quên ON (một số DB như MySQL cho phép cú pháp này)
```

**Output** — 9 dòng (3 × 3), trong đó 6 dòng ghép sai

| Customers.customer_id | name | order_id | Orders.customer_id | Hợp lệ? |
| --- | --- | --- | --- | --- |
| C01 | Alice | O101 | C01 | ✔ |
| C01 | Alice | O102 | C02 | ✘ |
| C01 | Alice | O103 | C01 | ✔ |
| C02 | Bob | O101 | C01 | ✘ |
| C02 | Bob | O102 | C02 | ✔ |
| C02 | Bob | O103 | C01 | ✘ |
| C03 | Carol | O101 | C01 | ✘ |
| C03 | Carol | O102 | C02 | ✘ |
| C03 | Carol | O103 | C01 | ✘ |

**Correct Query**

```sql
SELECT c.customer_id, c.name, o.order_id, o.total
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id;
```

 Nếu thật sự cần tích Descartes, viết tường minh `CROSS JOIN`.

---

### C2. Lọc bảng bên phải của `LEFT JOIN` trong `WHERE`

**Nguyên nhân.** `WHERE` chạy *sau* JOIN; dòng trái không khớp mang `NULL` ở cột phải, `NULL = 'New'` là `UNKNOWN` nên bị loại → `LEFT JOIN` thành `INNER JOIN`.

**Input**

Table `Employees`

| id | name |
| --- | --- |
| 1 | Alice |
| 2 | Bob |

Table `Equipment`

| id | employee_id | equipment_name | status |
| --- | --- | --- | --- |
| 101 | 1 | Projector | New |

**Task:** Liệt kê **mọi** nhân viên cùng thiết bị có `status = 'New'` (không có thì `NULL`).

**Expected Output**

| name | equipment_name |
| --- | --- |
| Alice | Projector |
| Bob | NULL |

**Wrong Query**

```sql
SELECT e.name, q.equipment_name
FROM Employees e
LEFT JOIN Equipment q ON e.id = q.employee_id
WHERE q.status = 'New';
```

**Output**

| name | equipment_name |
| --- | --- |
| Alice | Projector |

Bob mất vì `q.status` của Bob là `NULL`, `NULL = 'New'` là `UNKNOWN` nên bị `WHERE` loại.

**Correct Query** — đưa điều kiện vào `ON`

```sql
SELECT e.name, q.equipment_name
FROM Employees e
LEFT JOIN Equipment q ON e.id = q.employee_id AND q.status = 'New';
```



| Vị trí điều kiện | Ý nghĩa với `LEFT JOIN` |
| --- | --- |
| `ON` | Quyết định *dòng nào của bảng phải được ghép*; dòng trái luôn được giữ |
| `WHERE` | Lọc *toàn bộ kết quả sau khi nối*; lọc cột bảng phải sẽ xóa các dòng `NULL` |

Ngoại lệ có chủ đích: `WHERE q.id IS NULL` (anti-join, xem E1).

---

### C3. Fan-out khi JOIN nhiều bảng quan hệ 1-N

**Nguyên nhân.** Nối bảng cha với hai bảng con độc lập: sách có *m* lượt mượn và *n* lượt đặt sinh *m × n* dòng trước khi gom → `COUNT`/`SUM` bị phình. `COUNT(DISTINCT)` chữa được `COUNT` nhưng **không** chữa `SUM`, và bảng trung gian vẫn phình to.

**Input**

Table `Books`

| book_id |
| --- |
| 1 |
| 2 |

Table `Loans`

| loan_id | book_id |
| --- | --- |
| 1 | 1 |
| 2 | 1 |
| 3 | 1 |
| 4 | 2 |

Table `Reservations`

| reservation_id | book_id | status |
| --- | --- | --- |
| 1 | 1 | ready_pickup |
| 2 | 1 | ready_pickup |
| 3 | 2 | picked_up |

**Task:** Với mỗi sách, đếm số lượt mượn (`borrow_count`) và số lượt đặt trước đang chờ lấy (`pending_reservation`, `status = 'ready_pickup'`).

**Expected Output**

| book_id | borrow_count | pending_reservation |
| --- | --- | --- |
| 1 | 3 | 2 |
| 2 | 1 | 0 |

**Wrong Query**

```sql
SELECT b.book_id,
       COUNT(l.loan_id)        AS borrow_count,
       COUNT(r.reservation_id) AS pending_reservation
FROM Books b
LEFT JOIN Loans        l ON l.book_id = b.book_id
LEFT JOIN Reservations r ON r.book_id = b.book_id AND r.status = 'ready_pickup'
GROUP BY b.book_id;
```

**Output** — sách 1 sinh 3 × 2 = 6 dòng trước `GROUP BY`

| book_id | borrow_count | pending_reservation |
| --- | --- | --- |
| 1 | 6 | 6 |
| 2 | 1 | 0 |

**Correct Query** — gom từng bảng con trước (1-N thành 1-1), rồi mới nối

```sql
WITH loan_stats AS (
    SELECT book_id, COUNT(*) AS borrow_count
    FROM Loans GROUP BY book_id
),
res_stats AS (
    SELECT book_id, COUNT(*) AS pending_reservation
    FROM Reservations WHERE status = 'ready_pickup' GROUP BY book_id
)
SELECT b.book_id,
       COALESCE(ls.borrow_count, 0)        AS borrow_count,
       COALESCE(rs.pending_reservation, 0) AS pending_reservation
FROM Books b
LEFT JOIN loan_stats ls ON ls.book_id = b.book_id
LEFT JOIN res_stats  rs ON rs.book_id = b.book_id;
```



> Trước khi `GROUP BY`, hỏi: *"grain (độ chi tiết) của kết quả nối là gì?"* Nếu có hai nhánh 1-N cùng cấp, phải gom riêng.

---

### C4. Chọn nhầm loại JOIN

**Input** — Table `A` và Table `B`, nối theo `id`

| A.id |
| --- |
| 1 |
| 2 |
| 3 |

| B.id |
| --- |
| 2 |
| 3 |
| 4 |

**Task:** Quan sát kết quả `A JOIN B ON A.id = B.id` với từng loại JOIN.

**Output**

| JOIN | Giữ lại | Output (A.id, B.id) |
| --- | --- | --- |
| `INNER` | Chỉ dòng khớp hai phía | (2, 2), (3, 3) |
| `LEFT` | Tất cả dòng bảng trái | (1, NULL), (2, 2), (3, 3) |
| `RIGHT` | Tất cả dòng bảng phải | (2, 2), (3, 3), (NULL, 4) |
| `FULL OUTER` | Tất cả dòng hai bảng | (1, NULL), (2, 2), (3, 3), (NULL, 4) |

Thực hành: chỉ dùng `LEFT` (đổi thứ tự bảng thay vì dùng `RIGHT`) để code đọc nhất quán từ trái sang phải.

---

### C5. `DISTINCT` che lỗi JOIN và khóa nối không duy nhất

**Nguyên nhân.** Khi bảng được nối có **nhiều dòng cho một khóa** (ví dụ dimension dạng SCD Type 2 lưu lịch sử thay đổi), mỗi dòng bên trái bị nhân lên. Thêm `DISTINCT` hoặc `SUM(DISTINCT ...)` chỉ làm mờ triệu chứng và còn gộp nhầm các giá trị hợp lệ bằng nhau. Ngoài ra khóa nối `NULL` không bao giờ khớp (`NULL = NULL` là `UNKNOWN`), nên dòng đó biến mất khỏi `INNER JOIN`.

**Input**

Table `Orders`

| order_id | customer_id | total |
| --- | --- | --- |
| O1 | C01 | 100 |
| O2 | C01 | 100 |

Table `CustomerHistory` (lịch sử thay đổi thành phố)

| customer_id | city | is_current |
| --- | --- | --- |
| C01 | London | 0 |
| C01 | Paris | 1 |

**Task:** Tính tổng doanh thu.

**Expected Output**

| total_revenue |
| --- |
| 200 |

**Wrong Query**

```sql
-- (1) Nối thẳng
SELECT SUM(o.total) AS total_revenue
FROM Orders o JOIN CustomerHistory h ON o.customer_id = h.customer_id;

-- (2) "Chữa" bằng DISTINCT
SELECT SUM(DISTINCT o.total) AS total_revenue
FROM Orders o JOIN CustomerHistory h ON o.customer_id = h.customer_id;
```

**Output**

| Query | total_revenue | Giải thích |
| --- | --- | --- |
| (1) | 400 | 2 đơn × 2 bản ghi lịch sử = 4 dòng × 100 |
| (2) | 100 | `DISTINCT` gộp hai đơn cùng giá 100 thành một |

**Correct Query** — khóa nối phải duy nhất ở phía "một"

```sql
SELECT SUM(o.total) AS total_revenue
FROM Orders o
JOIN CustomerHistory h ON o.customer_id = h.customer_id AND h.is_current = 1;
```



> Trước mỗi JOIN, kiểm tra tính duy nhất của khóa phía "một":
> `SELECT customer_id, COUNT(*) FROM CustomerHistory GROUP BY customer_id HAVING COUNT(*) > 1;` (kết quả khác rỗng nghĩa là join sẽ nhân dòng).
> Dùng `LEFT JOIN` nếu không muốn mất dòng có khóa `NULL` hoặc khóa không khớp.

---

## D. Gom nhóm (`GROUP BY` / `HAVING`)

### D1. `SELECT` cột không thuộc `GROUP BY` và không nằm trong hàm tổng hợp

**Nguyên nhân.** Mỗi nhóm cho ra một dòng, nhưng cột lẻ có nhiều giá trị trong nhóm → không xác định.

**Input** — Table `Orders`

| customer | order_date | amount |
| --- | --- | --- |
| Alice | 2024-01-01 | 100 |
| Alice | 2024-01-05 | 500 |

**Task:** Với mỗi khách hàng, lấy ngày đặt hàng mới nhất và tổng tiền.

**Expected Output**

| customer | latest_order | total |
| --- | --- | --- |
| Alice | 2024-01-05 | 600 |

**Wrong Query**

```sql
SELECT customer, order_date, SUM(amount) AS total
FROM Orders
GROUP BY customer;
```

**Output**

| DBMS | Output |
| --- | --- |
| SQL Server | `ERROR: Column 'Orders.order_date' is invalid in the select list because it is not contained in either an aggregate function or the GROUP BY clause.` |
| PostgreSQL, Oracle, MySQL ≥ 5.7 (mặc định) | Báo lỗi tương tự |
| SQLite, MySQL tắt `ONLY_FULL_GROUP_BY` | `Alice, 2024-01-01, 600` (`order_date` là giá trị tùy ý → **sai âm thầm**) |

**Correct Query**

```sql
SELECT customer, MAX(order_date) AS latest_order, SUM(amount) AS total
FROM Orders
GROUP BY customer;
```

 Muốn lấy "cả dòng" của bản ghi mới nhất, dùng `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ... DESC)`.

---

### D2. Dùng `HAVING` cho điều kiện cấp dòng

**Nguyên nhân.** `WHERE` lọc trước khi gom, `HAVING` lọc sau. Điều kiện không chứa hàm tổng hợp nên đặt ở `WHERE` để giảm dữ liệu sớm và tận dụng index. (Nhiều optimizer tự đẩy xuống, nhưng không nên phụ thuộc vào điều đó.)

**Input** — Table `Employees` (bản thật: 1.000.000 dòng; sample rút gọn)

| name | department | salary |
| --- | --- | --- |
| Anna | IT | 10 |
| Ben | IT | 20 |
| Carl | HR | 30 |

**Task:** Tính tổng lương phòng IT.

**Expected Output**

| department | total_salary |
| --- | --- |
| IT | 30 |

**Wrong Query**

```sql
SELECT department, SUM(salary) AS total_salary
FROM Employees
GROUP BY department
HAVING department = 'IT';
```

**Output** — dữ liệu đúng, nhưng:

| | Wrong Query (`HAVING`) | Correct Query (`WHERE`) |
| --- | --- | --- |
| Dữ liệu trả về | `IT, 30` | `IT, 30` |
| Số dòng đi vào `GROUP BY` (sample) | 3 | 2 |
| Số dòng đi vào `GROUP BY` (bản 1M dòng) | 1.000.000 | chỉ các dòng IT |
| Thời gian (minh họa) | ~2–4 giây | vài ms |

**Correct Query**

```sql
SELECT department, SUM(salary) AS total_salary
FROM Employees
WHERE department = 'IT'
GROUP BY department;
```



| Mệnh đề | Lọc trên | Dùng hàm tổng hợp? |
| --- | --- | --- |
| `WHERE` | Từng dòng, trước gom nhóm | Không |
| `HAVING` | Từng nhóm, sau gom nhóm | Có |

---

## E. Subquery, tập hợp và xếp hạng

### E1. Tìm dữ liệu "không tồn tại" (Anti-join)

#### E1a. Bẫy `HAVING COUNT(*) = 0`

**Nguyên nhân.** `GROUP BY` chỉ tạo nhóm từ các dòng đang có, nên nhóm "0 dòng" không bao giờ tồn tại. Phép `JOIN` còn loại sẵn khách chưa có đơn.

**Input**

Table `Customers`

| id | name |
| --- | --- |
| 1 | Alice |
| 2 | Bob |

Table `Orders`

| id | customer_id |
| --- | --- |
| 1 | 1 |
| 2 | 1 |

**Task:** Tìm khách hàng chưa từng đặt đơn nào.

**Expected Output**

| name |
| --- |
| Bob |

**Wrong Query**

```sql
SELECT c.name
FROM Customers c
JOIN Orders o ON c.id = o.customer_id
GROUP BY c.name
HAVING COUNT(o.id) = 0;
```

**Output**

```
Empty set (0 rows)
```

Bob bị `JOIN` loại; Alice có `COUNT = 2`.

**Correct Query**

```sql
-- Cách 1: NOT EXISTS (khuyên dùng)
SELECT c.name FROM Customers c
WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.customer_id = c.id);

-- Cách 2: LEFT JOIN ... IS NULL
SELECT c.name FROM Customers c
LEFT JOIN Orders o ON o.customer_id = c.id
WHERE o.id IS NULL;
```



#### E1b. Bẫy `NOT IN` với tập có `NULL`

**Nguyên nhân.** `x NOT IN (1, 2, NULL)` ≡ `x<>1 AND x<>2 AND x<>NULL`; hạng tử cuối là `UNKNOWN` kéo cả biểu thức thành `UNKNOWN` → rỗng.

**Input**

Table `Customers`

| id | name |
| --- | --- |
| 1 | Alice |
| 2 | Bob |
| 3 | Carol |

Table `Promotions`

| promo_id | customer_id | promo_name |
| --- | --- | --- |
| 101 | 1 | Voucher $50 |
| 102 | 2 | Free shipping |
| 103 | NULL | Loyalty reward |

**Task:** Tìm khách hàng chưa nhận khuyến mãi nào.

**Expected Output**

| name |
| --- |
| Carol |

**Wrong Query**

```sql
SELECT name FROM Customers
WHERE id NOT IN (SELECT customer_id FROM Promotions);
```

**Output**

```
Empty set (0 rows)
```

**Correct Query**

```sql
SELECT c.name FROM Customers c
WHERE NOT EXISTS (SELECT 1 FROM Promotions p WHERE p.customer_id = c.id);
```

 Nếu vẫn dùng `NOT IN`, phải thêm `WHERE customer_id IS NOT NULL` trong subquery.

---

### E2. Tìm thực thể thỏa *đồng thời* nhiều điều kiện (Relational Division)

**Nguyên nhân.** Một dòng không thể vừa là `'Python'` vừa là `'SQL'`; `OR` trả về ai có *ít nhất một* kỹ năng. Cần đếm trên nhóm. (Cách giải bằng `INTERSECT` xem G2.)

**Input** — Table `EmployeeSkills`

| name | skill |
| --- | --- |
| Alice | Python |
| Alice | SQL |
| Bob | Python |

**Task:** Tìm nhân viên biết **cả** Python **và** SQL.

**Expected Output**

| name |
| --- |
| Alice |

**Wrong Query**

```sql
SELECT name FROM EmployeeSkills WHERE skill = 'Python' OR skill = 'SQL';
```

**Output**

| name |
| --- |
| Alice |
| Alice |
| Bob |

Bob chỉ biết Python vẫn lọt; Alice xuất hiện 2 lần.

**Correct Query**

```sql
SELECT name
FROM EmployeeSkills
WHERE skill IN ('Python', 'SQL')
GROUP BY name
HAVING COUNT(DISTINCT skill) = 2;   -- 2 = số kỹ năng yêu cầu
```



---

### E3. Subquery không tương quan khi cần so sánh theo nhóm

**Nguyên nhân.** `MAX` trong subquery độc lập tính trên *toàn bảng*, không theo phòng ban của dòng ngoài.

**Input** — Table `Employees`

| name | department | salary |
| --- | --- | --- |
| Anna | IT | 15000 |
| Ben | IT | 20000 |
| Carl | Sales | 30000 |
| Dan | Sales | 25000 |

**Task:** Tìm nhân viên có lương cao nhất *trong phòng ban của họ*.

**Expected Output**

| name | department | salary |
| --- | --- | --- |
| Ben | IT | 20000 |
| Carl | Sales | 30000 |

**Wrong Query**

```sql
SELECT name, department, salary FROM Employees
WHERE salary = (SELECT MAX(salary) FROM Employees);   -- MAX = 30000 của toàn công ty
```

**Output**

| name | department | salary |
| --- | --- | --- |
| Carl | Sales | 30000 |

**Correct Query** — subquery tương quan

```sql
SELECT name, department, salary
FROM Employees e1
WHERE salary = (SELECT MAX(salary) FROM Employees e2 WHERE e2.department = e1.department);
```

Hoặc dùng window function (thường dễ tối ưu hơn):

```sql
SELECT name, department, salary
FROM (SELECT *, MAX(salary) OVER (PARTITION BY department) AS max_salary FROM Employees) t
WHERE salary = max_salary;
```



---

### E4. `UNION` vs `UNION ALL`

**Nguyên nhân.** `UNION` khử trùng (tốn sort/hash) nên **làm mất** các dòng trùng hợp lệ; `UNION ALL` giữ nguyên và rẻ hơn.

**Input**

Table `Q1Transactions`

| txn_id | amount |
| --- | --- |
| 1 | 100 |
| 2 | 100 |

Table `Q2Transactions`

| txn_id | amount |
| --- | --- |
| 3 | 100 |
| 4 | 200 |

**Task:** Tính tổng tiền của cả hai quý.

**Expected Output**

| total |
| --- |
| 500 |

**Wrong Query**

```sql
SELECT SUM(amount) AS total FROM (
    SELECT amount FROM Q1Transactions
    UNION
    SELECT amount FROM Q2Transactions
) t;
```

**Output**

| total |
| --- |
| 300 |

Ba dòng `100` bị gộp thành một dòng `100`, rồi cộng với `200`.

**Correct Query**

```sql
SELECT SUM(amount) AS total FROM (
    SELECT amount FROM Q1Transactions
    UNION ALL
    SELECT amount FROM Q2Transactions
) t;
```

 Mặc định dùng `UNION ALL`; chỉ dùng `UNION` khi *chủ đích* khử trùng (và nên chọn cột định danh như `txn_id` để khử trùng đúng nghĩa).

---

### E5. Bảng tra cứu toán tử subquery

**Input** — Table `A` và Table `B`

| A.x |
| --- |
| 1 |
| 2 |
| 3 |

| B.y |
| --- |
| 2 |
| NULL |

**Task:** Quan sát kết quả khi lọc `A` bằng từng toán tử với subquery trên `B`.

**Output**

| Query (`SELECT x FROM A WHERE ...`) | Output | Giải thích |
| --- | --- | --- |
| `x IN (SELECT y FROM B)` | 2 | `NULL` không khớp bị bỏ qua |
| `x NOT IN (SELECT y FROM B)` | Empty set | Có `NULL` trong subquery → toàn bộ thành `UNKNOWN` |
| `EXISTS (SELECT 1 FROM B WHERE B.y = A.x)` | 2 | Chỉ kiểm tra có dòng khớp hay không |
| `NOT EXISTS (SELECT 1 FROM B WHERE B.y = A.x)` | 1, 3 | Không bị ảnh hưởng bởi `NULL` |
| `x > ALL (SELECT y FROM B)` | Empty set | `3 > 2` đúng nhưng `3 > NULL` là `UNKNOWN` → không bao giờ `TRUE` |
| `x > ANY (SELECT y FROM B)` | 3 | `3 > 2` đúng là đủ (`TRUE OR UNKNOWN`) |

**Bảng quy tắc**

| Toán tử | Tương đương | Subquery chứa `NULL` | Subquery rỗng |
| --- | --- | --- | --- |
| `IN` | `= A OR = B` | `NULL` không khớp bị bỏ qua | `FALSE` |
| `NOT IN` | `<> A AND <> B` | **Cả biểu thức thành `UNKNOWN` → rỗng** | `TRUE` |
| `EXISTS` | Có ≥ 1 dòng | Không bị ảnh hưởng | `FALSE` |
| `> ALL` | `> MAX` | Có `NULL` → không bao giờ `TRUE` | `TRUE` |
| `> ANY` | `> MIN` | `NULL` bị bỏ qua nếu còn giá trị khớp | `FALSE` |

---

### E6. Top-N mỗi nhóm và giá trị bằng nhau (Ties)

**Nguyên nhân.** `ROW_NUMBER` luôn đánh số khác nhau, nên khi lương bằng nhau nó chọn **tùy ý** một dòng (có thể khác nhau giữa các lần chạy). `RANK` và `DENSE_RANK` cho các dòng bằng nhau cùng hạng. Tương tự, `LIMIT n` mà `ORDER BY` không phân định hết thứ tự cũng cho kết quả không xác định.

**Input** — Table `Employees`

| name | department | salary |
| --- | --- | --- |
| Anna | IT | 20000 |
| Ben | IT | 20000 |
| Carl | IT | 15000 |
| Dan | Sales | 30000 |

**Task:** Tìm nhân viên lương cao nhất mỗi phòng (cùng mức lương thì lấy tất cả).

**Expected Output**

| name | department | salary |
| --- | --- | --- |
| Anna | IT | 20000 |
| Ben | IT | 20000 |
| Dan | Sales | 30000 |

**Wrong Query**

```sql
SELECT name, department, salary FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
    FROM Employees
) t WHERE rn = 1;
```

**Output**

| name | department | salary |
| --- | --- | --- |
| Anna *(hoặc Ben)* | IT | 20000 |
| Dan | Sales | 30000 |

Chỉ một trong hai người được chọn, không xác định.

**Correct Query**

```sql
SELECT name, department, salary FROM (
    SELECT *, RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rk
    FROM Employees
) t WHERE rk = 1;
```



**So sánh ba hàm xếp hạng** (phòng IT, `ORDER BY salary DESC`)

| name | salary | `ROW_NUMBER` | `RANK` | `DENSE_RANK` |
| --- | --- | --- | --- | --- |
| Anna | 20000 | 1 *(hoặc 2)* | 1 | 1 |
| Ben | 20000 | 2 *(hoặc 1)* | 1 | 1 |
| Carl | 15000 | 3 | **3** (nhảy hạng) | **2** (liên tục) |

| Nghiệp vụ | Hàm / cách dùng |
| --- | --- |
| Đúng 1 dòng mỗi nhóm, chấp nhận chọn tùy ý | `ROW_NUMBER` **kèm tiebreaker xác định**: `ORDER BY salary DESC, name` |
| Lấy tất cả dòng đồng hạng | `RANK` / `DENSE_RANK` |
| N mức lương cao nhất (không phải N người) | `DENSE_RANK() <= N` |
| `LIMIT`/`TOP` với ties | `FETCH FIRST n ROWS WITH TIES` (PostgreSQL 13+, Oracle 12c+, SQL Server `TOP n WITH TIES`) |

---

### E7. Dùng alias hoặc window function trong `WHERE`

**Nguyên nhân.** Theo thứ tự thực thi (mục 0.1), `WHERE` chạy **trước** `SELECT`, nên chưa thấy alias và chưa thấy kết quả window function.

**Input** — Table `Employees` (như E6)

| name | department | salary |
| --- | --- | --- |
| Anna | IT | 20000 |
| Ben | IT | 20000 |
| Carl | IT | 15000 |
| Dan | Sales | 30000 |

**Task 1:** Liệt kê nhân viên có lương năm (`salary * 12`) > 200000.

**Expected Output**

| name | annual_salary |
| --- | --- |
| Anna | 240000 |
| Ben | 240000 |
| Dan | 360000 |

**Task 2:** Lấy một nhân viên lương cao nhất mỗi phòng (cùng lương thì lấy theo tên).

**Expected Output**

| name | department |
| --- | --- |
| Anna | IT |
| Dan | Sales |

**Wrong Query**

```sql
SELECT name, salary * 12 AS annual_salary FROM Employees WHERE annual_salary > 200000;

SELECT name, department,
       ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, name) AS rn
FROM Employees WHERE rn = 1;
```

**Output**

```
ERROR: column "annual_salary" does not exist     -- SQL Server: Invalid column name 'annual_salary'
ERROR: column "rn" does not exist
```

**Correct Query** — lặp lại biểu thức, hoặc bọc subquery / CTE (hoặc `QUALIFY` trên Snowflake, BigQuery, Databricks)

```sql
-- Task 1
SELECT name, salary * 12 AS annual_salary FROM Employees WHERE salary * 12 > 200000;

-- Task 2
WITH x AS (
    SELECT name, department,
           ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, name) AS rn
    FROM Employees
)
SELECT name, department FROM x WHERE rn = 1;

-- Task 2 với QUALIFY (nếu DBMS hỗ trợ)
-- SELECT name, department FROM Employees
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, name) = 1;
```



| Mệnh đề | Dùng được alias của `SELECT`? |
| --- | --- |
| `WHERE`, `JOIN ... ON` | Không (mọi DBMS) |
| `GROUP BY`, `HAVING` | Tùy DBMS: MySQL, PostgreSQL (GROUP BY) có, SQL Server, Oracle không |
| `ORDER BY` | Có (mọi DBMS) |

---

## F. Window function

### F1. Window function đặt trên kết quả `GROUP BY`

**Nguyên nhân.** `GROUP BY` chạy trước, window function chạy sau trên các dòng *đã gom*; cột thô không còn tồn tại độc lập. Tính tỷ trọng sản phẩm trong danh mục cần **hai lớp** hàm tổng hợp:
- **Lớp trong** `SUM(amount)`: tổng theo từng sản phẩm (từ `GROUP BY`).
- **Lớp ngoài** `SUM(...) OVER (...)`: tổng của các tổng sản phẩm trong cùng danh mục.

**Input**

Table `Products`

| product_id | product_name | category |
| --- | --- | --- |
| 1 | Milk | Beverage |
| 2 | Water | Beverage |

Table `Transactions`

| transaction_id | product_id | amount |
| --- | --- | --- |
| 101 | 1 | 60 |
| 102 | 1 | 55 |
| 103 | 2 | 110 |

**Task:** Tính tổng bán ra của từng sản phẩm và tỷ trọng (%) so với tổng của danh mục chứa nó.

**Expected Output**

| product_name | total_sold | pct_of_category |
| --- | --- | --- |
| Milk | 115 | 51.11 |
| Water | 110 | 48.89 |

**Wrong Query**

```sql
SELECT p.product_name,
       SUM(t.amount) AS total_sold,
       ROUND(100.0 * SUM(t.amount) / SUM(t.amount) OVER (PARTITION BY p.category), 2) AS pct_of_category
FROM Transactions t
JOIN Products p ON p.product_id = t.product_id
GROUP BY p.product_id, p.product_name, p.category;
```

**Output**

```
ERROR: column "t.amount" must appear in the GROUP BY clause or be used in an aggregate function
-- SQL Server / PostgreSQL / Oracle / MySQL 8.0 đều báo lỗi tương tự
```

DB lỏng lẻo có thể lấy một giá trị dòng đơn lẻ (ví dụ chỉ lấy 60 của Milk) → % hoàn toàn sai lệch.

**Correct Query** — `SUM(SUM(...)) OVER`

```sql
SELECT p.product_name,
       SUM(t.amount) AS total_sold,
       ROUND(100.0 * SUM(t.amount)
             / SUM(SUM(t.amount)) OVER (PARTITION BY p.category), 2) AS pct_of_category
FROM Transactions t
JOIN Products p ON p.product_id = t.product_id
GROUP BY p.product_id, p.product_name, p.category;
```



> **Quy tắc thuộc lòng**
> - Gom tất cả trong 1 CTE/query: luôn dùng cú pháp 2 lớp `SUM(SUM(cột)) OVER (...)`.
> - Sợ rối mắt: tách **2 CTE riêng**. CTE 1 dùng `GROUP BY` tính `total_sold`; CTE 2 mới gọi `SUM(total_sold) OVER (PARTITION BY category)` trên kết quả đã gom. Cách này minh bạch và không bao giờ dính lỗi lớp dữ liệu.

---

### F2. Frame mặc định khi có `ORDER BY` (tổng dồn ngoài ý muốn)

**Nguyên nhân.** Thêm `ORDER BY` vào `OVER()` đổi frame mặc định từ "toàn partition" sang `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. Nhiều người tưởng `ORDER BY` trong `OVER` chỉ để sắp xếp, nhưng thực chất nó **chuyển phép tính từ "tổng nhóm" thành "tổng dồn từng dòng"**.

**Bảng quy tắc frame mặc định**

| Có `PARTITION BY`? | Có `ORDER BY`? | Có `ROWS` / `RANGE`? | Phạm vi tính toán (Frame) | Hành vi chi tiết |
| --- | --- | --- | --- | --- |
| Không | Không | — | `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` | Tổng hợp trên **toàn bộ result set** |
| Có | Không | — | `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` | Tổng hợp trên **toàn bộ partition** tương ứng |
| Không | Có | Không | `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | **Tổng dồn** từ dòng đầu của result set đến dòng hiện tại |
| Có | Có | Không | `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | **Tổng dồn** từ dòng đầu của partition đến dòng hiện tại |
| bất kỳ | Có | Có | Theo đúng khai báo | Áp dụng chính xác khung dữ liệu bạn chủ động thiết lập |

#### F2a. Tổng toàn bảng bị thành tổng dồn

**Input** — Table `DailyRevenue`

| day | revenue |
| --- | --- |
| 2024-01-01 | 100 |
| 2024-01-02 | 200 |
| 2024-01-03 | 150 |

**Task:** Hiển thị doanh thu từng ngày kèm tổng doanh thu của toàn bộ bảng.

**Expected Output**

| day | revenue | total_revenue |
| --- | --- | --- |
| 2024-01-01 | 100 | 450 |
| 2024-01-02 | 200 | 450 |
| 2024-01-03 | 150 | 450 |

**Wrong Query**

```sql
SELECT day, revenue, SUM(revenue) OVER (ORDER BY day) AS total_revenue FROM DailyRevenue;
```

**Output**

| day | revenue | total_revenue |
| --- | --- | --- |
| 2024-01-01 | 100 | 100 |
| 2024-01-02 | 200 | 300 |
| 2024-01-03 | 150 | 450 |

**Correct Query**

```sql
-- Cách 1: bỏ ORDER BY
SELECT day, revenue, SUM(revenue) OVER () AS total_revenue FROM DailyRevenue;

-- Cách 2: bắt buộc giữ ORDER BY (để dùng cho cột khác) → khai báo rõ Frame
SELECT day, revenue,
       SUM(revenue) OVER (ORDER BY day
                          ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS total_revenue
FROM DailyRevenue;
```



#### F2b. `ROWS` vs `RANGE` khi có giá trị trùng (Ties)

`ROWS` duyệt chính xác **theo số dòng** vật lý. `RANGE` duyệt **theo giá trị của cột `ORDER BY`**: các dòng có cùng giá trị sắp xếp bị **gộp chung** vào một bước, làm tổng dồn bị "nhảy vọt".

**Input** — Table `Transactions`

| day | amount |
| --- | --- |
| 2024-01-01 | 100 |
| 2024-01-01 | 100 |
| 2024-01-02 | 200 |

**Task:** Tính tổng dồn theo từng dòng.

**Expected Output**

| day | amount | running_total |
| --- | --- | --- |
| 2024-01-01 | 100 | 100 |
| 2024-01-01 | 100 | 200 |
| 2024-01-02 | 200 | 400 |

**Wrong Query** (mặc định là `RANGE`)

```sql
SELECT day, amount, SUM(amount) OVER (ORDER BY day) AS running_total FROM Transactions;
```

**Output**

| day | amount | running_total |
| --- | --- | --- |
| 2024-01-01 | 100 | 200 |
| 2024-01-01 | 100 | 200 |
| 2024-01-02 | 200 | 400 |

Hai dòng cùng ngày được cộng gộp cùng lúc nên cả hai ra `200`.

**Correct Query**

```sql
SELECT day, amount,
       SUM(amount) OVER (ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM Transactions;
```



> **Khuyên dùng:** luôn ưu tiên `ROWS` thay vì `RANGE` khi tính toán dồn (Running Totals / Moving Averages). Ngoài đúng hơn, `RANGE` phải gom các giá trị trùng nên tốn thêm chi phí, tùy DBMS có thể phải spill ra đĩa / TempDB.

#### F2c. `ROWS n PRECEDING` vs `RANGE n PRECEDING`

`ROWS n` đếm n **dòng** phía trước. `RANGE n` lấy các dòng có **giá trị `ORDER BY` nằm trong [giá trị hiện tại − n, giá trị hiện tại]**, nên bị ảnh hưởng khi dữ liệu có khoảng trống.

**Input** — Table `Sales` (thiếu ngày 3)

| day_no | amount |
| --- | --- |
| 1 | 10 |
| 2 | 20 |
| 4 | 30 |
| 5 | 40 |

**Task:** Tổng doanh thu của ngày hiện tại và **ngày liền trước** (theo lịch).

**Expected Output**

| day_no | amount | sum_2_days |
| --- | --- | --- |
| 1 | 10 | 10 |
| 2 | 20 | 30 |
| 4 | 30 | 30 |
| 5 | 40 | 70 |

**Wrong Query**

```sql
SELECT day_no, amount,
       SUM(amount) OVER (ORDER BY day_no ROWS 1 PRECEDING) AS sum_2_days
FROM Sales;
```

**Output**

| day_no | amount | sum_2_days |
| --- | --- | --- |
| 1 | 10 | 10 |
| 2 | 20 | 30 |
| 4 | 30 | 50 |
| 5 | 40 | 70 |

Ngày 4 cộng nhầm ngày 2 (cách 2 ngày) vì `ROWS` đếm theo dòng.

**Correct Query**

```sql
SELECT day_no, amount,
       SUM(amount) OVER (ORDER BY day_no RANGE BETWEEN 1 PRECEDING AND CURRENT ROW) AS sum_2_days
FROM Sales;
```

 (`RANGE` với độ lệch số: PostgreSQL, Oracle, MySQL 8 hỗ trợ; SQL Server chỉ hỗ trợ `UNBOUNDED` và `CURRENT ROW`.)

**Cú pháp rút gọn → đầy đủ**

| Cú pháp viết tắt | Cú pháp đầy đủ (SQL tự hiểu) | Phạm vi tính toán |
| --- | --- | --- |
| `ROWS 3 PRECEDING` | `ROWS BETWEEN 3 PRECEDING AND CURRENT ROW` | Từ 3 dòng trước đó đến dòng hiện tại (tổng 4 dòng) |
| `RANGE 3 PRECEDING` | `RANGE BETWEEN 3 PRECEDING AND CURRENT ROW` | Từ các dòng có giá trị trong khoảng [giá trị hiện tại − 3, giá trị hiện tại] đến dòng hiện tại |
| `ROWS UNBOUNDED PRECEDING` | `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | Từ dòng đầu tiên của partition đến dòng hiện tại (tính dồn) |
| `RANGE UNBOUNDED PRECEDING` | `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | Từ dòng đầu tiên đến dòng hiện tại (tính dồn theo giá trị) |

---

### F3. `LAST_VALUE` / `NTH_VALUE` với frame mặc định, và `LAG` / `LEAD` ở biên

**Nguyên nhân.** Khi có `ORDER BY`, frame mặc định kết thúc ở `CURRENT ROW` (xem F2), nên `LAST_VALUE` chỉ thấy đến dòng hiện tại và trả về **chính nó**. `FIRST_VALUE` không gặp vấn đề vì frame luôn bắt đầu từ đầu partition. `LAG` ở dòng đầu (và `LEAD` ở dòng cuối) trả `NULL` do không có dòng liền kề.

**Input** — Table `DailyRevenue`

| day | revenue |
| --- | --- |
| 2024-01-01 | 100 |
| 2024-01-02 | 200 |
| 2024-01-03 | 150 |

**Task:** Hiển thị doanh thu của ngày cuối cùng (`last_day_revenue`) và mức tăng so với ngày trước (`change`, ngày đầu tiên tính là 0).

**Expected Output**

| day | revenue | last_day_revenue | change |
| --- | --- | --- | --- |
| 2024-01-01 | 100 | 150 | 0 |
| 2024-01-02 | 200 | 150 | 100 |
| 2024-01-03 | 150 | 150 | -50 |

**Wrong Query**

```sql
SELECT day, revenue,
       LAST_VALUE(revenue) OVER (ORDER BY day) AS last_day_revenue,
       revenue - LAG(revenue) OVER (ORDER BY day) AS change
FROM DailyRevenue;
```

**Output**

| day | revenue | last_day_revenue | change |
| --- | --- | --- | --- |
| 2024-01-01 | 100 | 100 | NULL |
| 2024-01-02 | 200 | 200 | 100 |
| 2024-01-03 | 150 | 150 | -50 |

**Correct Query**

```sql
SELECT day, revenue,
       LAST_VALUE(revenue) OVER (
           ORDER BY day
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_day_revenue,
       revenue - LAG(revenue, 1, revenue) OVER (ORDER BY day) AS change   -- đối số thứ 3: giá trị mặc định
FROM DailyRevenue;
```



> Cách khác tránh frame: `FIRST_VALUE(revenue) OVER (ORDER BY day DESC)` để lấy giá trị cuối. Quyết định theo nghiệp vụ cho dòng đầu của `LAG`: `NULL` (không có dữ liệu so sánh) hay `0`.

---

## G. Tư duy tập hợp (Thinking in Sets)

Mỗi kết quả truy vấn là một **tập hợp các dòng**. Nhiều bài toán "một dòng không thể vừa là A vừa là B" chỉ dễ giải khi nhìn chúng như phép toán trên các tập: lấy tập A, lấy tập B, rồi giao, trừ hoặc hợp.

### G1. Ánh xạ từ ngôn ngữ nghiệp vụ sang phép toán tập hợp

**Input** — Table `OrderItems` (dùng cho G1–G3)

| order_id | customer | product |
| --- | --- | --- |
| 1 | Alice | Laptop |
| 2 | Alice | Mouse |
| 3 | Bob | Laptop |
| 4 | Carol | Mouse |
| 5 | Bob | Laptop |

Tập khách mua Laptop = {Alice, Bob}. Tập khách mua Mouse = {Alice, Carol}.

**Output** — kết quả của từng phép toán trên sample

| Cách nói trong yêu cầu | Phép toán | Toán tử SQL | Output trên sample | Cách viết không dùng toán tử tập hợp |
| --- | --- | --- | --- | --- |
| "**vừa** A **vừa** B", "cả hai" | Giao A ∩ B | `INTERSECT` | Alice | `IN` / `EXISTS`, hoặc `GROUP BY ... HAVING COUNT(DISTINCT) = n` (E2) |
| "có A **nhưng không** có B", "chưa từng" | Hiệu A ∖ B | `EXCEPT` (Oracle: `MINUS`) | Bob | `NOT EXISTS`, `LEFT JOIN ... IS NULL` (E1) |
| "A **hoặc** B", "gộp từ nhiều nguồn" | Hợp A ∪ B | `UNION` | Alice, Bob, Carol | `IN (...)`, `OR` (chỉ khi cùng một bảng) |
| "chỉ có ở **một trong hai**" | Hiệu đối xứng A Δ B | `(A EXCEPT B) UNION (B EXCEPT A)` | Bob, Carol | `FULL OUTER JOIN ... WHERE a IS NULL OR b IS NULL` |

> Bước đầu khi gặp bài toán: **viết ra từng tập con** (A là gì, B là gì) rồi chọn phép toán, thay vì cố nhét mọi điều kiện vào một `WHERE`.

---

### G2. Giao (`INTERSECT`): "vừa mua A vừa mua B"

**Nguyên nhân.** `WHERE` đánh giá **từng dòng riêng lẻ**: một dòng không thể có `product` vừa bằng `'Laptop'` vừa bằng `'Mouse'`. Muốn điều kiện thỏa trên *nhiều dòng của cùng một khách*, phải lấy hai tập rồi giao chúng.

**Input** — Table `OrderItems` (như G1)

**Task:** Tìm khách hàng đã mua **cả** Laptop **và** Mouse.

**Expected Output**

| customer |
| --- |
| Alice |

**Wrong Query**

```sql
-- (1) AND trên cùng một dòng
SELECT customer FROM OrderItems WHERE product = 'Laptop' AND product = 'Mouse';

-- (2) OR: lấy ai mua một trong hai
SELECT customer FROM OrderItems WHERE product = 'Laptop' OR product = 'Mouse';
```

**Output**

| Query | Output |
| --- | --- |
| (1) | Empty set (0 rows) |
| (2) | Alice, Alice, Bob, Carol, Bob (5 dòng, có trùng; Bob và Carol vẫn lọt) |

**Correct Query**

```sql
SELECT customer FROM OrderItems WHERE product = 'Laptop'
INTERSECT
SELECT customer FROM OrderItems WHERE product = 'Mouse';
```



| Cách | Khi nào nên dùng |
| --- | --- |
| `INTERSECT` | 2–3 tập, các điều kiện khác nhau về bản chất, dễ đọc nhất |
| `GROUP BY ... HAVING COUNT(DISTINCT product) = n` (E2) | Cần "đủ **n** giá trị" trong một danh sách, mở rộng dễ khi n lớn |
| `WHERE customer IN (...) AND customer IN (...)` / `EXISTS` | DBMS không có `INTERSECT` (MySQL < 8.0.31) |

---

### G3. Hiệu (`EXCEPT`): "có A nhưng không có B"

**Nguyên nhân.** Điều kiện phủ định trên từng dòng (`product <> 'Mouse'`) chỉ loại **dòng** Mouse, không loại **khách** đã mua Mouse. Hiệu hai tập thì phép loại áp dụng trên khách hàng. Phép hiệu **không đối xứng**: `A EXCEPT B` khác `B EXCEPT A`.

**Input** — Table `OrderItems` (như G1)

**Task:** Tìm khách hàng đã mua Laptop nhưng **chưa từng** mua Mouse.

**Expected Output**

| customer |
| --- |
| Bob |

**Wrong Query**

```sql
SELECT customer FROM OrderItems WHERE product = 'Laptop' AND product <> 'Mouse';
-- hoặc: WHERE product <> 'Mouse'
```

**Output**

| customer |
| --- |
| Alice |
| Bob |
| Bob |

Alice vẫn lọt vì còn dòng Laptop; Bob xuất hiện hai lần.

**Correct Query**

```sql
SELECT customer FROM OrderItems WHERE product = 'Laptop'
EXCEPT                                   -- Oracle: MINUS
SELECT customer FROM OrderItems WHERE product = 'Mouse';
```

 Đảo thứ tự hai vế (Mouse `EXCEPT` Laptop) ra `Carol`.

> `EXCEPT` **an toàn với `NULL`** (xem G5) nên là lựa chọn thay thế tốt cho `NOT IN` (E1b); `NOT EXISTS` vẫn là cách tối ưu hơn khi cần nhiều cột hoặc bảng lớn.

---

### G4. Hợp (`UNION`) và hiệu đối xứng

**Nguyên nhân.** Khi cùng một thực thể xuất hiện ở nhiều nguồn, `UNION` cho tập **các thực thể phân biệt**, còn `UNION ALL` cho tập **các dòng**. Đếm khách hàng mà dùng nhầm `UNION ALL` sẽ đếm trùng. (E4 là chiều ngược lại: dùng `UNION` làm mất dòng hợp lệ.)

**Input**

Table `OnlineCustomers`

| name |
| --- |
| Alice |
| Bob |

Table `StoreCustomers`

| name |
| --- |
| Bob |
| Carol |

**Task 1:** Có bao nhiêu khách hàng phân biệt trên cả hai kênh?

**Expected Output**

| customer_count |
| --- |
| 3 |

**Wrong Query**

```sql
SELECT COUNT(*) AS customer_count FROM (
    SELECT name FROM OnlineCustomers UNION ALL SELECT name FROM StoreCustomers
) t;
```

**Output**

| customer_count |
| --- |
| 4 |

Bob bị đếm hai lần.

**Correct Query**

```sql
SELECT COUNT(*) AS customer_count FROM (
    SELECT name FROM OnlineCustomers UNION SELECT name FROM StoreCustomers
) t;
```



**Task 2 (hiệu đối xứng):** Tìm khách hàng chỉ mua ở **một** kênh.

**Expected Output**

| name |
| --- |
| Alice |
| Carol |

**Correct Query**

```sql
(SELECT name FROM OnlineCustomers EXCEPT SELECT name FROM StoreCustomers)
UNION
(SELECT name FROM StoreCustomers  EXCEPT SELECT name FROM OnlineCustomers);
```



---

### G5. Ngữ nghĩa của toán tử tập hợp: trùng lặp, NULL và cú pháp

**Input**

Table `A`

| x |
| --- |
| 1 |
| 1 |
| NULL |

Table `B`

| x |
| --- |
| NULL |
| 2 |

**Task:** So sánh cách `INTERSECT` / `EXCEPT` và `JOIN` / `NOT IN` xử lý `NULL` và dòng trùng trên cùng dữ liệu.

**Output**

| Query | Output | Giải thích |
| --- | --- | --- |
| `SELECT x FROM A EXCEPT SELECT x FROM B` | 1 | Tự khử trùng (một dòng `1` thay vì hai); `NULL` của A bị loại vì **khớp** với `NULL` của B |
| `SELECT x FROM A INTERSECT SELECT x FROM B` | NULL | Set operator coi hai `NULL` là **bằng nhau** |
| `SELECT DISTINCT A.x FROM A JOIN B ON A.x = B.x` | Empty set | `JOIN`/`IN` dùng `=` nên `NULL = NULL` là `UNKNOWN` |
| `SELECT x FROM A WHERE x NOT IN (SELECT x FROM B)` | Empty set | `NOT IN` gặp `NULL` trong tập con → `UNKNOWN` (E1b) |

Đây là điểm khác biệt quan trọng: **toán tử tập hợp so sánh dòng theo kiểu "không phân biệt" (`IS NOT DISTINCT FROM`), không theo `=`**. Cùng một bài "tìm phần chung/phần thiếu", `INTERSECT`/`EXCEPT` và `JOIN`/`NOT IN` có thể cho kết quả khác khi dữ liệu có `NULL`.

**Quy tắc cú pháp và bẫy thường gặp**

| Bẫy | Chi tiết |
| --- | --- |
| Tự khử trùng | `UNION`, `INTERSECT`, `EXCEPT` đều loại dòng trùng. Muốn giữ bội số: `UNION ALL`, và `INTERSECT ALL` / `EXCEPT ALL` (hỗ trợ tùy DBMS, PostgreSQL có) |
| Số cột và kiểu | Các vế phải **cùng số cột**, kiểu dữ liệu **tương thích** theo từng vị trí (không theo tên cột). Tên cột của kết quả lấy từ vế đầu |
| `ORDER BY` | Chỉ đặt **một lần ở cuối** cả câu, và sắp xếp theo tên cột/vị trí của vế đầu |
| Độ ưu tiên | Theo chuẩn SQL, `INTERSECT` ưu tiên cao hơn `UNION`/`EXCEPT`; một số DBMS (như Oracle) coi chúng ngang cấp, tính từ trái sang phải. **Luôn dùng ngoặc** khi trộn nhiều toán tử |
| Khác biệt phương ngữ | Oracle dùng `MINUS` (bản mới có `EXCEPT`); MySQL chỉ có `INTERSECT`/`EXCEPT` từ 8.0.31; SQL Server, PostgreSQL hỗ trợ đầy đủ |
| Hiệu năng | Mỗi toán tử khử trùng phải sort/hash toàn bộ kết quả. Với bảng lớn, `EXISTS` / `NOT EXISTS` thường nhanh hơn |

---

## Checklist trước khi chạy truy vấn

1. **Grain:** mỗi dòng của kết quả đại diện cho cái gì? Có JOIN 1-N nào làm nhân dòng không? (C1, C3)
2. **NULL:** cột nào có thể `NULL`? So sánh, phủ định, `NOT IN`, hàm tổng hợp xử lý ra sao? (A2–A4, E1)
3. **Biên:** khoảng lọc đã nửa mở `[from, to)` chưa? Kiểu dữ liệu hai vế có khớp không? (A1, B2)
4. **Ngoặc:** mọi `OR` trộn với `AND` đã có ngoặc chưa? (B1)
5. **Vị trí điều kiện:** với `LEFT JOIN`, điều kiện bảng phải ở `ON` hay `WHERE`? Với gom nhóm, ở `WHERE` hay `HAVING`? (C2, D2)
6. **Index:** cột lọc có bị bọc hàm/biểu thức không? (B3)
7. **Window:** có `ORDER BY` trong `OVER` thì frame là gì (`ROWS` hay `RANGE`)? Có đang đặt window trên dữ liệu đã `GROUP BY` không? (F1, F2)
8. **Phép tính:** có phép chia nào chia số nguyên cho số nguyên, hoặc mẫu số có thể bằng 0 không? Tập rỗng có cần hiển thị `0` thay vì `NULL` không? Chuỗi nối có cột `NULL` không? (A5–A7)
9. **Khóa nối:** phía "một" của JOIN có thật sự duy nhất không? Có đang dùng `DISTINCT` để che số dòng bị nhân không? (C5)
10. **Xếp hạng:** dữ liệu có giá trị bằng nhau không? `ORDER BY` / `LIMIT` đã có tiebreaker chưa? Có đang lọc theo alias hoặc window function trong `WHERE` không? (E6, E7)
11. **Frame:** `LAST_VALUE` / `NTH_VALUE` đã khai báo frame đến `UNBOUNDED FOLLOWING` chưa? `LAG` / `LEAD` xử lý dòng biên ra sao? (F3)
12. **Tư duy tập hợp:** yêu cầu có dạng "vừa A vừa B" / "A nhưng không B" / "A hoặc B"? Đã viết ra từng tập con và chọn `INTERSECT` / `EXCEPT` / `UNION` (hoặc phép tương đương) chưa? Có quan tâm `NULL` và dòng trùng khi dùng toán tử tập hợp không? (G1–G5, E1, E2)
13. **Kiểm chứng:** thử trên tập nhỏ có đủ các trường hợp biên (NULL, trùng, rỗng, sát biên) và đối chiếu số dòng/tổng với kỳ vọng.
