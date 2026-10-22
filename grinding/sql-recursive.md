# Recursive CTE: cây, đồ thị và quy hoạch động trong SQL

> Phương ngữ: **PostgreSQL 16** (đúng engine của `check.py`). Mọi query, output và thông báo lỗi dưới đây đã **chạy thật bằng `check.py`**.
> Cách học: nắm phần 1 (giải phẫu recursive CTE và 4 giới hạn của nó) → mỗi bài đồ thị / DP chỉ là một cách chọn **trạng thái** và **bước đi**.
> Bẫy chung (NULL, chia số nguyên, frame của window) nằm ở [sql-common-pitfalls.md](sql-common-pitfalls.md); tài liệu này trỏ tới bằng mã mục (A2, E1, F2…).

**Mục lục**

| Phần | Nội dung | Bài tập |
| --- | --- | --- |
| 1 | Giải phẫu recursive CTE, dừng đệ quy, giới hạn, cây | `recursive/01`, `02` |
| 2 | Đồ thị: bạn của bạn, BFS, thành phần liên thông, chu trình, sắp xếp topo | `graph/01`–`05` |
| 3 | Quy hoạch động: nước mưa, Kadane, house robber, đổi tiền, knapsack | `dp/01`–`05` |

---

## Phần 1. Giải phẫu recursive CTE

### 1.1 Khung và cách nó chạy

```sql
WITH RECURSIVE r(cot1, cot2) AS (
  SELECT ...                     -- (1) phần NEO: chạy một lần, cho ra "thế hệ 0"
  UNION ALL                      -- hoặc UNION (khử trùng, xem 1.2)
  SELECT ... FROM r JOIN ...     -- (2) phần ĐỆ QUY: chạy trên các dòng MỚI của lần trước
)
SELECT ... FROM r;
```

PostgreSQL không thật sự "gọi đệ quy". Nó chạy **vòng lặp**: phần neo cho tập làm việc đầu tiên; mỗi vòng, phần đệ quy chỉ nhìn **các dòng sinh ra ở vòng trước** và sinh ra dòng mới; vòng lặp **dừng khi một vòng không sinh dòng nào**. Kết quả là hợp của mọi vòng.

Vì vậy mọi bài trong tài liệu này đều trả lời hai câu:

1. **Trạng thái** là gì (mỗi dòng của `r` mang những cột nào)?
2. **Bước đi** là gì (từ một dòng sinh ra các dòng nào)? Và **khi nào hết dòng mới** để dừng?

### 1.2 Bốn cách để đệ quy dừng lại

| Cách | Viết thế nào | Dùng khi |
| --- | --- | --- |
| Dữ liệu tự hết | `JOIN` không còn dòng khớp (lá của cây, hết phần tử) | Cây, DAG, duyệt danh sách theo chỉ số (3.4, 3.6) |
| Chặn bằng đường đi | Mang theo mảng `path`, điều kiện `WHERE e.v <> ALL (w.path)` | Đồ thị có chu trình, cần **đường đi** (2.2, 2.4) |
| `UNION` thay `UNION ALL` | Dòng đã có thì không thêm lại → hết dòng mới | Chỉ cần **tập** trạng thái đạt được, không cần đường đi (2.3, 3.5) |
| Giới hạn độ sâu | Cột `d` + `WHERE r.d < N` | Chốt an toàn, hoặc đề hỏi "tối đa N bước" |

PostgreSQL 14+ còn có mệnh đề **`CYCLE`** tự mang đường đi và đánh dấu chu trình:

```sql
WITH RECURSIVE r(n, d) AS (
  SELECT 1::bigint, 0
  UNION ALL
  SELECT e.v, r.d + 1 FROM r JOIN e ON e.u = r.n
) CYCLE n SET is_cycle USING path
SELECT n, d, is_cycle, path FROM r;
```

| n | d | is_cycle | path |
| --- | --- | --- | --- |
| 1 | 0 | False | {(1)} |
| 2 | 1 | False | {(1),(2)} |
| 3 | 2 | False | {(1),(2),(3)} |
| 1 | 3 | True | {(1),(2),(3),(1)} |

