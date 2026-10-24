# Top N mỗi nhóm

> Bài liên quan: `topn/01`–`05`. Output đều chạy thật bằng `check.py`.

## Bài toán

Công ty muốn biết **2 người lương cao nhất của mỗi phòng ban**. Nếu có người bằng lương nhau ở ranh giới, lấy hết họ.

Cách nghĩ đầu tiên là `ORDER BY salary DESC LIMIT 2`. Nhưng `LIMIT` cắt trên **cả bảng**, không cắt theo từng phòng: nó trả về đúng 2 người lương cao nhất công ty (Alice và Ben, cùng phòng Engineering), và các phòng khác không có ai. Ta cần **đánh số lại từ 1 trong mỗi phòng**, rồi lọc theo số đó.

## Dữ liệu

`employees`: mỗi dòng = 1 nhân viên. Lương tính bằng triệu đồng, có thể là `NULL`.

| emp_id | name | department | salary |
| --- | --- | --- | --- |
| 1 | Alice | Engineering | 90 |
| 2 | Ben | Engineering | 90 |
| 3 | Chloe | Engineering | 80 |
| 4 | David | Engineering | 70 |
| 5 | Emma | Sales | 60 |
| 6 | Frank | Sales | 50 |
| 7 | Grace | Sales | 50 |
| 8 | Henry | Sales | 40 |
| 9 | Ivy | Support | 55 |
| 10 | Jack | Support | NULL |
| 11 | Kate | Marketing | 75 |

Ba chỗ dễ sai: Alice và Ben **bằng lương** ở vị trí đầu, Frank và Grace **bằng lương** ở vị trí thứ hai, và Jack **chưa có lương**.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Chọn hàm xếp hạng theo cách đề xử lý người bằng nhau | (quyết định trước khi viết) | |
| B2 | Xếp hạng trong từng phòng | CTE `ranked` | 1 nhân viên, kèm hạng |
| B3 | Lọc hạng ở tầng ngoài | query cuối | chỉ còn người đạt hạng |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Chọn hàm xếp hạng

**Ý tưởng:** có ba hàm xếp hạng. Chúng chỉ khác nhau ở cách xử lý **người bằng nhau**, và chọn hàm nào là do đề quyết định.

**Ví dụ nhỏ:** phòng Engineering, lương 90, 90, 80, 70.

| name | salary | `ROW_NUMBER` | `RANK` | `DENSE_RANK` |
| --- | --- | --- | --- | --- |
| Alice | 90 | 1 | 1 | 1 |
| Ben | 90 | 2 | 1 | 1 |
| Chloe | 80 | 3 | **3** | **2** |
| David | 70 | 4 | 4 | 3 |

- `ROW_NUMBER`: luôn đánh 1, 2, 3, 4, kể cả khi bằng nhau. Dùng khi đề cần **đúng N dòng**, hoặc "bản ghi mới nhất".
- `RANK`: người bằng nhau cùng hạng, rồi **bỏ qua** các hạng đã bị chiếm (hai người hạng 1 thì người tiếp theo là hạng 3). Dùng khi đề nói "top N, bằng nhau thì lấy hết".
- `DENSE_RANK`: người bằng nhau cùng hạng, và **không bỏ** hạng nào (người tiếp theo là hạng 2). Dùng khi đề nói "N mức lương cao nhất" hoặc "mức lương cao thứ N".

Đề ở mạch chính là "top 2, bằng nhau thì lấy hết", nên dùng `RANK`.

## B2. Xếp hạng trong từng phòng (CTE `ranked`)

**Ý tưởng:** `PARTITION BY department` để mỗi phòng đánh số lại từ 1, `ORDER BY salary DESC` để người lương cao nhất đứng đầu.

**Ví dụ nhỏ:** phòng Sales.

| name | salary | rnk |
| --- | --- | --- |
| Emma | 60 | 1 |
| Frank | 50 | 2 |
| Grace | 50 | 2 |
| Henry | 40 | 4 |

