# Recursive CTE: cây và đồ thị

> Bài liên quan: `recursive/01`, `02`, `graph/01`–`05`. Output và thông báo lỗi đều chạy thật bằng `check.py`.

## Bài toán

Một hệ thống tàu điện có các ga nối với nhau. Đề hỏi: **từ ga Central, đi tới mỗi ga mất ít nhất bao nhiêu chặng?** Ga nào không tới được thì để trống.

Chỗ khó: số chặng **không biết trước**. Mỗi `JOIN` chỉ đi thêm đúng một chặng: đi 2 chặng thì viết 2 `JOIN`, đi 3 chặng thì viết 3 `JOIN`, nhưng bao nhiêu chặng là đủ lại tùy dữ liệu.

**Recursive CTE** là một vòng lặp viết bằng SQL:

```sql
WITH RECURSIVE r AS (
  SELECT ...                    -- phần neo: các dòng đầu tiên
  UNION ALL
  SELECT ... FROM r JOIN ...    -- phần đệ quy: từ các dòng vừa sinh, sinh ra dòng mới
)
SELECT ... FROM r;              -- dùng kết quả
```

Vòng lặp chạy như sau:
1. Chạy phần neo một lần, được các dòng đầu tiên.
2. Mỗi vòng, phần đệ quy chỉ nhìn **các dòng vừa sinh ở vòng trước**, và sinh ra các dòng mới.
3. Vòng lặp **dừng khi một vòng không sinh ra dòng nào**.

## Dữ liệu

`stations`: mỗi dòng = 1 ga.

| station_id | name |
| --- | --- |
| 1 | Central |
| 2 | Harbor |
| 3 | Market |
| 4 | Park |
| 5 | Airport |
| 6 | Lake |

`links`: mỗi dòng = 1 tuyến nối hai ga. Tàu chạy **cả hai chiều**, nhưng mỗi tuyến chỉ lưu một lần (theo chiều nào cũng được).

| a | b |
| --- | --- |
| 1 | 2 |
| 2 | 3 |
| 3 | 1 |
| 3 | 4 |
| 2 | 1 |
| 4 | 6 |

Ba chỗ dễ sai: Central, Harbor, Market **nối thành vòng**, tuyến Central–Harbor bị **lưu hai lần** (1, 2) và (2, 1), và Airport **không nối với ga nào**.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code |
| --- | --- | --- |
| B1 | Chuẩn bị các tuyến theo cả hai chiều | CTE `edges` |
| B2 | Neo: bắt đầu từ đâu | phần trên `UNION ALL` của CTE `walk` |
| B3 | Bước đi và điều kiện dừng | phần dưới `UNION ALL` của CTE `walk` |
| B4 | Gom kết quả bên ngoài CTE | query cuối |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Chuẩn bị các tuyến theo cả hai chiều (CTE `edges`)

**Ý tưởng:** tàu chạy cả hai chiều, nhưng `links` chỉ lưu một chiều. Từ Central (1), ta đi được sang Market (3) qua tuyến (3, 1), nhưng tuyến đó được lưu theo chiều Market → Central. Vì vậy ta tạo một bảng `edges` có **cả hai chiều** của mọi tuyến. `UNION` (không phải `UNION ALL`) bỏ luôn các dòng trùng, như tuyến Central–Harbor đang bị lưu hai lần.

| a, b in `links` | rows in `edges` |
| --- | --- |
| (1, 2) | (1, 2), (2, 1) |
| (2, 1) | (2, 1), (1, 2): <span class="drop">duplicates, removed by UNION</span> |
| (3, 1) | (3, 1), (1, 3) |
| ... | |

```sql
WITH RECURSIVE edges AS (
  SELECT a AS u, b AS v FROM links
  UNION
  SELECT b, a FROM links
)
```