Dòng quay lại nút cũ được giữ với `is_cycle = true` nhưng **không được mở rộng tiếp**. Mảng `path` tự viết (`ARRAY[...] || x`) thì chạy trên mọi phiên bản và dễ đọc hơn khi đi phỏng vấn.

### 1.3 Bốn giới hạn phải nhớ (kèm thông báo lỗi thật)

1. **Kiểu cột ở phần neo phải khớp phần đệ quy.** `SELECT 0, 0` là `integer`, còn cột bảng trong `check.py` là `bigint`:
   `recursive query "r" column 1 has type integer in non-recursive term but type bigint overall` → viết `0::bigint`, `'x'::text`, `ARRAY[]::int[]`.
2. **Không có hàm tổng hợp trong phần đệ quy**: `aggregate functions are not allowed in a recursive query's recursive term`. Muốn "đường ngắn nhất" thì sinh **mọi** trạng thái rồi `MIN` / `MAX` **bên ngoài** CTE (2.2, 2.5, 3.5).
3. **Không đặt CTE đệ quy ở phía có thể NULL của outer join**: `recursive reference to query "r" must not appear within an outer join`. Dùng `JOIN`; nếu cần "giữ cả dòng không khớp" thì làm ở truy vấn ngoài.
4. **Phần đệ quy chỉ được nhắc tên CTE một lần.** Muốn rẽ hai nhánh (lấy / bỏ) thì nhân dòng bằng `CROSS JOIN (VALUES (TRUE), (FALSE)) AS t(take)` thay vì `UNION` hai lần (3.6).

### 1.4 Cây: đi xuống và mang theo đường đi (`recursive/02`)

Cây không có chu trình nên **dữ liệu tự hết**: neo là gốc (`manager_id IS NULL`), mỗi vòng đi xuống một tầng, lá không có con nên dừng.

```sql
WITH RECURSIVE chain AS (
  SELECT emp_id, name, 0 AS depth, name::text AS path          -- ::text: path sẽ dài ra, kiểu phải khớp
  FROM employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.name, c.depth + 1, c.path || ' > ' || e.name
  FROM employees e JOIN chain c ON e.manager_id = c.emp_id
)
SELECT name, depth, path FROM chain;
```

Muốn đi **lên** (từ nhân viên tới sếp cao nhất) thì đảo điều kiện nối: `JOIN employees m ON m.emp_id = c.manager_id`.

### 1.5 Cây: tổng cây con của mọi nút (`recursive/01`)

Neo là **mọi nút** (mỗi nút là gốc của cây con của nó), mang theo `root_id` không đổi trong suốt quá trình đi xuống:

```sql
WITH RECURSIVE tree AS (
  SELECT unit_id AS root_id, unit_id FROM units
  UNION ALL
  SELECT t.root_id, u.unit_id FROM tree t JOIN units u ON u.parent_id = t.unit_id
)
SELECT r.name, SUM(u.budget) AS total_budget
FROM tree t
JOIN units r ON r.unit_id = t.root_id
JOIN units u ON u.unit_id = t.unit_id
GROUP BY r.unit_id, r.name;
```

Mẹo "cột mang theo không đổi" (`root_id`, `start_id`, `start_acc`) dùng lại ở 2.3 và 2.4: muốn tính cho **mọi điểm xuất phát** thì đưa tất cả vào neo và mang điểm xuất phát theo.

---

## Phần 2. Đồ thị

### 2.0 Chuẩn bị cạnh

Đồ thị **vô hướng** lưu mỗi cạnh một lần (chiều nào cũng được, có khi lưu trùng). Luôn chuẩn hóa thành hai chiều trước:

```sql
edges AS (
  SELECT a AS u, b AS v FROM links
  UNION                                -- UNION: khử luôn cạnh lưu trùng hoặc lưu cả hai chiều
  SELECT b, a FROM links
)
```

