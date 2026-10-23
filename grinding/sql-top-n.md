# Top N mỗi nhóm

> Bài liên quan: `topn/01`–`05`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** trong mỗi nhóm, lấy N dòng đứng đầu. Ví dụ: 2 người lương cao nhất mỗi phòng, email mới nhất của mỗi khách, lương cao thứ hai.

**Vì sao `ORDER BY ... LIMIT N` không dùng được:** `LIMIT` cắt trên **cả bảng**, không cắt theo từng nhóm. Ta cần đánh số lại từ 1 trong mỗi nhóm, rồi lọc theo số đó.

Ba bước:

1. Chọn hàm xếp hạng theo cách đề xử lý đồng hạng
2. Xếp hạng trong từng nhóm
3. Lọc hạng ở tầng ngoài

Ví dụ chạy xuyên suốt dùng bảng `employees`:

| emp_id | name | department | salary |
| --- | --- | --- | --- |
| 1 | A | IT | 500 |
| 2 | B | IT | 500 |
| 3 | C | IT | 400 |
| 4 | D | IT | 300 |
| 5 | E | HR | 300 |
| 6 | F | HR | 200 |
| 7 | G | HR | 200 |
| 8 | H | HR | 100 |
| 9 | I | Sales | 900 |

---

## B1. Chọn hàm xếp hạng theo cách đề xử lý đồng hạng

- **Vấn đề:** A và B cùng lương 500. Họ có cùng hạng không? Người đứng sau họ được hạng 2 hay hạng 3?
- **Tại sao:** ba hàm xếp hạng chỉ khác nhau đúng ở chỗ này:

| Đề nói | Hàm | IT: 500, 500, 400, 300 |
| --- | --- | --- |
| "đúng N dòng", "bản ghi mới nhất" | `ROW_NUMBER` + cột tách hòa | 1, 2, 3, 4 |
| "top N, đồng hạng thì lấy hết" | `RANK` | 1, 1, 3, 4 |
| "N mức lương cao nhất", "lương cao thứ N" | `DENSE_RANK` | 1, 1, 2, 3 |

## B2. Xếp hạng trong từng nhóm

- **Vấn đề:** mỗi phòng ban phải được đánh số lại từ 1.
- **Tại sao:**
  - `PARTITION BY department` để bắt đầu đánh số lại ở mỗi phòng ban.
  - `ORDER BY salary DESC` để người lương cao nhất đứng đầu.
  - PostgreSQL coi `NULL` lớn hơn mọi giá trị, nên với `DESC` thì `NULL` đứng **đầu**. Không xử lý thì nhân viên chưa có lương sẽ nhận hạng 1. Cách sửa: lọc `WHERE salary IS NOT NULL`, hoặc viết `ORDER BY salary DESC NULLS LAST`.

Ví dụ HR, nhân viên E có lương `NULL` (dữ liệu `topn/04`):

| department | name | salary | rnk |
| --- | --- | --- | --- |
| HR | E | NULL | **1** |
| HR | D | 300 | 2 |

```sql
SELECT department, name, salary,
       ROW_NUMBER() OVER w AS rn, RANK() OVER w AS rnk, DENSE_RANK() OVER w AS drnk
FROM employees
WHERE salary IS NOT NULL
WINDOW w AS (PARTITION BY department ORDER BY salary DESC)
```

| department | name | salary | rn | rnk | drnk |
| --- | --- | --- | --- | --- | --- |
| HR | E | 300 | 1 | 1 | 1 |
| HR | F | 200 | 2 | 2 | 2 |
| HR | G | 200 | 3 | 2 | 2 |
| HR | H | 100 | 4 | 4 | 3 |
| IT | A | 500 | 1 | 1 | 1 |
| IT | B | 500 | 2 | 1 | 1 |
| IT | C | 400 | 3 | 3 | 2 |
| IT | D | 300 | 4 | 4 | 3 |
| Sales | I | 900 | 1 | 1 | 1 |

Khi dùng `ROW_NUMBER`, hãy thêm cột tách hòa vào `ORDER BY` (ví dụ `snapshot_id DESC`). Nếu không, hai dòng bằng nhau có thể đổi chỗ cho nhau giữa các lần chạy.

## B3. Lọc hạng ở tầng ngoài

- **Vấn đề:** cần lọc `rnk <= 2`.
- **Tại sao:** window function chạy **sau** `WHERE`, nên viết `WHERE RANK() OVER (...) <= 2` sẽ báo lỗi `window functions are not allowed in WHERE`. Phải tính hạng ở một subquery hoặc CTE, rồi lọc ở tầng ngoài.

```sql
SELECT department, name, salary
FROM (
  SELECT department, name, salary,
         RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rnk
  FROM employees WHERE salary IS NOT NULL
) t
WHERE rnk <= 2;
```

| department | name | salary |
| --- | --- | --- |
| HR | E | 300 |
| HR | F | 200 |
| HR | G | 200 |
| IT | A | 500 |
| IT | B | 500 |
| Sales | I | 900 |

- HR có 3 người vì F và G cùng đứng hạng 2.
- IT chỉ có A và B. C đứng hạng 3, vì `RANK` bỏ qua hạng 2.

## Tổng kết: query đầy đủ

Ghép B1 → B3 thành một câu (top 2 mỗi phòng, đồng hạng lấy hết):

```sql
WITH ranked AS (                                   -- B1 + B2: chọn RANK, xếp hạng trong từng phòng
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

| department | name | salary |
| --- | --- | --- |
| HR | E | 300 |
| HR | F | 200 |
| HR | G | 200 |
| IT | A | 500 |
| IT | B | 500 |
| Sales | I | 900 |


---

**Khi chỉ cần 1 dòng mỗi nhóm:** PostgreSQL có cách viết gọn là `DISTINCT ON`.
- `ORDER BY` phải bắt đầu bằng đúng các cột trong `DISTINCT ON`.
- Cách này lấy đúng 1 dòng, giống `ROW_NUMBER = 1`. Nếu đề muốn lấy hết các dòng đồng hạng thì vẫn phải dùng `RANK`.

```sql
SELECT DISTINCT ON (account_id) account_id, snapshot_id, balance
FROM balance_snapshots
ORDER BY account_id, snapshot_date DESC, snapshot_id DESC;
```

| account_id | snapshot_id | balance |
| --- | --- | --- |
| 10 | 3 | 175 |
| 20 | 4 | 300 |
| 30 | 5 | 50 |

**Khi không được dùng window function:**
- So mỗi dòng với giá trị lớn nhất của chính nhóm đó, bằng một subquery tương quan. Các dòng đồng hạng tự được giữ hết.
- `MAX` bỏ qua `NULL`, và `NULL = ...` không bao giờ đúng, nên nhân viên chưa có lương tự bị loại.

```sql
SELECT e.department, e.name, e.salary
FROM employees e
WHERE e.salary = (SELECT MAX(x.salary) FROM employees x WHERE x.department = e.department);
```

| department | name | salary |
| --- | --- | --- |
| HR | D | 300 |
| IT | A | 500 |
| IT | B | 500 |
| Sales | F | 700 |