> [!CAUTION]
> ❌ **Dùng thẳng `links` theo một chiều**
>
> Từ Central chỉ đi được sang Harbor (tuyến 1 → 2), rồi từ Harbor sang Market. Market ra 2 chặng thay vì 1, vì tuyến Market–Central chỉ được lưu theo chiều 3 → 1.
>
> → **Sửa:** với đồ thị vô hướng, luôn tạo cả hai chiều bằng `UNION` trước khi đi.

## B2. Neo: bắt đầu từ đâu (phần trên `UNION ALL`)

**Ý tưởng:** phần neo cho ra các dòng của vòng 0. Ở đây ta bắt đầu từ một ga: Central, 0 chặng. Mỗi dòng mang theo những thông tin cần dùng ở các vòng sau: ga đang đứng (`node`), số chặng đã đi (`hops`), và các ga đã đi qua (`path`, một mảng).

```sql
walk(node, hops, path) AS (
  SELECT 1::bigint, 0, ARRAY[1::bigint]
  UNION ALL
  ...
)
```

| node | hops | path |
| --- | --- | --- |
| 1 | 0 | [1] |

> [!CAUTION]
> ❌ **Kiểu dữ liệu của neo khác với phần đệ quy: `SELECT 1, 0`**
>
> ```text
> ERROR:  recursive query "walk" column 1 has type integer in non-recursive term but type bigint overall
> ```
>
> Số `1` viết thẳng có kiểu `integer`, còn cột `station_id` của bảng có kiểu `bigint`. Cột của CTE đệ quy phải cùng một kiểu ở cả hai phần.
>
> → **Sửa:** ép kiểu ở phần neo: `1::bigint`, `ARRAY[1::bigint]`, hoặc `'x'::text` cho cột chữ.

## B3. Bước đi và điều kiện dừng (phần dưới `UNION ALL`)

**Ý tưởng:** từ mỗi dòng vừa sinh, đi sang **các ga kề** của nó: `JOIN edges` theo ga đang đứng. Mỗi dòng mới tăng `hops` thêm 1 và thêm ga mới vào `path`.

Nhưng Central, Harbor, Market nối thành vòng. Nếu không chặn, đường đi 1 → 2 → 3 → 1 → 2 → ... cứ thế sinh dòng mãi. Điều kiện `e.v <> ALL (w.path)` nghĩa là "ga kế tiếp chưa có trong đường đi này": không quay lại ga đã đi qua trên **chính đường đang đi**. Khi mọi đường đi đều hết ga mới, một vòng không sinh dòng nào, và đệ quy dừng.

```sql
walk(node, hops, path) AS (
  SELECT 1::bigint, 0, ARRAY[1::bigint]
  UNION ALL
  SELECT e.v, w.hops + 1, w.path || e.v
  FROM walk w
  JOIN edges e ON e.u = w.node
  WHERE e.v <> ALL (w.path)
)
```

| round | node | hops | path |
| --- | --- | --- | --- |
| 0 | 1 | 0 | [1] |
| 1 | 2 | 1 | [1, 2] |
| 1 | 3 | 1 | [1, 3] |
| 2 | 3 | 2 | [1, 2, 3] |
| 2 | 2 | 2 | [1, 3, 2] |
| 2 | 4 | 2 | [1, 3, 4] |
| 3 | 4 | 3 | [1, 2, 3, 4] |
| 3 | 6 | 3 | [1, 3, 4, 6] |
| 4 | 6 | 4 | [1, 2, 3, 4, 6] |

Cách này sinh ra **mọi đường đi không lặp ga**, nên một ga có thể xuất hiện nhiều lần với số chặng khác nhau. Market có hai dòng: 1 chặng (đi thẳng) và 2 chặng (qua Harbor). B4 sẽ chọn số nhỏ nhất.