Đồ thị **có hướng** (chuyển tiền, môn tiên quyết) thì giữ nguyên chiều, nhưng vẫn `DISTINCT` nếu một cặp có thể xuất hiện nhiều lần (2.4).

| Bài | Trạng thái | Dừng bằng | Kết quả lấy bằng | Mục |
| --- | --- | --- | --- | --- |
| Bạn của bạn | (không cần đệ quy) | | Self-join 2 bước, `COUNT(DISTINCT)` | 2.1 |
| Ít bước nhất | (nút, số bước, đường đi) | `path` | `MIN(số bước)` theo nút | 2.2 |
| Thành phần liên thông | (điểm xuất phát, nút) | `UNION` | `MIN(nút)` theo điểm xuất phát | 2.3 |
| Chu trình | (điểm xuất phát, nút, độ dài, đường đi) | `path` + dừng khi về nhà | `MIN(độ dài) WHERE nút = điểm xuất phát` | 2.4 |
| Thứ tự topo | (nút, độ sâu) | DAG tự hết | `MAX(độ sâu)` theo nút | 2.5 |

### 2.1 Bạn của bạn (`graph/01`)

Số bước **cố định** (2) thì không cần đệ quy, chỉ cần self-join hai lần:

```sql
WITH edges AS (SELECT user_a AS u, user_b AS v FROM friendships
               UNION SELECT user_b, user_a FROM friendships),
friends AS (SELECT v AS f FROM edges WHERE u = 1)
SELECT e.v AS user_id, COUNT(DISTINCT e.u) AS mutual_friends
FROM friends fr
JOIN edges e ON e.u = fr.f
WHERE e.v <> 1 AND e.v NOT IN (SELECT f FROM friends)
GROUP BY e.v
ORDER BY mutual_friends DESC, user_id;
```

- Loại **chính mình** (`e.v <> 1`): bạn của bạn tôi luôn có tôi.
- Loại **bạn trực tiếp**: đây là anti-join. `NOT IN` an toàn ở đây vì `f` không bao giờ NULL; nói chung nên dùng `NOT EXISTS` (E1b).
- `COUNT(DISTINCT e.u)`: nếu cạnh bị lưu trùng mà quên `UNION` ở bước chuẩn hóa thì số bạn chung bị đếm đôi. `DISTINCT` là lớp bảo vệ thứ hai.

### 2.2 Ít bước nhất (BFS) (`graph/02`)

```sql
WITH RECURSIVE edges AS (...),                         -- 2.0
walk(stop, hops, path) AS (
  SELECT 'Ben Thanh'::text, 0, ARRAY['Ben Thanh'::text]
  UNION ALL
  SELECT e.v, w.hops + 1, w.path || e.v
  FROM walk w JOIN edges e ON e.u = w.stop
  WHERE e.v <> ALL (w.path)                            -- không quay lại trạm đã đi trên đường này
)
SELECT stop, MIN(hops) AS hops FROM walk GROUP BY stop ORDER BY hops, stop;
```

- `walk` sinh **mọi đường đi đơn** (không lặp nút) từ điểm xuất phát. Đường ngắn nhất là `MIN` bên ngoài (giới hạn 2 ở 1.3).
- Số đường đi đơn có thể **tăng theo hàm mũ** trên đồ thị dày. Với dữ liệu lớn: thêm giới hạn độ sâu, hoặc dùng `UNION` trên `(stop, hops)` (bỏ `path`) và chặn bằng `hops < số_nút`. Cách này cho số bước đúng nhưng không giữ được đường đi.
- Trạm không tới được thì **không có dòng**. Muốn hiện chúng với NULL thì `LEFT JOIN` từ danh sách trạm ở truy vấn ngoài (không đặt trong CTE, giới hạn 3 ở 1.3).

### 2.3 Thành phần liên thông (`graph/03`)

Câu hỏi "những tài khoản nào nối với nhau qua chuỗi liên kết" cần **tập** các cặp (điểm xuất phát, nút tới được), không cần đường đi. `UNION` khử trùng nên một cặp đã có thì không sinh lại. Số cặp là hữu hạn, nên đệ quy **tự dừng kể cả khi có chu trình**:

```sql
WITH RECURSIVE edges AS (...),
reach(start_id, node) AS (
  SELECT account_id, account_id FROM accounts          -- mỗi tài khoản tới được chính nó (kể cả khi không có cạnh)
  UNION
  SELECT r.start_id, e.v FROM reach r JOIN edges e ON e.u = r.node
),
labeled AS (SELECT start_id AS account_id, MIN(node) AS component_id FROM reach GROUP BY start_id)
SELECT component_id, COUNT(*) AS size,
       STRING_AGG(account_id::text, ', ' ORDER BY account_id) AS members
FROM labeled GROUP BY component_id ORDER BY component_id;
```

- **Nhãn của thành phần = id nhỏ nhất tới được**. Hai tài khoản cùng nhóm thì tới được cùng một tập, nên có cùng `MIN`.
- Neo lấy từ bảng **`accounts`**, không lấy từ bảng cạnh, để tài khoản đơn lẻ vẫn thành một nhóm 1 phần tử.
- Dùng `UNION ALL` ở đây thì vòng 104 → 105 → 106 → 104 sinh dòng mãi mãi, và câu lệnh chạy tới khi hết thời gian (`check.py` dừng sau 10 giây).
- Chi phí là n² cặp. Với hàng triệu tài khoản thì dùng thuật toán union-find ở ngoài SQL, hoặc lặp "gán nhãn bằng `MIN` của hàng xóm" tới khi ổn định.

### 2.4 Chu trình: tiền chạy vòng (`graph/04`)

Đi từ **mọi** tài khoản theo chiều chuyển tiền. Đường đi được phép quay lại **đúng điểm xuất phát** (đó là một chu trình), và dừng tại đó:

```sql
WITH RECURSIVE edges AS (SELECT DISTINCT from_acc AS u, to_acc AS v FROM transfers),
walk(start_acc, node, len, path) AS (
  SELECT u, v, 1, ARRAY[u, v] FROM edges
  UNION ALL
  SELECT w.start_acc, e.v, w.len + 1, w.path || e.v
  FROM walk w JOIN edges e ON e.u = w.node
  WHERE w.node <> w.start_acc                          -- đã về nhà: không đi tiếp
    AND (e.v = w.start_acc OR e.v <> ALL (w.path))     -- chỉ điểm xuất phát được ghé hai lần
)
SELECT start_acc AS account, MIN(len) AS cycle_len
FROM walk WHERE node = start_acc GROUP BY start_acc;
```

- Chuyển tiền cho chính mình (`TK-H → TK-H`) là chu trình độ dài 1: neo đã có `node = start_acc`.
- Một tài khoản có thể nằm trên nhiều chu trình (TK-C thuộc cả A→B→C→A và C→D→E→C). `MIN(len)` lấy chu trình ngắn nhất.
- `SELECT DISTINCT` trên cạnh: nhiều lần chuyển giữa cùng một cặp không làm số đường đi tăng lên.
- Biến thể: liệt kê từng chu trình **một lần** bằng cách chỉ giữ đường có điểm xuất phát là nút nhỏ nhất trên vòng (`start_acc = (SELECT MIN(x) FROM unnest(path) x)`).

### 2.5 Sắp xếp topo theo tầng (`graph/05`)

"Học môn nào trước" trên đồ thị **không có chu trình** (DAG). Tầng của một môn = **đường dài nhất** từ một môn gốc tới nó: môn có nhiều môn tiên quyết phải chờ môn **chậm nhất** trong số đó.

```sql
WITH RECURSIVE depth(course_id, d) AS (
  SELECT c.course_id, 0 FROM courses c
  WHERE NOT EXISTS (SELECT 1 FROM prerequisites p WHERE p.course_id = c.course_id)   -- gốc
  UNION ALL
  SELECT p.course_id, dp.d + 1
  FROM depth dp JOIN prerequisites p ON p.prereq_id = dp.course_id
)
SELECT c.course_id, c.name, MAX(dp.d) AS level
FROM courses c JOIN depth dp ON dp.course_id = c.course_id
GROUP BY c.course_id, c.name ORDER BY level, c.course_id;
```