```sql
WITH ranked AS (
  SELECT department, name, salary,
         RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rnk
  FROM employees
  WHERE salary IS NOT NULL
)
```

> [!CAUTION]
> ❌ **Không lọc lương `NULL`**
>
> PostgreSQL coi `NULL` lớn hơn mọi giá trị, nên khi `ORDER BY salary DESC`, `NULL` đứng **đầu**. Jack chưa có lương nhưng lại nhận hạng 1 của phòng Support, đẩy Ivy xuống hạng 2.
>
> → **Sửa:** `WHERE salary IS NOT NULL`, hoặc `ORDER BY salary DESC NULLS LAST` nếu vẫn muốn giữ Jack ở cuối.

## B3. Lọc hạng ở tầng ngoài (query cuối)

**Ý tưởng:** giữ người có `rnk <= 2`. Hạng được tính bằng hàm cửa sổ, mà hàm cửa sổ chạy **sau** `WHERE`. Vì vậy không lọc hạng được trong cùng câu đã tính hạng. Phải tính ở CTE `ranked`, rồi lọc ở tầng ngoài.

```sql
SELECT department, name, salary
FROM ranked
WHERE rnk <= 2
ORDER BY department, salary DESC, name;
```

| department | name | rnk | kept? |
| --- | --- | --- | --- |
| Engineering | Alice | 1 | yes |
| Engineering | Ben | 1 | yes |
| Engineering | Chloe | 3 | <span class="drop">no</span> |
| Sales | Frank | 2 | yes |
| Sales | Grace | 2 | yes |
| ... | | | |

Engineering chỉ có 2 người, vì Chloe đứng hạng 3 (`RANK` bỏ qua hạng 2). Sales có 3 người, vì Frank và Grace cùng hạng 2.

> [!CAUTION]
> ❌ **Lọc thẳng trong cùng câu: `WHERE RANK() OVER (...) <= 2`**
>
> ```text
> ERROR:  window functions are not allowed in WHERE
> ```
>
> `WHERE` chạy trước khi hàm cửa sổ được tính, nên lúc đó chưa có hạng để lọc.
>
> → **Sửa:** tính hạng trong một CTE hoặc truy vấn con, rồi `WHERE rnk <= 2` ở tầng ngoài.

## Tổng kết: query đầy đủ

```sql
WITH ranked AS (                                   -- B1 + B2: RANK trong từng phòng
  SELECT department, name, salary,
         RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rnk
  FROM employees
  WHERE salary IS NOT NULL
)
SELECT department, name, salary                    -- B3: lọc hạng ở tầng ngoài
FROM ranked
WHERE rnk <= 2
ORDER BY department, salary DESC, name;
```

Cả ba cách xếp hạng sau B2:

| department | name | salary | rn | rnk | drnk |
| --- | --- | --- | --- | --- | --- |
| Engineering | Alice | 90 | 1 | 1 | 1 |
| Engineering | Ben | 90 | 2 | 1 | 1 |
| Engineering | Chloe | 80 | 3 | 3 | 2 |
| Engineering | David | 70 | 4 | 4 | 3 |
| Marketing | Kate | 75 | 1 | 1 | 1 |
| Sales | Emma | 60 | 1 | 1 | 1 |
| Sales | Frank | 50 | 2 | 2 | 2 |
| Sales | Grace | 50 | 3 | 2 | 2 |
| Sales | Henry | 40 | 4 | 4 | 3 |
| Support | Ivy | 55 | 1 | 1 | 1 |

Kết quả cuối:

| department | name | salary |
| --- | --- | --- |
| Engineering | Alice | 90 |
| Engineering | Ben | 90 |
| Marketing | Kate | 75 |
| Sales | Emma | 60 |
| Sales | Frank | 50 |
| Sales | Grace | 50 |
| Support | Ivy | 55 |

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính: hỏi mức lương cao thứ N, lấy bản ghi mới nhất của mỗi nhóm, hoặc cấm dùng hàm cửa sổ. Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi hỏi mức lương cao thứ hai