> [!CAUTION]
> ❌ **Không có điều kiện dừng khi đồ thị có vòng**
>
> Bỏ `WHERE e.v <> ALL (w.path)`, đường đi chạy vòng quanh Central, Harbor, Market mãi mãi. `check.py` báo `Time Limit Exceeded`.
>
> → **Sửa:** chặn bằng một trong các cách: mang theo `path` và không quay lại ga cũ, giới hạn độ sâu (`WHERE w.hops < N`), hoặc dùng `UNION` thay `UNION ALL` khi chỉ cần tập các ga tới được (xem V3).

## B4. Gom kết quả bên ngoài CTE (query cuối)

**Ý tưởng:** sau khi CTE sinh ra mọi đường đi, lấy số chặng nhỏ nhất của mỗi ga bằng `MIN(hops)`. Đi từ bảng `stations` rồi `LEFT JOIN walk`, để ga không tới được (Airport) vẫn hiện ra với `NULL`.

```sql
SELECT s.station_id, s.name, MIN(w.hops) AS hops
FROM stations s
LEFT JOIN walk w ON w.node = s.station_id
GROUP BY s.station_id, s.name
ORDER BY s.station_id;
```

| station | hops in `walk` | MIN |
| --- | --- | --- |
| Market | 1, 2 | 1 |
| Lake | 3, 4 | 3 |
| Airport | (none) | NULL |
| ... | | |

> [!CAUTION]
> ❌ **Tính `MIN` ngay trong phần đệ quy**
>
> ```text
> ERROR:  aggregate functions are not allowed in a recursive query's recursive term
> ```
>
> PostgreSQL không cho dùng hàm gộp, `GROUP BY` hay `LEFT JOIN` tới chính CTE trong phần đệ quy.
>
> → **Sửa:** sinh mọi trạng thái trong CTE trước, rồi `GROUP BY` và `MIN` / `MAX` ở truy vấn bên ngoài.

## Tổng kết: query đầy đủ

```sql
WITH RECURSIVE edges AS (                          -- B1: tuyến theo cả hai chiều
  SELECT a AS u, b AS v FROM links
  UNION
  SELECT b, a FROM links
),
walk(node, hops, path) AS (
  SELECT 1::bigint, 0, ARRAY[1::bigint]            -- B2: neo tại Central
  UNION ALL
  SELECT e.v, w.hops + 1, w.path || e.v            -- B3: đi sang ga kề
  FROM walk w
  JOIN edges e ON e.u = w.node
  WHERE e.v <> ALL (w.path)                        -- B3: không quay lại ga đã đi
)
SELECT s.station_id, s.name, MIN(w.hops) AS hops   -- B4: gom ngoài CTE
FROM stations s
LEFT JOIN walk w ON w.node = s.station_id
GROUP BY s.station_id, s.name
ORDER BY s.station_id;
```

| station_id | name | hops |
| --- | --- | --- |
| 1 | Central | 0 |
| 2 | Harbor | 1 |
| 3 | Market | 1 |
| 4 | Park | 2 |
| 5 | Airport | NULL |
| 6 | Lake | 3 |

---

# Phần 2: Biến thể

Mỗi biến thể dưới đây đổi một trong bốn bước: neo từ đâu, đi theo hướng nào, dừng thế nào, hay gom kết quả ra sao. Mỗi mục kể một tình huống, thử cách làm quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi đi xuống một cây: đường đi và độ sâu

Cây là trường hợp dễ nhất: mỗi nút có **một cha**, và không có vòng. Đề: với mỗi nhân viên, cho biết **độ sâu** (0 cho người không có quản lý) và **chuỗi quản lý** từ trên xuống, nối bằng `' > '`.

```text
employees (emp_id, name, manager_id)   -- mới; manager_id NULL = không có quản lý
```

| emp_id | name | manager_id |
| --- | --- | --- |
| 1 | Grace | NULL |
| 2 | Henry | 1 |
| 3 | Ivy | 1 |
| 4 | Jack | 2 |
| 5 | Kate | 4 |
| 6 | Leo | NULL |