| course_id | name | level |
| --- | --- | --- |
| 1 | SQL basics | 0 |
| 2 | Python basics | 0 |
| 6 | Statistics | 0 |
| 3 | Advanced SQL | 1 |
| 4 | Data analysis | 2 |
| 7 | Data Engineering | 2 |
| 5 | Machine Learning | 3 |

- `MIN(d)` thay cho `MAX(d)` cho Machine Learning tầng 1 (đường ngắn Python → ML), **ngang tầng** với Data analysis, dù đó là môn tiên quyết của nó. Data Engineering lại ra tầng 2. Thứ tự học bị sai.
- Nếu đồ thị **có chu trình** (A cần B, B cần A) thì các môn trên vòng không bao giờ được neo hay được tới, nên **biến mất khỏi kết quả**. Đó chính là cách phát hiện: so số môn trong kết quả với số môn trong bảng.

---

## Phần 3. Quy hoạch động trong SQL

### 3.1 Ba cách viết DP bằng SQL

DP = chia bài toán thành các **trạng thái** mà mỗi trạng thái tính được từ các trạng thái trước. Trong SQL có ba cách hiện thực, nên chọn theo thứ tự:

| Cách | Khi nào dùng được | Ví dụ | Mục |
| --- | --- | --- | --- |
| **Window function** | Trạng thái i chỉ cần một tổng hợp đơn giản của các dòng trước/sau (MAX, SUM, MIN) | Nước mưa, Kadane | 3.2, 3.3 |
| **Recursive CTE như vòng lặp** | Trạng thái i cần **kết quả DP** của i−1, i−2 (không phải dữ liệu thô) | House robber | 3.4 |
| **Recursive CTE liệt kê trạng thái** + `MIN`/`MAX` bên ngoài | Không gian trạng thái nhỏ (số tiền ≤ vài trăm, số món ≤ ~20) | Đổi tiền, knapsack | 3.5, 3.6 |

Câu cần hỏi: *"Giá trị ở bước i có viết được thành `MAX/SUM/MIN(...) OVER (...)` trên dữ liệu gốc không?"* Nếu có, dùng window (nhanh, gọn). Nếu không, vì nó phụ thuộc kết quả đã tính, thì dùng recursive.

### 3.2 Nước mưa giữa các cột (`dp/01`)

Mực nước tại i = `LEAST(cao nhất bên trái tính cả i, cao nhất bên phải tính cả i)`. Hai giá trị này là **hai running MAX ngược chiều nhau**:

```sql
SELECT pos, height,
       LEAST(MAX(height) OVER (ORDER BY pos ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
             MAX(height) OVER (ORDER BY pos ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)) - height AS water
FROM terrain;
```

Tổng `water` của dữ liệu đề là 6. Frame `CURRENT ROW AND UNBOUNDED FOLLOWING` là "running max từ phải sang". Có thể viết `ORDER BY pos DESC` với frame mặc định, nhưng khi đặt cạnh nhau thì viết frame tường minh dễ đọc hơn (F2).

### 3.3 Đoạn liên tiếp có tổng lớn nhất (Kadane) (`dp/02`)

Tổng đoạn i..j = `prefix[j] − prefix[i−1]`. Đoạn tốt nhất kết thúc tại j là `prefix[j] − MIN(prefix trước j)`. Lời giải `dp/02` ghép mọi cặp prefix (n², dễ lấy ngày bắt đầu và kết thúc):

```sql
WITH numbered AS (
  SELECT day, ROW_NUMBER() OVER (ORDER BY day) AS i, SUM(profit_m) OVER (ORDER BY day) AS prefix
  FROM daily_profit
),
prefixes AS (SELECT i, prefix FROM numbered UNION ALL SELECT 0, 0)   -- prefix rỗng: đoạn bắt đầu từ ngày 1
SELECT s.day AS start_day, e.day AS end_day, e.prefix - p.prefix AS total_profit
FROM prefixes p
JOIN numbered e ON e.i > p.i
JOIN numbered s ON s.i = p.i + 1
ORDER BY total_profit DESC, start_day, end_day
LIMIT 1;
```