Đề: **trong mỗi phòng, ai có mức lương cao thứ hai?** Hai người cùng lương cao nhất thì cùng đứng ở mức thứ nhất. Phòng không có mức lương thứ hai thì bỏ qua.

### Thử `RANK = 2`

Mạch chính dùng `RANK`, nên cách nghĩ nhanh là đổi `rnk <= 2` thành `rnk = 2`:

| department | name | salary | rnk |
| --- | --- | --- | --- |
| Sales | Frank | 50 | 2 |
| Sales | Grace | 50 | 2 |

Phòng Engineering biến mất. Alice và Ben cùng hạng 1, nên `RANK` cho Chloe hạng **3**: không có ai hạng 2. Nhưng Chloe (80) rõ ràng có mức lương cao thứ hai của phòng.

### Cách sửa: `DENSE_RANK`

"Mức lương cao thứ hai" là hỏi về **mức lương**, không phải về vị trí người. `DENSE_RANK` đánh số các mức lương khác nhau liên tiếp, không bỏ số nào:

```sql
WITH ranked AS (
  SELECT department, name, salary,
         DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS drnk
  FROM employees
  WHERE salary IS NOT NULL
)
SELECT department, name, salary
FROM ranked
WHERE drnk = 2
ORDER BY department, name;
```

| department | name | salary |
| --- | --- | --- |
| Engineering | Chloe | 80 |
| Sales | Frank | 50 |
| Sales | Grace | 50 |

Marketing và Support chỉ có một mức lương, nên không có dòng nào, đúng như đề yêu cầu.

> [!TIP]
> **Ghi nhớ:** "mức thứ N" (bằng nhau không chiếm chỗ) thì dùng `DENSE_RANK`. "Top N người" (bằng nhau thì lấy hết) thì dùng `RANK`.

## V2. Khi lấy bản ghi mới nhất của mỗi nhóm

Bảng lưu lịch sử đổi email của khách. Đề: **mỗi khách đang dùng email nào**, tức email của lần cập nhật **mới nhất**? Nếu hai lần cập nhật cùng ngày, lấy lần có `update_id` lớn hơn.

```text
email_updates (update_id, customer_id, email, updated_at)   -- mới
```

| update_id | customer_id | email | updated_at |
| --- | --- | --- | --- |
| 1 | 1 | alice@old.com | 2024-01-10 |
| 2 | 1 | alice@work.com | 2024-03-05 |
| 3 | 1 | alice@new.com | 2024-03-05 |
| 4 | 2 | ben@mail.com | 2024-02-01 |
| 5 | 3 | chloe@a.com | 2024-02-20 |
| 6 | 3 | chloe@b.com | 2024-01-15 |

Khách 1 có hai lần cập nhật cùng ngày 03-05. Khách 3 có lần cập nhật mới nhất (05) nằm **trước** lần cũ hơn (06) trong bảng.

### Thử cách tự nhiên nhất

Tìm ngày cập nhật lớn nhất của mỗi khách, rồi nối ngược lại để lấy email:

```sql
SELECT u.customer_id, u.update_id, u.email
FROM email_updates u
JOIN (SELECT customer_id, MAX(updated_at) AS mx FROM email_updates GROUP BY customer_id) m
  ON m.customer_id = u.customer_id AND m.mx = u.updated_at;
```

| customer_id | update_id | email |
| --- | --- | --- |
| 1 | 2 | <span class="drop">alice@work.com</span> |
| 1 | 3 | alice@new.com |
| ... | | |

Khách 1 ra **hai dòng**, vì có hai lần cập nhật cùng ngày lớn nhất. Đề cần đúng một email mỗi khách.

### Cách sửa: `ROW_NUMBER` với cột phân định thứ tự