Có hai gốc: Grace và Leo. Neo là **mọi người không có quản lý**. Bước đi là tìm những người có quản lý là người vừa sinh: `e.manager_id = c.emp_id`. Cây không có vòng, nên đệ quy tự dừng khi không còn ai ở tầng dưới:

```sql
WITH RECURSIVE chain AS (
  SELECT emp_id, name, 0 AS depth, name::text AS path
  FROM employees
  WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.name, c.depth + 1, c.path || ' > ' || e.name
  FROM chain c
  JOIN employees e ON e.manager_id = c.emp_id
)
SELECT name, depth, path FROM chain ORDER BY emp_id;
```

| name | depth | path |
| --- | --- | --- |
| Grace | 0 | Grace |
| Henry | 1 | Grace > Henry |
| Ivy | 1 | Grace > Ivy |
| Jack | 2 | Grace > Henry > Jack |
| Kate | 3 | Grace > Henry > Jack > Kate |
| Leo | 0 | Leo |

Muốn đi **lên** (từ một nhân viên tới sếp cao nhất) thì đảo điều kiện nối: `m.emp_id = c.manager_id`.

> [!TIP]
> **Ghi nhớ:** trên cây, neo là các gốc, bước đi là nối theo cột cha. Cây không có vòng nên không cần điều kiện dừng.

## V2. Khi tính tổng của cả cây con

Đề: mỗi đơn vị có ngân sách riêng. Với **mỗi** đơn vị, tính tổng ngân sách của nó **cộng mọi đơn vị bên dưới** (con, cháu, chắt...).

```text
units (unit_id, name, parent_id, budget)   -- mới
```

| unit_id | name | parent_id | budget |
| --- | --- | --- | --- |
| 1 | Company | NULL | 100 |
| 2 | Retail | 1 | 40 |
| 3 | Online | 1 | 60 |
| 4 | North | 2 | 25 |
| 5 | South | 2 | 15 |
| 6 | App | 3 | 30 |
| 7 | Web | 3 | 20 |

### Thử cách tự nhiên nhất

Cộng ngân sách của đơn vị với các **con trực tiếp** của nó (một lần `JOIN` theo `parent_id`). Company ra 100 + 40 + 60 = **200**, thiếu ngân sách của North, South, App, Web, vốn là cháu chứ không phải con. Cây sâu bao nhiêu tầng thì phải `JOIN` bấy nhiêu lần.

### Cách sửa: neo tại mọi nút, mang theo điểm xuất phát

Ta cần đi xuống từ **mọi đơn vị**, không chỉ từ gốc. Neo là **mọi đơn vị**, và mỗi dòng mang theo một cột `start_id` không đổi trong suốt quá trình đi. Mỗi dòng của CTE nghĩa là "`unit_id` nằm trong cây con của `start_id`":

```sql
WITH RECURSIVE sub(start_id, unit_id) AS (
  SELECT unit_id, unit_id FROM units
  UNION ALL
  SELECT s.start_id, u.unit_id
  FROM sub s
  JOIN units u ON u.parent_id = s.unit_id
)
SELECT top.name, SUM(u.budget) AS total_budget
FROM sub s
JOIN units top ON top.unit_id = s.start_id
JOIN units u   ON u.unit_id   = s.unit_id
GROUP BY top.unit_id, top.name
ORDER BY top.unit_id;
```

| start | units in its subtree | total_budget |
| --- | --- | --- |
| Company | all 7 | 290 |
| Retail | Retail, North, South | 80 |
| Online | Online, App, Web | 110 |
| North | North | 25 |
| ... | | |

> [!TIP]
> **Ghi nhớ:** tính cho **mọi** điểm xuất phát thì neo tại mọi nút và mang theo cột `start_id`, rồi `GROUP BY start_id` ở ngoài.

## V3. Khi tìm các nhóm liên thông