- **Thêm prefix 0** ("trước ngày đầu tiên"), nếu không thì không có đoạn nào bắt đầu từ ngày 1.
- `e.i > p.i` (chặt) bảo đảm đoạn có **ít nhất một ngày**. Khi mọi ngày đều lỗ, đáp án là ngày lỗ ít nhất, không phải 0.
- Bản O(n) chỉ cần giá trị. Window không lồng được vào aggregate, nên phải tính `min_before` trong subquery trước:

  ```sql
  SELECT MAX(prefix - min_before) AS best
  FROM (SELECT i, prefix,
               MIN(prefix) OVER (ORDER BY i ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS min_before
        FROM prefixes) t
  WHERE i > 0;                                        -- dữ liệu đề: 6
  ```

  Muốn ngày bắt đầu thì phải tìm thêm vị trí của min.

### 3.4 House robber: recursive CTE làm vòng lặp (`dp/03`)

`best(i) = GREATEST(best(i−1), best(i−2) + v(i))`: bước i cần **kết quả DP** của hai bước trước, nên không viết được bằng window. Recursive CTE đi **một dòng mỗi vòng** và mang theo hai giá trị đó:

```sql
WITH RECURSIVE days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY day) AS i, extra_revenue_m AS v FROM promo_days
),
dp(i, best, best_prev) AS (
  SELECT 0::bigint, 0::bigint, 0::bigint                -- trước ngày 1; ::bigint khớp kiểu (1.3)
  UNION ALL
  SELECT d.i, GREATEST(dp.best, dp.best_prev + d.v), dp.best
  FROM dp JOIN days d ON d.i = dp.i + 1                 -- hết ngày thì hết dòng: dừng
)
SELECT best AS max_extra_revenue FROM dp ORDER BY i DESC LIMIT 1;
```

- `ROW_NUMBER` biến các ngày thành chỉ số liên tục 1..n. `JOIN ... ON d.i = dp.i + 1` là "lấy phần tử kế tiếp".
- Dòng neo `(0, 0, 0)` xử lý luôn bảng rỗng: kết quả là 0 mà không cần `COALESCE`.
- Tham lam (chọn ngày lớn nhất trước) sai với 5, 6, 5: chọn 6 được 6, còn đáp án đúng là 5 + 5 = 10.
- Cùng khung "đi từng dòng, mang theo trạng thái" giải được mọi phép tính tuần tự mà window không làm được, ví dụ số dư có trần (không vượt quá X), hay tích lũy reset theo điều kiện phụ thuộc chính kết quả.

### 3.5 Đổi tiền: ít voucher nhất (`dp/04`)

Trạng thái `(số tiền đã đạt, số voucher đã dùng)`. Từ mỗi trạng thái thêm một voucher bất kỳ, và không vượt quá số tiền lớn nhất cần trả. `UNION` giữ mỗi trạng thái một lần, đáp án là `MIN(n)` bên ngoài:

```sql
WITH RECURSIVE reach(amount, n) AS (
  SELECT 0::bigint, 0::bigint
  UNION
  SELECT r.amount + v.value, r.n + 1
  FROM reach r CROSS JOIN vouchers v
  WHERE r.amount + v.value <= (SELECT MAX(amount) FROM payments)
),
best AS (SELECT amount, MIN(n) AS min_vouchers FROM reach GROUP BY amount)
SELECT p.payment_id, p.amount, b.min_vouchers
FROM payments p LEFT JOIN best b ON b.amount = p.amount;     -- không đạt được → NULL
```

