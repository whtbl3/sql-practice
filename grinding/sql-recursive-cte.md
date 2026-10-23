# Recursive CTE: cây và đồ thị

> Bài liên quan: `recursive/01`, `02`, `graph/01`–`05`. Output và thông báo lỗi đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** đi theo các liên kết **không biết trước bao nhiêu bước**. Ví dụ: cấp dưới của cấp dưới, từ ga này đi tới được những ga nào và mất mấy chặng, những tài khoản nào nối với nhau, tiền có chạy vòng không.

**Vì sao `JOIN` thường không đủ:** mỗi `JOIN` chỉ đi thêm đúng một bước. Đi 2 bước thì viết 2 `JOIN`, nhưng số bước lại phụ thuộc dữ liệu. Recursive CTE là một **vòng lặp**:
- Phần neo cho ra các dòng đầu tiên.
- Mỗi vòng, phần đệ quy chỉ nhìn **các dòng vừa sinh ở vòng trước** và sinh ra dòng mới.
- Vòng lặp **dừng khi một vòng không sinh ra dòng nào**.

```sql
WITH RECURSIVE r AS (
  SELECT ...                    -- B1 neo
  UNION ALL
  SELECT ... FROM r JOIN ...    -- B2 bước đi, B3 điều kiện dừng
)
SELECT ... FROM r ...;          -- B4 gom kết quả
```

Bốn bước:

1. Neo: đi từ đâu
2. Bước đi: từ một dòng sinh ra những dòng nào
3. Điều kiện dừng
4. Gom kết quả bên ngoài CTE

Ví dụ chạy xuyên suốt: 5 ga tàu (`stations` gồm 1–5) và các tuyến nối giữa chúng. Tuyến **vô hướng**, có vòng 1–2–3. Ga 5 không nối với ga nào.

| a | b |
| --- | --- |
| 1 | 2 |
| 2 | 3 |
| 3 | 1 |
| 3 | 4 |

---

## B1. Neo: đi từ đâu

- **Vấn đề:** cần chọn những dòng bắt đầu của vòng lặp.
- **Tại sao:**
  - Đi từ **một điểm** (ví dụ ga 1): neo có một dòng.
  - Tính cho **mọi điểm xuất phát** (ví dụ thành phần liên thông, tổng ngân sách của mọi cây con): neo gồm mọi nút, và mang theo một cột `start_id` không đổi suốt quá trình đi.
  - Neo phải lấy từ **bảng nút**, không lấy từ bảng cạnh. Lấy từ bảng cạnh thì ga 5 (không có tuyến nào) sẽ biến mất.
  - Kiểu cột ở neo phải khớp với phần đệ quy. `SELECT 1, 0` cho ra `integer`, còn cột của bảng là `bigint`, nên báo lỗi `recursive query "walk" column 1 has type integer in non-recursive term but type bigint overall`. Cách sửa: viết `1::bigint`, `'x'::text`, `ARRAY[]::int[]`.

```sql
SELECT 1::bigint AS node, 0 AS hops, ARRAY[1::bigint] AS path          -- một điểm
SELECT station_id AS start_id, station_id AS node FROM stations         -- mọi điểm
```

## B2. Bước đi: từ một dòng sinh ra những dòng nào

- **Vấn đề:** từ ga đang đứng, đi sang các ga kề nó.
- **Tại sao:**
  - Phần đệ quy `JOIN` CTE với bảng cạnh. Mỗi dòng mới mang theo những gì cần dùng sau: số chặng (`hops + 1`) và đường đi (`path || e.v`).
  - Với đồ thị **vô hướng**, chuẩn hóa cạnh thành hai chiều trước, nếu không chỉ đi được theo một chiều. Dùng `UNION` để bỏ luôn các cạnh bị lưu trùng.
  - Với cây, chỉ cần nối theo cột cha: `ON e.manager_id = c.emp_id` để đi xuống, hoặc `ON m.emp_id = c.manager_id` để đi lên.

```sql
edges AS (SELECT a AS u, b AS v FROM links UNION SELECT b, a FROM links)
```

| u | v |
| --- | --- |
| 1 | 2 |
| 1 | 3 |
| 2 | 1 |
| 2 | 3 |
| 3 | 1 |
| 3 | 2 |
| 3 | 4 |
| 4 | 3 |

```sql
SELECT e.v, w.hops + 1, w.path || e.v
FROM walk w JOIN edges e ON e.u = w.node
```

## B3. Điều kiện dừng

- **Vấn đề:** vòng 1–2–3 có chu trình. Không chặn thì 1 → 2 → 3 → 1 → 2 ... sinh dòng mãi mãi. `check.py` báo `Time Limit Exceeded`.
- **Tại sao:** đệ quy dừng khi một vòng không sinh dòng mới. Có bốn cách để đạt được điều đó:

| Cách | Viết | Dùng khi |
| --- | --- | --- |
| Dữ liệu tự hết | `JOIN` không còn dòng khớp | cây, đồ thị có hướng không có chu trình |
| Chặn bằng đường đi | mang mảng `path`, rồi `WHERE e.v <> ALL (w.path)` | có chu trình, và cần biết **đường đi** |
| `UNION` thay `UNION ALL` | dòng đã có thì không được thêm lại | chỉ cần **tập** trạng thái đạt được |
| Giới hạn độ sâu | `WHERE w.hops < N` | chốt an toàn, hoặc đề hỏi "tối đa N bước" |