Một ví điện tử liên kết hai tài khoản khi chúng dùng chung thiết bị hoặc số điện thoại. Hai tài khoản cùng **nhóm** khi có một chuỗi liên kết nối chúng (trực tiếp hoặc qua tài khoản khác). Đề: liệt kê các nhóm. Mã nhóm là id nhỏ nhất trong nhóm.

```text
accounts      (account_id)               -- mới; tài khoản 1 đến 8
account_links (account_a, account_b)     -- mới; vô hướng
```

| account_a | account_b |
| --- | --- |
| 1 | 2 |
| 3 | 2 |
| 4 | 5 |
| 5 | 6 |
| 6 | 4 |
| 7 | 7 |

Tài khoản 4, 5, 6 nối thành vòng. Tài khoản 7 liên kết với chính nó. Tài khoản 8 không có liên kết nào.

Ở đây ta không cần **đường đi**, chỉ cần **tập** các cặp (điểm xuất phát, tài khoản tới được). Thay `UNION ALL` bằng `UNION`: một cặp đã có rồi sẽ không được thêm lại. Khi một vòng chỉ sinh ra các cặp đã có, vòng đó không thêm được dòng nào, và đệ quy dừng, kể cả khi có vòng.

```sql
WITH RECURSIVE edges AS (
  SELECT account_a AS u, account_b AS v FROM account_links
  UNION
  SELECT account_b, account_a FROM account_links
),
reach(start_id, node) AS (
  SELECT account_id, account_id FROM accounts
  UNION
  SELECT r.start_id, e.v FROM reach r JOIN edges e ON e.u = r.node
),
labels AS (
  SELECT start_id AS account_id, MIN(node) AS component_id FROM reach GROUP BY start_id
)
SELECT component_id, COUNT(*) AS size, STRING_AGG(account_id::text, ', ' ORDER BY account_id) AS members
FROM labels
GROUP BY component_id
ORDER BY component_id;
```

| component_id | size | members |
| --- | --- | --- |
| 1 | 3 | 1, 2, 3 |
| 4 | 3 | 4, 5, 6 |
| 7 | 1 | 7 |
| 8 | 1 | 8 |

Neo lấy từ bảng `accounts`, không từ bảng liên kết, nên tài khoản 8 (không có liên kết nào) vẫn có nhóm riêng.

> [!CAUTION]
> ❌ **Dùng `UNION ALL` trong `reach`**
>
> Không có `path` để chặn, và `UNION ALL` không bỏ dòng trùng. Từ tài khoản 4, các cặp (4, 5), (4, 6), (4, 4), (4, 5)... được sinh lại mãi quanh vòng 4–5–6. `check.py` báo `Time Limit Exceeded`.
>
> → **Sửa:** khi chỉ cần tập trạng thái, dùng `UNION`.

> [!TIP]
> **Ghi nhớ:** chỉ cần biết "tới được hay không" thì dùng `UNION` thay `UNION ALL`. Dòng trùng bị bỏ, và đệ quy tự dừng kể cả trên đồ thị có vòng.

## V4. Khi tìm chu trình

Một hệ thống chống rửa tiền tìm dòng tiền chạy vòng về chỗ cũ. Đề: những tài khoản nào nằm trên một **chu trình** (đi theo các giao dịch từ nó có thể quay về chính nó), và chu trình **ngắn nhất** qua nó dài bao nhiêu bước?

```text
transfers (from_acc, to_acc)   -- mới; có hướng
```

| from_acc | to_acc |
| --- | --- |
| A | B |
| B | C |
| C | A |
| C | D |
| D | C |
| E | E |
| F | G |

A → B → C → A là một vòng 3 bước. C ↔ D là một vòng 2 bước. E chuyển cho chính mình (vòng 1 bước). F → G không quay lại.

### Thử điều kiện dừng của mạch chính