- **Tham lam sai** với mệnh giá "lạ": voucher {1, 3, 4} trả 6 bằng 4 + 1 + 1 (3 voucher), trong khi 3 + 3 chỉ cần 2. Tiền Việt Nam (1, 2, 5, 10…) thì tham lam đúng, nên đề phỏng vấn luôn cố tình chọn mệnh giá lạ.
- Số trạng thái ≤ (số tiền lớn nhất + 1) × (số voucher tối đa), nên chỉ hợp với số tiền nhỏ. Không có điều kiện `<=` thì đệ quy chạy mãi.
- `LEFT JOIN` ở **truy vấn ngoài** (được phép), không đặt trong CTE (giới hạn 3 ở 1.3).

### 3.6 Knapsack 0/1: lấy hay bỏ từng món (`dp/05`)

Đi qua các món theo thứ tự. Mỗi bước rẽ **hai nhánh** (lấy / bỏ) bằng `CROSS JOIN (VALUES (TRUE), (FALSE))`, và **cắt nhánh** quá tải ngay khi sinh ra:

```sql
WITH RECURSIVE ordered AS (
  SELECT ROW_NUMBER() OVER (ORDER BY item_id) AS k, item_id, weight_kg, value FROM items
),
pack(k, weight, value, ids) AS (
  SELECT 0::bigint, 0::bigint, 0::bigint, ARRAY[]::int[]
  UNION ALL
  SELECT o.k,
         p.weight + CASE WHEN t.take THEN o.weight_kg ELSE 0 END,
         p.value  + CASE WHEN t.take THEN o.value     ELSE 0 END,
         CASE WHEN t.take THEN p.ids || o.item_id::int ELSE p.ids END
  FROM pack p
  JOIN ordered o ON o.k = p.k + 1
  CROSS JOIN (VALUES (TRUE), (FALSE)) AS t(take)
  WHERE p.weight + CASE WHEN t.take THEN o.weight_kg ELSE 0 END <= 10
)
SELECT * FROM pack
WHERE k = (SELECT COUNT(*) FROM items)                 -- đã quyết định hết các món
ORDER BY value DESC, weight, ids LIMIT 1;
```

- Đáp án của đề: Gas stove + Water + Flashlight + Camera = 10 kg, giá trị 175.
- **Tham lam theo giá trị/kg sai**: A (6 kg, 66), B (5 kg, 50), C (5 kg, 50), sức chứa 10. Tham lam lấy A (11/kg) xong thì không còn chỗ cho B hay C, được 66. Đáp án đúng là B + C = 100.
- Số nhánh tối đa 2ⁿ, nhưng cắt nhánh quá tải giảm đi rất nhiều. Phù hợp với khoảng ≤ 20 món. Bài lớn hơn cần DP theo **trọng lượng** (trạng thái `(k, weight)` giữ giá trị lớn nhất), nhưng việc đó cần tổng hợp trong vòng lặp nên phải dùng PL/pgSQL.
- Mảng `ids` so sánh được trực tiếp (`ORDER BY ids`): đây là quy tắc tách hòa "danh sách id đứng trước".

### 3.7 Bẫy recursive CTE

1. **Kiểu neo khác kiểu đệ quy** (`integer` và `bigint`, `varchar` và `text`): ép kiểu ở neo (1.3).
2. **`UNION ALL` trên đồ thị có chu trình** mà không có `path` hay giới hạn độ sâu: chạy mãi (2.3).
3. **Tổng hợp trong phần đệ quy**: không được phép. Sinh trạng thái rồi `MIN`/`MAX` ở ngoài.
4. **Outer join với chính CTE đệ quy**: không được phép. Chuyển ra truy vấn ngoài.
5. **Quên chuẩn hóa cạnh hai chiều** cho đồ thị vô hướng, hoặc quên `DISTINCT` khi cạnh bị lặp: kết quả thiếu hoặc bùng nổ số đường đi.
6. **`MIN` thay `MAX`** (hoặc ngược lại) khi gom kết quả: đường ngắn nhất dùng `MIN`, tầng topo dùng `MAX` (2.5).
7. **Neo lấy từ bảng cạnh thay vì bảng nút**: các nút cô lập biến mất (2.3).
8. **Tin vào thuật toán tham lam** cho house robber, đổi tiền, knapsack: luôn thử một phản ví dụ nhỏ trước khi viết.