"Đúng một dòng mỗi nhóm" là việc của `ROW_NUMBER`. Thêm `update_id DESC` vào `ORDER BY` để khi cùng ngày thì lần có id lớn hơn đứng trước:

```sql
SELECT customer_id, update_id, email
FROM (
  SELECT customer_id, update_id, email,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC, update_id DESC) AS rn
  FROM email_updates
) t
WHERE rn = 1
ORDER BY customer_id;
```

| customer_id | update_id | email |
| --- | --- | --- |
| 1 | 3 | alice@new.com |
| 2 | 4 | ben@mail.com |
| 3 | 5 | chloe@a.com |

Nếu thiếu `update_id DESC`, hai dòng ngày 03-05 bằng nhau và `ROW_NUMBER` có thể chọn bất kỳ dòng nào. Kết quả có thể khác nhau giữa các lần chạy.

PostgreSQL có cách viết gọn cho "mỗi nhóm lấy một dòng" là `DISTINCT ON`: giữ dòng **đầu tiên** của mỗi `customer_id` theo thứ tự của `ORDER BY`. `ORDER BY` phải bắt đầu bằng đúng các cột trong `DISTINCT ON`:

```sql
SELECT DISTINCT ON (customer_id) customer_id, update_id, email
FROM email_updates
ORDER BY customer_id, updated_at DESC, update_id DESC;
```

Cho cùng kết quả. `DISTINCT ON` luôn lấy đúng một dòng, giống `ROW_NUMBER = 1`. Nếu đề muốn lấy **hết** các dòng bằng nhau, vẫn phải dùng `RANK`.

> [!TIP]
> **Ghi nhớ:** "bản ghi mới nhất mỗi nhóm" thì dùng `ROW_NUMBER() ... = 1` hoặc `DISTINCT ON`, và luôn thêm một cột phân định thứ tự (như id) vào `ORDER BY`.

## V3. Khi không được dùng hàm cửa sổ

Đề: **người lương cao nhất của mỗi phòng** (bằng nhau thì lấy hết), nhưng **cấm dùng hàm cửa sổ** (không được viết `OVER`). Đây là dạng hay gặp khi phỏng vấn.

### Thử cách tự nhiên nhất

So lương mỗi người với lương lớn nhất:

```sql
SELECT e.department, e.name, e.salary
FROM employees e
WHERE e.salary = (SELECT MAX(x.salary) FROM employees x);
```

Chỉ ra Alice và Ben. Truy vấn con tìm lương lớn nhất của **cả công ty** (90), nên chỉ phòng Engineering có người khớp.

### Cách sửa: truy vấn con tương quan

Truy vấn con phải tìm lương lớn nhất **của chính phòng đang xét**. Thêm điều kiện `x.department = e.department`, trong đó `e` là dòng của câu bên ngoài. Truy vấn con giờ được chạy lại cho từng nhân viên, với phòng ban của nhân viên đó. Kiểu truy vấn con này gọi là **tương quan** (correlated):

```sql
SELECT e.department, e.name, e.salary
FROM employees e
WHERE e.salary = (SELECT MAX(x.salary) FROM employees x WHERE x.department = e.department)
ORDER BY e.department, e.name;
```

| department | name | salary |
| --- | --- | --- |
| Engineering | Alice | 90 |
| Engineering | Ben | 90 |
| Marketing | Kate | 75 |
| Sales | Emma | 60 |
| Support | Ivy | 55 |

Người bằng nhau tự được giữ hết, vì cả Alice và Ben đều bằng lương lớn nhất của phòng. Jack (lương `NULL`) tự bị loại: `MAX` bỏ qua `NULL`, và `NULL = 55` không bao giờ đúng.

> [!TIP]
> **Ghi nhớ:** không có hàm cửa sổ thì so mỗi dòng với `(SELECT MAX(...) FROM bảng x WHERE x.nhóm = e.nhóm)`. Nhớ điều kiện tương quan, nếu không sẽ so với giá trị lớn nhất của cả bảng.