Đi từ mỗi tài khoản, chặn bằng `t.to_acc <> ALL (w.path)` như B3. Kết quả ra **0 dòng**. Để khép một vòng, bước cuối phải quay về **chính điểm xuất phát**, mà điểm xuất phát đã nằm trong `path` từ đầu, nên bước đó luôn bị chặn.

### Cách sửa: cho phép quay về điểm xuất phát, rồi dừng

Cho phép đi tới tài khoản chưa có trong `path`, **hoặc** đúng tài khoản xuất phát. Khi đã về tới nhà, không đi tiếp nữa:

```sql
WITH RECURSIVE walk(start_acc, node, steps, path) AS (
  SELECT DISTINCT from_acc, from_acc, 0, ARRAY[from_acc]
  FROM transfers
  UNION ALL
  SELECT w.start_acc, t.to_acc, w.steps + 1, w.path || t.to_acc
  FROM walk w
  JOIN transfers t ON t.from_acc = w.node
  WHERE (w.node <> w.start_acc OR w.steps = 0)                     -- về tới nhà thì dừng
    AND (t.to_acc = w.start_acc OR t.to_acc <> ALL (w.path))       -- được về nhà, không lặp chỗ khác
)
SELECT start_acc AS account, MIN(steps) AS cycle_len
FROM walk
WHERE node = start_acc AND steps > 0
GROUP BY start_acc
ORDER BY start_acc;
```

Các đường đi từ C:

| steps | path | back at C? |
| --- | --- | --- |
| 1 | C, A | |
| 1 | C, D | |
| 2 | C, D, C | **yes**, length 2 |
| 2 | C, A, B | |
| 3 | C, A, B, C | **yes**, length 3 |

| account | cycle_len |
| --- | --- |
| A | 3 |
| B | 3 |
| C | 2 |
| D | 2 |
| E | 1 |

C nằm trên cả hai vòng. `MIN(steps)` chọn vòng ngắn hơn. F và G không có dòng nào quay về chính mình, nên không xuất hiện. `w.steps = 0` cho phép dòng neo (đang đứng ở nhà) vẫn được đi bước đầu tiên.

> [!TIP]
> **Ghi nhớ:** tìm chu trình thì cho phép quay lại **chỉ điểm xuất phát** (`to = start OR to <> ALL (path)`), và dừng khi đã về tới nhà.

## V5. Khi xếp thứ tự theo điều kiện tiên quyết

Một khóa học dữ liệu có các môn phải học trước. Đề: **mức** của mỗi môn là 0 nếu không có môn tiên quyết, ngược lại là 1 + mức **cao nhất** trong các môn tiên quyết của nó. Như vậy môn nào cũng đứng sau mọi môn tiên quyết.

```text
courses       (course_id, name)          -- mới
prerequisites (course_id, prereq_id)     -- mới; course_id cần học prereq_id trước
```

| course_id | name | prerequisites |
| --- | --- | --- |
| 1 | SQL | |
| 2 | Python | |
| 3 | Advanced SQL | 1 |
| 4 | Pandas | 2 |
| 5 | Analytics | 3, 4 |
| 6 | Statistics | |
| 7 | Machine Learning | 5, 6, 2 |

Neo là các môn không có môn tiên quyết, mức 0. Bước đi là sang các môn cần môn vừa sinh. Một môn có nhiều đường để tới: Machine Learning tới được qua Python trực tiếp (mức 1), qua Statistics (mức 1), hoặc qua Analytics (mức 3).

```sql
WITH RECURSIVE lvl(course_id, level) AS (
  SELECT c.course_id, 0
  FROM courses c
  WHERE NOT EXISTS (SELECT 1 FROM prerequisites p WHERE p.course_id = c.course_id)
  UNION ALL
  SELECT p.course_id, l.level + 1
  FROM lvl l
  JOIN prerequisites p ON p.prereq_id = l.course_id
)
SELECT c.course_id, c.name, MAX(l.level) AS level
FROM courses c
JOIN lvl l ON l.course_id = c.course_id
GROUP BY c.course_id, c.name
ORDER BY level, c.course_id;
```