Chặn bằng đường đi: không quay lại ga đã đi qua trên **chính đường này**.

```sql
WITH RECURSIVE walk(node, hops, path) AS (
  SELECT 1::bigint, 0, ARRAY[1::bigint]
  UNION ALL
  SELECT e.v, w.hops + 1, w.path || e.v
  FROM walk w JOIN edges e ON e.u = w.node
  WHERE e.v <> ALL (w.path)
)
```

| node | hops | path |
| --- | --- | --- |
| 1 | 0 | [1] |
| 2 | 1 | [1, 2] |
| 3 | 1 | [1, 3] |
| 3 | 2 | [1, 2, 3] |
| 2 | 2 | [1, 3, 2] |
| 4 | 2 | [1, 3, 4] |
| 4 | 3 | [1, 2, 3, 4] |

Cách này sinh ra **mọi đường đi đơn** (không ghé lại ga cũ), nên một ga có thể xuất hiện nhiều lần. Trên đồ thị dày, số đường đi tăng rất nhanh.

**Đề hỏi chu trình** (tiền chạy vòng về đúng tài khoản xuất phát): cho phép ghé lại **chỉ điểm xuất phát**, bằng `e.v = w.start OR e.v <> ALL (w.path)`, và không đi tiếp khi đã về tới nhà (`w.node <> w.start`).

## B4. Gom kết quả bên ngoài CTE

- **Vấn đề:** cần số chặng **ít nhất** tới mỗi ga.
- **Tại sao:**
  - Hàm tổng hợp không được phép trong phần đệ quy. Viết `MIN(w.hops)` bên trong sẽ báo lỗi `aggregate functions are not allowed in a recursive query's recursive term`.
  - `LEFT JOIN` với CTE đệ quy cũng không được đặt bên trong CTE.
  - Vì vậy, sinh **mọi trạng thái** trong CTE trước, rồi `GROUP BY` và `MIN`/`MAX` ở truy vấn ngoài. Ở truy vấn ngoài thì dùng `LEFT JOIN` từ bảng nút được, nên ga không tới được vẫn hiện ra.

```sql
SELECT s.station_id, MIN(w.hops) AS hops
FROM stations s LEFT JOIN walk w ON w.node = s.station_id
GROUP BY s.station_id;
```

| station_id | hops |
| --- | --- |
| 1 | 0 |
| 2 | 1 |
| 3 | 1 |
| 4 | 2 |
| 5 | NULL |

**Ít bước nhất hay nhiều bước nhất:**
- Đường ngắn nhất dùng `MIN`.
- Tầng trong sắp xếp topo (học môn nào trước) dùng `MAX`: một môn phải chờ môn tiên quyết **chậm nhất** của nó.

**Thành phần liên thông** (những ga nào nối với nhau): chỉ cần **tập** các cặp (điểm xuất phát, ga tới được), không cần đường đi.
- Dùng `UNION` thì một cặp đã có sẽ không được sinh lại, nên đệ quy tự dừng kể cả khi có chu trình.
- Nhãn của mỗi nhóm là id nhỏ nhất tới được.

```sql
WITH RECURSIVE reach(start_id, node) AS (
  SELECT station_id, station_id FROM stations
  UNION
  SELECT r.start_id, e.v FROM reach r JOIN edges e ON e.u = r.node
)
SELECT start_id AS station_id, MIN(node) AS component_id FROM reach GROUP BY start_id;
```

| station_id | component_id |
| --- | --- |
| 1 | 1 |
| 2 | 1 |
| 3 | 1 |
| 4 | 1 |
| 5 | 5 |

**Khi số bước cố định** (ví dụ bạn của bạn, đúng 2 bước): không cần đệ quy, chỉ cần self-join 2 lần. Nhớ loại chính mình và loại những người đã là bạn trực tiếp.

---

## Tổng kết: query đầy đủ

Ghép B1 → B4 thành một câu:

```sql
WITH RECURSIVE edges AS (                          -- B2: cạnh hai chiều
  SELECT a AS u, b AS v FROM links
  UNION
  SELECT b, a FROM links
),
walk(node, hops, path) AS (
  SELECT 1::bigint, 0, ARRAY[1::bigint]            -- B1: neo tại ga 1
  UNION ALL
  SELECT e.v, w.hops + 1, w.path || e.v            -- B2: đi sang ga kề
  FROM walk w JOIN edges e ON e.u = w.node
  WHERE e.v <> ALL (w.path)                        -- B3: không quay lại ga đã đi
)
SELECT s.station_id, MIN(w.hops) AS hops           -- B4: gom ngoài CTE
FROM stations s
LEFT JOIN walk w ON w.node = s.station_id
GROUP BY s.station_id
ORDER BY s.station_id;
```

| station_id | hops |
| --- | --- |
| 1 | 0 |
| 2 | 1 |
| 3 | 1 |
| 4 | 2 |
| 5 | NULL |