| course_id | name | level |
| --- | --- | --- |
| 1 | SQL | 0 |
| 2 | Python | 0 |
| 6 | Statistics | 0 |
| 3 | Advanced SQL | 1 |
| 4 | Pandas | 1 |
| 5 | Analytics | 2 |
| 7 | Machine Learning | 3 |

Ở mạch chính, ta lấy `MIN` vì muốn đường **ngắn nhất**. Ở đây phải lấy `MAX`: Machine Learning phải chờ môn tiên quyết **chậm nhất** của nó (Analytics, mức 2). Lấy `MIN` thì Machine Learning ra mức 1, tức học cùng lúc với Advanced SQL, trước cả Analytics.

> [!TIP]
> **Ghi nhớ:** thứ tự theo điều kiện tiên quyết là **đường dài nhất** từ gốc: gom bằng `MAX`, không phải `MIN`.

## V6. Khi số bước cố định: bạn của bạn

Đề: gợi ý kết bạn cho Alice (user 1): mọi người cách Alice **đúng 2 bước** (là bạn của một người bạn của Alice), không phải chính Alice, và chưa là bạn của Alice. Kèm theo **số bạn chung**.

```text
users       (user_id, name)        -- mới
friendships (user_a, user_b)       -- mới; vô hướng, có cặp bị lưu hai lần
```

| user_a | user_b |
| --- | --- |
| 1 | 2 |
| 3 | 1 |
| 1 | 4 |
| 2 | 5 |
| 3 | 5 |
| 4 | 6 |
| 2 | 3 |
| 6 | 7 |
| 2 | 1 |

Users: 1 Alice, 2 Ben, 3 Chloe, 4 David, 5 Emma, 6 Frank, 7 Grace.

Số bước **biết trước** (đúng 2), nên không cần đệ quy: nối bảng cạnh với chính nó hai lần là đủ. Bạn của Alice là `f1.v` (với `f1.u = 1`), bạn của họ là `f2.v`:

```sql
WITH edges AS (
  SELECT user_a AS u, user_b AS v FROM friendships
  UNION
  SELECT user_b, user_a FROM friendships
)
SELECT f2.v AS user_id, us.name, COUNT(DISTINCT f1.v) AS mutual_friends
FROM edges f1
JOIN edges f2 ON f2.u = f1.v
JOIN users us ON us.user_id = f2.v
WHERE f1.u = 1
  AND f2.v <> 1
  AND NOT EXISTS (SELECT 1 FROM edges d WHERE d.u = 1 AND d.v = f2.v)
GROUP BY f2.v, us.name
ORDER BY mutual_friends DESC, user_id;
```

| candidate | reached via (Alice's friends) | kept? |
| --- | --- | --- |
| Alice | Ben, Chloe, David | no (herself) |
| Ben | Chloe | no (already a friend) |
| Chloe | Ben | no (already a friend) |
| Emma | Ben, Chloe | **yes**, 2 mutual |
| Frank | David | **yes**, 1 mutual |

| user_id | name | mutual_friends |
| --- | --- | --- |
| 5 | Emma | 2 |
| 6 | Frank | 1 |

Hai điều kiện `f2.v <> 1` và `NOT EXISTS (...)` loại chính Alice và những người đã là bạn. `UNION` trong `edges` bỏ cặp (1, 2) bị lưu hai lần. Nếu dùng `UNION ALL`, Ben xuất hiện hai lần trong danh sách bạn của Alice, và `COUNT(*)` cho Emma ra 3 bạn chung thay vì 2. `COUNT(DISTINCT f1.v)` là chốt an toàn thứ hai.

> [!TIP]
> **Ghi nhớ:** số bước cố định thì nối bảng cạnh với chính nó đúng số lần đó, không cần đệ quy. Nhớ loại chính mình và những người đã nối trực tiếp.
