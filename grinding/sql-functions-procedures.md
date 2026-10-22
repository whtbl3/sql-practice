# Function, Procedure và Trigger trong PostgreSQL (PL/pgSQL)

> Phương ngữ: **PostgreSQL 16** (đúng engine của `check.py`). Mọi lời giải mẫu dưới đây là đáp án trong `solutions/func/*`, đã **chạy thật** qua test nhìn thấy và test ẩn.
> Cách học: đọc từng phần theo thứ tự, mỗi phần có **các bước viết** rồi mới đến lời giải mẫu, cuối phần là bẫy. Làm bài `func/*` tương ứng ngay sau khi đọc.
> Bẫy chung về NULL, kiểu dữ liệu, JOIN nằm ở [sql-common-pitfalls.md](sql-common-pitfalls.md) (mã mục A2, A5…).

**Mục lục**

| Phần | Nội dung | Bài tập |
| --- | --- | --- |
| 0 | Bản đồ: Function, Procedure, Trigger khác nhau thế nào, khi nào dùng | |
| 1 | Giải phẫu `CREATE FUNCTION` từng dòng | |
| 2 | Function viết bằng `LANGUAGE sql` | `func/01` |
| 3 | PL/pgSQL căn bản: khối lệnh, biến, `IF`, `RAISE`, vòng lặp | `func/02`, `func/05` |
| 4 | Function trả về bảng: `RETURNS TABLE`, `RETURN QUERY`, tham số mặc định | `func/03`, `func/04` |
| 5 | Procedure: `CALL`, kiểm tra đầu vào, giao dịch, `FOUND` | `func/06`, `func/07`, `func/10` |
| 6 | Trigger | `func/08` |
| 7 | Bắt lỗi: `EXCEPTION WHEN` | `func/09` |
| 8 | Volatility, hiệu năng, bảo mật | |
| 9 | Làm bài `func/*` với `check.py` | |
| 10 | Câu hỏi phỏng vấn hay gặp và bảng thuộc lòng | |

---

## Phần 0. Bản đồ

### 0.1 Ba thứ, ba mục đích

| | Function | Procedure | Trigger |
| --- | --- | --- | --- |
| Tạo bằng | `CREATE FUNCTION` | `CREATE PROCEDURE` | `CREATE FUNCTION ... RETURNS TRIGGER` + `CREATE TRIGGER` |
| Gọi bằng | Trong câu SQL: `SELECT f(x)`, `FROM f(x)`, `WHERE f(x) > 0` | Riêng một lệnh: `CALL p(x)` | **Không gọi tay**: tự chạy khi có `INSERT/UPDATE/DELETE` trên bảng |
| Trả về | Một giá trị, một dòng hoặc một tập dòng | Không có giá trị trả về (chỉ có tham số `INOUT`/`OUT`) | Dòng `NEW`/`OLD` (hoặc `NULL`) cho engine |
| `COMMIT`/`ROLLBACK` bên trong | Không được | Được (nếu `CALL` không nằm trong một transaction mở sẵn) | Không được |
| Dùng khi | **Tính toán**: biến đổi giá trị, truy vấn có tham số | **Thực hiện một nghiệp vụ**: chuyển tiền, chạy batch, cập nhật nhiều bảng | **Phản ứng tự động**: audit log, kiểm tra ràng buộc phức tạp, cập nhật cột dẫn xuất |

Câu trả lời ngắn khi bị hỏi *"function và procedure khác nhau thế nào?"*: **function trả về giá trị và dùng được bên trong câu SQL; procedure là một hành động gọi bằng `CALL`, không trả về giá trị và được tự quản lý transaction.**

### 0.2 Khi nào **không** nên viết function/procedure

- Một câu `SELECT` có CTE + window giải được thì đừng gói vào vòng lặp PL/pgSQL. SQL theo tập (set-based) gần như luôn nhanh hơn xử lý từng dòng (xem 5.3).
- Logic nghiệp vụ thay đổi liên tục, cần test và review như code ứng dụng thì để ở tầng ứng dụng. Đặt trong database khi cần **tính nguyên tử gần dữ liệu** (chuyển tiền), **dùng chung cho nhiều ứng dụng**, hoặc **không được phép bỏ qua** (trigger audit).

---

## Phần 1. Giải phẫu `CREATE FUNCTION` từng dòng

```sql
CREATE OR REPLACE FUNCTION net_price(p_price NUMERIC, p_discount_pct INT)  -- (1) tên + tham số
RETURNS NUMERIC                                                            -- (2) kiểu trả về
LANGUAGE sql                                                               -- (3) ngôn ngữ thân hàm
IMMUTABLE                                                                  -- (4) volatility
AS $$                                                                      -- (5) thân hàm trong $$ ... $$
  SELECT ROUND(p_price * (100 - COALESCE(p_discount_pct, 0)) / 100, 2)
$$;
```

| Bước | Dòng | Quyết định cần đưa ra |
| --- | --- | --- |
| 1 | Tên + tham số | Đặt tiền tố `p_` cho tham số để **không trùng tên cột** (bẫy lớn nhất của PL/pgSQL, xem 4.3) |
| 2 | `RETURNS` | Một giá trị (`NUMERIC`), một tập dòng (`RETURNS TABLE (...)`, `SETOF ...`), `TRIGGER` hoặc `VOID` |
| 3 | `LANGUAGE` | `sql` nếu thân hàm chỉ là một câu truy vấn; `plpgsql` nếu cần biến, `IF`, vòng lặp, `RAISE`, bắt lỗi |
| 4 | Volatility | `IMMUTABLE` / `STABLE` / `VOLATILE` (mặc định). Xem Phần 8 |
| 5 | `$$ ... $$` | Dollar quoting: viết thân hàm mà không phải nhân đôi dấu `'`. Cần lồng nhau thì đặt tên: `$body$ ... $body$` |

**`CREATE OR REPLACE` không đổi được kiểu trả về** (cũng không đổi được tên tham số):

```
ERROR:  cannot change return type of existing function
HINT:  Use DROP FUNCTION g(integer) first.
```

PostgreSQL cho phép **nạp chồng (overloading)**: `f(int)` và `f(text)` là hai hàm khác nhau. Vì vậy `DROP FUNCTION` cần ghi cả kiểu tham số khi có nhiều phiên bản: `DROP FUNCTION g(integer);`.

---

## Phần 2. Function viết bằng `LANGUAGE sql` (`func/01`)

### 2.1 Các bước

1. Viết **biểu thức** cần tính như thể tham số là cột: `ROUND(price * (100 - discount) / 100, 2)`.
2. Xử lý NULL cho từng tham số theo đề: discount NULL = không giảm → `COALESCE(p_discount_pct, 0)`; price NULL → kết quả NULL (phép nhân với NULL tự cho NULL).
3. Bọc trong `SELECT ...` và đặt vào `$$ ... $$`.
4. Chọn volatility: chỉ phụ thuộc tham số → `IMMUTABLE`.
5. Thử bằng câu gọi trong `-- CALL`.

### 2.2 `STRICT` hay `COALESCE`?

`STRICT` (= `RETURNS NULL ON NULL INPUT`) nghĩa là: **nếu bất kỳ tham số nào là NULL thì trả NULL luôn, không chạy thân hàm.**

```sql
CREATE FUNCTION h(x INT) RETURNS INT LANGUAGE sql STRICT AS 'SELECT 1';
SELECT h(NULL);   -- NULL, dù thân hàm luôn trả 1
```

Trong `func/01`, thêm `STRICT` là **sai**: sản phẩm 2 có discount NULL sẽ ra `net = NULL` thay vì `59.99`. Quy tắc: chỉ dùng `STRICT` khi **mọi** tham số NULL đều phải cho kết quả NULL.

### 2.3 Bẫy

| Bẫy | Hậu quả | Cách tránh |
| --- | --- | --- |
| Chia số nguyên: `p_price_int * (100 - d) / 100` khi mọi thứ là `INT` | Mất phần thập phân (xem A5) | Có ít nhất một vế `NUMERIC` |
| Làm tròn sai chỗ: làm tròn trước khi nhân | Lệch 0.01 | Tính xong mới `ROUND` một lần |
| `STRICT` khi đề cho NULL một nghĩa riêng | Mất dòng hợp lệ | `COALESCE` từng tham số |

---

## Phần 3. PL/pgSQL căn bản (`func/02`, `func/05`)

### 3.1 Khung một khối lệnh

```sql
CREATE FUNCTION ten_ham(p_x INT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE                      -- (1) khai báo biến (không bắt buộc)
  v_count INT := 0;
  v_name  TEXT;
BEGIN                        -- (2) thân
  SELECT name INTO v_name FROM users WHERE id = p_x;   -- gán kết quả truy vấn vào biến
  v_count := v_count + 1;                              -- gán bằng :=
  RETURN v_name;
EXCEPTION                    -- (3) bắt lỗi (không bắt buộc, xem Phần 7)
  WHEN OTHERS THEN RETURN NULL;
END;
$$;
```

| Cú pháp | Ý nghĩa |
| --- | --- |
| `v := biểu_thức;` | Gán giá trị |
| `SELECT a, b INTO v_a, v_b FROM ...;` | Gán **dòng đầu tiên** của kết quả vào biến; không có dòng nào thì biến là NULL |
| `SELECT ... INTO STRICT v ...;` | Bắt buộc **đúng 1 dòng**: 0 dòng → lỗi `query returned no rows`, nhiều dòng → lỗi `query returned more than one row` |
| `FOUND` | Biến tự có, `true` nếu câu `SELECT INTO`/`UPDATE`/`INSERT`/`DELETE` vừa rồi có ảnh hưởng tới ít nhất 1 dòng |
| `RETURN x;` | Kết thúc hàm, trả `x` |

### 3.2 `IF` / `ELSIF` / `RAISE`: các bước giải `func/02`

1. **Xử lý NULL đầu tiên.** `NULL >= 90` là NULL, không phải `false` (xem A2), nên nếu để NULL rơi xuống các nhánh so sánh, kết quả sẽ là nhánh cuối (`'F'`). Kiểm tra `IS NULL` trước tiên.
2. **Chặn dữ liệu không hợp lệ** bằng `RAISE EXCEPTION`, đừng trả về một giá trị "trông có vẻ đúng".
3. Viết các nhánh **từ cao xuống thấp**: nhánh đầu tiên đúng sẽ thắng, nên `>= 80` không cần thêm `AND < 90`.
4. Một `RETURN` mặc định ở cuối.

```sql
CREATE FUNCTION grade_of(p_score INT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_score IS NULL THEN                             -- Bước 1
    RETURN 'N/A';
  ELSIF p_score < 0 OR p_score > 100 THEN             -- Bước 2
    RAISE EXCEPTION 'invalid score: %', p_score;
  ELSIF p_score >= 90 THEN                            -- Bước 3
    RETURN 'A';
  ELSIF p_score >= 80 THEN
    RETURN 'B';
  ELSIF p_score >= 65 THEN
    RETURN 'C';
  END IF;
  RETURN 'F';                                         -- Bước 4
END;
$$;
```

**`RAISE` theo mức độ**

| Lệnh | Tác dụng |
| --- | --- |
| `RAISE NOTICE 'x = %', v;` | In thông báo, **không dừng**. Dùng để debug (`check.py` in các NOTICE phía trên output) |
| `RAISE WARNING ...` | Như NOTICE nhưng mức cảnh báo |
| `RAISE EXCEPTION 'msg %', v;` | **Dừng** và hủy toàn bộ câu lệnh đang chạy (rollback mọi thay đổi của câu lệnh đó) |
| `RAISE EXCEPTION ... USING ERRCODE = 'check_violation';` | Gắn mã lỗi để phía gọi bắt theo tên |

Mỗi `%` trong chuỗi được thay bằng một tham số theo thứ tự.

### 3.3 Vòng lặp

| Dạng | Khi nào |
| --- | --- |
| `FOR i IN 1..10 LOOP ... END LOOP;` | Lặp theo số |
| `FOR rec IN SELECT ... LOOP ... END LOOP;` | Duyệt từng dòng của một truy vấn (`rec` khai báo kiểu `RECORD`) |
| `WHILE điều_kiện LOOP ... END LOOP;` | Lặp tới khi điều kiện sai |
| `LOOP ... EXIT WHEN điều_kiện; END LOOP;` | Vòng lặp tự do |
| `CONTINUE WHEN điều_kiện;` | Bỏ qua phần còn lại của vòng hiện tại |

### 3.4 Hàm đọc bảng (`func/05`)

Đề: đếm số ngày làm việc (thứ 2 đến thứ 6, trừ ngày lễ trong bảng `holidays`) từ `p_from` tới `p_to`.

**Các bước**

1. Sinh từng ngày trong khoảng: `generate_series(p_from, p_to, INTERVAL '1 day')`. Nếu `p_from > p_to` thì hàm này sinh **0 dòng**, `COUNT(*)` ra 0, đúng yêu cầu mà không cần `IF`.
2. Giữ ngày trong tuần: `EXTRACT(ISODOW FROM d) < 6` (ISODOW: thứ Hai = 1 … Chủ nhật = 7, không phụ thuộc cài đặt locale).
3. Bỏ ngày lễ bằng `NOT EXISTS` (anti-join, an toàn với NULL hơn `NOT IN`).
4. Hàm **đọc bảng** nên là `STABLE`, không được là `IMMUTABLE` (Phần 8).

```sql
CREATE FUNCTION business_days(p_from DATE, p_to DATE)
RETURNS INT
LANGUAGE sql
STABLE
AS $$
  SELECT COUNT(*)::INT                                                       -- COUNT trả BIGINT, ép về INT cho khớp RETURNS
  FROM generate_series(p_from, p_to, INTERVAL '1 day') AS g(d)               -- Bước 1
  WHERE EXTRACT(ISODOW FROM g.d) < 6                                         -- Bước 2
    AND NOT EXISTS (SELECT 1 FROM holidays h WHERE h.holiday_date = g.d::DATE) -- Bước 3
$$;
```

Ngày lễ rơi vào thứ Bảy đã bị loại ở bước 2, nên không bị trừ hai lần (test ẩn kiểm tra đúng chỗ này).

Cách viết bằng vòng lặp PL/pgSQL (`WHILE v_d <= p_to LOOP ... v_d := v_d + 1; END LOOP;`) cũng đúng, nhưng chậm hơn và dài hơn. Nếu một câu SQL giải được thì dùng câu SQL.

---

## Phần 4. Function trả về bảng (`func/03`, `func/04`)

### 4.1 Ba cách khai báo

| Cách | Ví dụ | Ghi chú |
| --- | --- | --- |
| `RETURNS TABLE (cột kiểu, ...)` | `RETURNS TABLE (customer_id INT, total_spent NUMERIC)` | Rõ ràng nhất, dùng mặc định |
| `RETURNS SETOF ten_bang` | `RETURNS SETOF orders` | Trả nguyên dòng của một bảng có sẵn |
| `OUT` parameters | `f(p_n INT, OUT a INT, OUT b TEXT)` | Một dòng nhiều cột; thêm `SETOF RECORD` để nhiều dòng |

Gọi hàm bảng ở mệnh đề `FROM`: `SELECT * FROM top_customers(3);`.

### 4.2 Các bước giải `func/03`

1. Viết câu `SELECT` bình thường trả đúng kết quả với `n` cố định (ví dụ `LIMIT 3`), chạy thử.
2. Thay hằng số bằng tham số `p_n`.
3. **Đặt bí danh bảng và ghi rõ tên bảng trước mọi cột** (`o.customer_id`), vì cột output của `RETURNS TABLE` cũng là biến trong hàm (4.3).
4. **Ép kiểu cho khớp từng cột** của `RETURNS TABLE` (4.3).
5. Bọc trong `RETURN QUERY` (plpgsql) hoặc để nguyên câu `SELECT` (sql).

```sql
CREATE FUNCTION top_customers(p_n INT)
RETURNS TABLE (customer_id INT, total_spent NUMERIC)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT o.customer_id, SUM(o.amount)::NUMERIC     -- Bước 3 + 4
  FROM orders o
  WHERE o.status = 'paid'
  GROUP BY o.customer_id
  ORDER BY 2 DESC, 1                               -- theo vị trí: tránh nhắc lại tên trùng
  LIMIT p_n;                                       -- Bước 2
END;
$$;
```

### 4.3 Hai lỗi chắc chắn gặp

**Lỗi 1: trùng tên giữa cột output và cột bảng.** Viết `SELECT customer_id ... GROUP BY customer_id` không có bí danh:

```
ERROR:  column reference "customer_id" is ambiguous
DETAIL:  It could refer to either a PL/pgSQL variable or a table column.
CONTEXT:  PL/pgSQL function top_customers(integer) line 3 at RETURN QUERY
```

Trong PL/pgSQL, `customer_id` của `RETURNS TABLE` là một **biến**. Cách sửa (chọn một):

- Ghi rõ tên bảng trước mọi cột: `o.customer_id` (khuyên dùng), và `ORDER BY` theo vị trí.
- Đổi tên cột output (`RETURNS TABLE (out_customer_id INT, ...)`). Đổi tên thì phải đổi cả câu gọi, nên ít khi chọn cách này.
- Thêm dòng `#variable_conflict use_column` ngay đầu thân hàm để ưu tiên cột bảng.

Hàm viết bằng `LANGUAGE sql` (như `func/04`) không báo lỗi này: khi trùng tên, **tên cột được ưu tiên** hơn tham số. Không lỗi nhưng dễ đọc nhầm, nên vẫn ghi rõ tên bảng trước cột.

**Lỗi 2: kiểu dữ liệu không khớp.** `SUM` của cột `INT` trả `BIGINT`, không phải `NUMERIC`:

```
ERROR:  structure of query does not match function result type
DETAIL:  Returned type bigint does not match expected type numeric in column 2.
```

`RETURN QUERY` đòi **khớp chính xác** từng kiểu. Bảng kiểu trả về hay gặp:

| Biểu thức | Kiểu trả về |
| --- | --- |
| `COUNT(*)` | `BIGINT` |
| `SUM(cột INT)` | `BIGINT` |
| `SUM(cột BIGINT)`, `SUM(cột NUMERIC)` | `NUMERIC` |
| `AVG(cột INT)` | `NUMERIC` |
| `ROUND(numeric, 2)` | `NUMERIC` |
| `'abc'` (literal) | `unknown`, ép `::TEXT` nếu cột output là `TEXT` |

### 4.4 Tham số mặc định và "NULL nghĩa là không lọc" (`func/04`)

**Các bước**

1. Khai báo tham số tùy chọn **ở cuối**, kèm `DEFAULT NULL`: `p_status TEXT DEFAULT NULL`.
2. Viết điều kiện lọc dạng `(p_status IS NULL OR o.status = p_status)`.
3. Gọi theo vị trí `customer_orders(1)` hoặc theo tên `customer_orders(1, p_status => 'paid')`.

```sql
CREATE FUNCTION customer_orders(p_customer_id INT, p_status TEXT DEFAULT NULL)
RETURNS TABLE (order_id INT, status TEXT, amount INT)
LANGUAGE sql
STABLE
AS $$
  SELECT o.order_id, o.status, o.amount
  FROM orders o
  WHERE o.customer_id = p_customer_id
    AND (p_status IS NULL OR o.status = p_status)    -- Bước 2
  ORDER BY o.order_id
$$;
```

Viết `WHERE o.status = p_status` thì khi `p_status` là NULL, điều kiện ra NULL và **không trả dòng nào** (A2). Test nhìn thấy của `func/04` bắt đúng lỗi này.

---

## Phần 5. Procedure (`func/06`, `func/07`, `func/10`)

### 5.1 Khung và cách gọi

```sql
CREATE PROCEDURE transfer(p_from INT, p_to INT, p_amount NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
  ...
END;
$$;

CALL transfer(1, 2, 30.00);
```

- Không có `RETURNS`. Muốn trả giá trị ra ngoài thì dùng tham số `INOUT`: `CALL p(1, NULL)` trả về một dòng chứa giá trị cuối của tham số đó.
- `SELECT transfer(...)` báo lỗi `transfer(...) is a procedure`: procedure chỉ gọi bằng `CALL`.

### 5.2 Các bước viết một procedure nghiệp vụ (`func/06`)

1. **Liệt kê mọi luật nghiệp vụ** trước khi viết: số tiền > 0, hai tài khoản khác nhau, cả hai tồn tại, đủ số dư.
2. **Kiểm tra tham số trước** (không tốn truy vấn): số tiền, cùng tài khoản.
3. **Đọc và khóa dòng nguồn**: `SELECT ... INTO ... FOR UPDATE`. Hai giao dịch chuyển tiền chạy song song từ cùng tài khoản sẽ phải xếp hàng, không thể cùng đọc số dư 100 rồi cùng trừ.
4. **Kiểm tra trên dữ liệu đã đọc** (`NOT FOUND`, số dư).
5. **Chỉ khi mọi luật đều qua** mới `UPDATE`.

```sql
CREATE PROCEDURE transfer(p_from INT, p_to INT, p_amount NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN                                    -- Bước 2
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  IF p_from = p_to THEN
    RAISE EXCEPTION 'same account';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM accounts WHERE account_id = p_to) THEN
    RAISE EXCEPTION 'account not found: %', p_to;
  END IF;

  SELECT balance INTO v_balance FROM accounts WHERE account_id = p_from FOR UPDATE;  -- Bước 3
  IF NOT FOUND THEN                                                            -- Bước 4
    RAISE EXCEPTION 'account not found: %', p_from;
  END IF;
  IF v_balance < p_amount THEN
    RAISE EXCEPTION 'insufficient funds: balance %, amount %', v_balance, p_amount;
  END IF;

  UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from;  -- Bước 5
  UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to;
END;
$$;
```

**Tính nguyên tử (atomicity).** Nếu `RAISE EXCEPTION` xảy ra **sau** khi đã `UPDATE` một tài khoản, PostgreSQL vẫn hủy cả câu `CALL`, nên không bao giờ có chuyện tiền bị trừ mà không được cộng. Dù vậy, kiểm tra hết trước rồi mới ghi vẫn tốt hơn: dễ đọc, không tốn công ghi rồi hủy, và luật không phụ thuộc vào cơ chế rollback.

**Transaction trong procedure.** Procedure được phép `COMMIT`/`ROLLBACK` giữa chừng (ví dụ batch lớn, commit mỗi 10.000 dòng). Điều kiện: `CALL` phải được gọi **ngoài** một transaction đã mở (không nằm trong `BEGIN ... COMMIT` của phía gọi). Function thì không bao giờ được commit, vì nó luôn chạy bên trong câu lệnh của người gọi.

### 5.3 Xử lý từng dòng hay theo tập (`func/07`)

**Cách 1: vòng lặp** (đáp án mẫu, dễ hiểu từng bước):

```sql
FOR rec IN SELECT account_id, balance FROM accounts WHERE type = 'savings' LOOP
  v_interest := ROUND(rec.balance * p_rate, 2);
  CONTINUE WHEN v_interest <= 0;                     -- tiền lãi làm tròn về 0 thì bỏ qua
  UPDATE accounts SET balance = balance + v_interest WHERE account_id = rec.account_id;
  INSERT INTO interest_log (account_id, interest) VALUES (rec.account_id, v_interest);
END LOOP;
```

**Cách 2: theo tập**, một câu lệnh với CTE ghi dữ liệu (data-modifying CTE), đặt thay cho vòng `FOR` (vẫn giữ phần kiểm tra `p_rate` ở đầu):

```sql
WITH calc AS (                                       -- Bước 1: tính tiền lãi một lần, giữ dòng > 0
  SELECT account_id, ROUND(balance * p_rate, 2) AS interest
  FROM accounts
  WHERE type = 'savings' AND ROUND(balance * p_rate, 2) > 0
), upd AS (                                          -- Bước 2: cộng vào số dư
  UPDATE accounts a
  SET balance = a.balance + c.interest
  FROM calc c
  WHERE a.account_id = c.account_id
  RETURNING c.account_id, c.interest                 -- RETURNING lấy được cột của bảng trong FROM
)
INSERT INTO interest_log (account_id, interest)      -- Bước 3: ghi log đúng các dòng đã cập nhật
SELECT account_id, interest FROM upd;
```

Phải tính tiền lãi ở CTE `calc` **trước** khi `UPDATE`: `RETURNING` của câu `UPDATE` chỉ thấy số dư **mới**, nên không lấy lại được tiền lãi từ đó cho đúng. Với hàng triệu dòng, cách theo tập nhanh hơn vòng lặp rất nhiều; trong phỏng vấn, nói được cả hai cách và đánh đổi giữa chúng là điểm cộng.

### 5.4 `FOUND`, `GET DIAGNOSTICS` và upsert (`func/10`)

**Các bước**

1. Kiểm tra tham số (giá trị âm, NULL).
2. `UPDATE` trước.
3. `IF NOT FOUND THEN INSERT`: `FOUND` cho biết câu `UPDATE` vừa rồi có chạm dòng nào không.

```sql
UPDATE price_list
SET price = p_price, updated_count = updated_count + 1
WHERE sku = p_sku;

IF NOT FOUND THEN
  INSERT INTO price_list (sku, price, updated_count) VALUES (p_sku, p_price, 0);
END IF;
```

Cần biết **số dòng** bị ảnh hưởng: `GET DIAGNOSTICS v_rows = ROW_COUNT;` ngay sau câu lệnh.

Nếu bảng có `UNIQUE`/`PRIMARY KEY` trên `sku` thì dùng một câu duy nhất, an toàn cả khi nhiều phiên chạy song song:

```sql
INSERT INTO price_list (sku, price, updated_count) VALUES (p_sku, p_price, 0)
ON CONFLICT (sku) DO UPDATE
SET price = EXCLUDED.price, updated_count = price_list.updated_count + 1;
```

Cách `UPDATE` rồi `INSERT` có **race condition**: hai phiên cùng không thấy `C`, cùng `INSERT`, và bảng có hai dòng `C`. Bài tập dùng cách này vì bảng không có ràng buộc unique; khi phỏng vấn nên nói ra điểm này.

---

## Phần 6. Trigger (`func/08`)

### 6.1 Hai phần của một trigger

```sql
-- (1) Hàm trigger: không tham số, RETURNS TRIGGER
CREATE FUNCTION log_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.price IS DISTINCT FROM OLD.price THEN
    INSERT INTO price_audit (product_id, old_price, new_price)
    VALUES (NEW.product_id, OLD.price, NEW.price);
  END IF;
  RETURN NEW;
END;
$$;

-- (2) Gắn hàm vào bảng: khi nào, với lệnh gì, mỗi dòng hay mỗi câu lệnh
CREATE TRIGGER trg_price_audit
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_price_change();
```

### 6.2 Các bước thiết kế

| Bước | Câu hỏi | `func/08` |
| --- | --- | --- |
| 1 | Lệnh nào kích hoạt? `INSERT` / `UPDATE` / `DELETE` (có thể nhiều: `INSERT OR UPDATE`) | `UPDATE` |
| 2 | `BEFORE` hay `AFTER`? | `AFTER`: chỉ ghi log khi thay đổi đã chắc chắn được áp dụng |
| 3 | `FOR EACH ROW` hay `FOR EACH STATEMENT`? | `ROW`: cần `OLD`/`NEW` của từng dòng |
| 4 | Điều kiện nào thì làm? | Giá trị thực sự đổi: `IS DISTINCT FROM` (an toàn với NULL) |
| 5 | Trả về gì? | `RETURN NEW` (với `AFTER`, giá trị trả về bị bỏ qua; quen viết `RETURN NEW` hoặc `RETURN NULL`) |

### 6.3 `BEFORE` và `AFTER`, `ROW` và `STATEMENT`

| | Dùng để | Giá trị trả về |
| --- | --- | --- |
| `BEFORE ... FOR EACH ROW` | **Sửa dòng trước khi ghi** (chuẩn hóa email, gán `updated_at = now()`), hoặc chặn | `RETURN NEW` = ghi dòng (đã sửa); `RETURN NULL` = **bỏ qua** dòng này một cách im lặng |
| `AFTER ... FOR EACH ROW` | Ghi log, cập nhật bảng khác | Bị bỏ qua |
| `... FOR EACH STATEMENT` | Chạy **một lần** cho cả câu lệnh, kể cả khi câu lệnh không chạm dòng nào | `OLD`/`NEW` là NULL. Muốn xem các dòng thì dùng transition table: `REFERENCING NEW TABLE AS new_rows` |

Biến có sẵn trong hàm trigger: `NEW`, `OLD` (với `INSERT` thì không có `OLD`, với `DELETE` thì không có `NEW`), `TG_OP` (`'INSERT'`, `'UPDATE'`, `'DELETE'`), `TG_TABLE_NAME`.

### 6.4 Bẫy trigger

| Bẫy | Hậu quả |
| --- | --- |
| `NEW.price <> OLD.price` | NULL → 30 cho ra NULL, **không ghi log** (A4). Dùng `IS DISTINCT FROM` |
| `FOR EACH STATEMENT` cho audit từng dòng | `NEW`/`OLD` là NULL, không ghi được gì (test nhìn thấy của `func/08` bắt lỗi này) |
| `BEFORE` trigger quên `RETURN NEW` (trả NULL) | Mọi `UPDATE` bị **bỏ qua im lặng** |
| Trigger `UPDATE` chính bảng của nó | Đệ quy vô hạn. Dùng `BEFORE` và sửa `NEW` thay vì `UPDATE` |
| Logic nghiệp vụ nặng trong trigger | Ẩn, khó debug, làm chậm mọi câu ghi. Giữ trigger nhỏ |

Lọc ngay ở định nghĩa trigger để hàm không chạy khi không cần: `CREATE TRIGGER ... AFTER UPDATE OF price ON products FOR EACH ROW WHEN (OLD.price IS DISTINCT FROM NEW.price) EXECUTE FUNCTION ...`.

---

## Phần 7. Bắt lỗi: `EXCEPTION WHEN` (`func/09`)

### 7.1 Các bước

1. Thử thao tác có thể lỗi: `RETURN p_text::INT;`.
2. Tìm **đúng tên lỗi** cần bắt. `'abc'::INT` → `invalid_text_representation` (22P02); `'99999999999'::INT` → `numeric_value_out_of_range` (22003).
3. Bắt **chỉ những lỗi đó**, để các lỗi khác vẫn nổi lên.

```sql
CREATE FUNCTION to_int_or_null(p_text TEXT)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN p_text::INT;                                                 -- Bước 1
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN -- Bước 2 + 3
    RETURN NULL;
END;
$$;
```

### 7.2 Tên lỗi hay gặp

| Tên điều kiện | SQLSTATE | Khi nào |
| --- | --- | --- |
| `division_by_zero` | 22012 | Chia cho 0 |
| `invalid_text_representation` | 22P02 | Ép chuỗi sai định dạng sang số, ngày |
| `numeric_value_out_of_range` | 22003 | Tràn kiểu số |
| `unique_violation` | 23505 | Trùng khóa unique |
| `foreign_key_violation` | 23503 | Vi phạm khóa ngoại |
| `no_data_found` / `too_many_rows` | P0002 / P0003 | `SELECT INTO STRICT` |
| `raise_exception` | P0001 | `RAISE EXCEPTION` không gắn mã |

Bên trong nhánh `EXCEPTION`, `SQLERRM` là thông báo lỗi và `SQLSTATE` là mã lỗi.

### 7.3 Bẫy

- **`WHEN OTHERS THEN RETURN NULL`** nuốt mọi lỗi, kể cả lỗi lập trình (sai tên bảng, sai cột). Dữ liệu sai sẽ âm thầm thành NULL. Chỉ bắt lỗi bạn biết.
- Mỗi khối có `EXCEPTION` tạo một **subtransaction**, chi phí lớn hơn khối thường. Gọi hàm như vậy trên hàng triệu dòng sẽ chậm.
- Từ PostgreSQL 16 có thể kiểm tra mà không cần bắt lỗi: `pg_input_is_valid('abc', 'integer')` trả `false`. Lời giải thay thế cho `func/09`: `CASE WHEN pg_input_is_valid(p_text, 'integer') THEN p_text::INT END`.
- Những thay đổi dữ liệu trong khối `BEGIN` bị **hủy** khi nhảy vào nhánh `EXCEPTION`; những gì xảy ra trước khối thì vẫn giữ.

---

## Phần 8. Volatility, hiệu năng, bảo mật

### 8.1 `IMMUTABLE` / `STABLE` / `VOLATILE`

| Mức | Cam kết với planner | Ví dụ | Hệ quả |
| --- | --- | --- | --- |
| `IMMUTABLE` | Cùng tham số thì **luôn** cùng kết quả, không đọc bảng | `net_price`, `grade_of`, `to_int_or_null` | Được dùng trong **index biểu thức**; có thể tính trước khi lên kế hoạch |
| `STABLE` | Cùng kết quả **trong một câu lệnh**; được đọc bảng, không ghi | `business_days`, `top_customers`, hàm dùng `now()` | Có thể dùng làm điều kiện quét index |
| `VOLATILE` (mặc định) | Không cam kết gì; có thể ghi dữ liệu | `random()`, hàm có `INSERT`/`UPDATE` | Gọi lại cho **từng dòng**, không tối ưu được |

**Khai báo sai rất nguy hiểm**: một hàm đọc bảng mà khai `IMMUTABLE` có thể bị planner cache kết quả cũ hoặc làm index biểu thức chứa dữ liệu sai. Nguyên tắc: không chắc thì để `VOLATILE`; đọc bảng thì `STABLE`; chỉ tính trên tham số thì `IMMUTABLE`.

### 8.2 Hàm và index

- `WHERE lower(email) = 'a@x.com'` không dùng được index thường trên `email`. Tạo index biểu thức: `CREATE INDEX ON users (lower(email));`. Hàm trong index **bắt buộc** là `IMMUTABLE`.
- Hàm `LANGUAGE sql` đơn giản (một câu `SELECT`, không `STRICT` thừa, không `SECURITY DEFINER`) có thể được **inline**: planner chép thân hàm vào câu gọi rồi tối ưu như query thường. Hàm PL/pgSQL thì không bao giờ được inline.

### 8.3 Từng dòng (row-by-row) là chậm

Gọi một hàm PL/pgSQL có truy vấn bên trong cho mỗi dòng của một bảng 1 triệu dòng = 1 triệu truy vấn con. Đây chính là lỗi "N+1" trong database. Nếu có thể, viết lại thành một câu SQL theo tập (JOIN, CTE, window).

### 8.4 `SECURITY DEFINER`

Mặc định hàm chạy với quyền của **người gọi** (`SECURITY INVOKER`). `SECURITY DEFINER` chạy với quyền của **người tạo hàm**, dùng để cho phép người dùng thực hiện một thao tác cụ thể mà không cấp quyền trên bảng. Khi dùng phải cố định `search_path` (`SET search_path = public, pg_temp`), nếu không người gọi có thể tạo bảng/hàm giả cùng tên trong schema của họ để chiếm quyền.

---

## Phần 9. Làm bài `func/*` với `check.py`

Bài `func/*` có thêm section **`-- CALL`** do đề viết sẵn. `check.py` chạy theo thứ tự:

1. Tạo bảng từ `-- INPUT`.
2. Chạy **`-- QUERY` của bạn**: các câu `CREATE FUNCTION` / `CREATE PROCEDURE` / `CREATE TRIGGER`.
3. Chạy **`-- CALL` của đề**: `SELECT * FROM f(...)`, `CALL p(...)` hoặc các câu `UPDATE` kích hoạt trigger.
4. So kết quả của câu cuối (hoặc trạng thái bảng ghi trên dòng ngay trên bảng `-- EXPECTED`) với `-- EXPECTED`.

Test ẩn có thể dùng `-- CALL` khác (ví dụ gọi `top_customers(0)`) và có thể đòi **phải lỗi**: `-- EXPECTED` chỉ có một dòng `ERROR: insufficient funds` nghĩa là các câu lệnh phải thất bại với thông báo chứa chuỗi đó.

Mẹo debug:

- `RAISE NOTICE 'v_balance = %', v_balance;` trong thân hàm: `check.py` in các NOTICE ngay trên output.
- Lỗi bên trong thân hàm (`CONTEXT: PL/pgSQL function f(...) line 3`) được đổi sang **số dòng trong file bài** (`=> line 37 of ...`).
- Lỗi do chính `-- CALL` (ví dụ hàm chưa được tạo, sai số tham số) sẽ báo `raised while running the problem's -- CALL section`. Kiểm tra lại tên hàm và kiểu tham số so với đề.

```
q func              # danh sách bài
q func 3            # theo dõi file, in output mỗi lần lưu
q func 3 h          # nộp: test nhìn thấy + test ẩn
```

---

## Phần 10. Câu hỏi phỏng vấn hay gặp và bảng thuộc lòng

### 10.1 Câu hỏi

| Câu hỏi | Ý chính cần nói |
| --- | --- |
| Function khác procedure thế nào? | Function trả giá trị, dùng trong SQL, không commit. Procedure gọi bằng `CALL`, không trả giá trị (trừ `INOUT`), được `COMMIT`/`ROLLBACK` |
| Khi nào dùng trigger, khi nào không? | Dùng cho audit, ràng buộc không thể lách, cột dẫn xuất. Tránh cho logic nghiệp vụ lớn: ẩn, khó debug, chậm câu ghi |
| `BEFORE` khác `AFTER`? | `BEFORE` sửa được `NEW` hoặc hủy dòng (`RETURN NULL`); `AFTER` thấy dữ liệu đã ghi, dùng cho log/bảng khác |
| Row-level khác statement-level? | Row chạy mỗi dòng, có `OLD`/`NEW`; statement chạy một lần, dùng transition table để xem các dòng |
| `IMMUTABLE`/`STABLE`/`VOLATILE`? | Bảng 8.1. Liên quan tới index biểu thức và tối ưu hóa |
| Làm sao chuyển tiền an toàn khi nhiều phiên song song? | Một transaction, `SELECT ... FOR UPDATE` dòng nguồn, kiểm tra rồi mới ghi; khóa các tài khoản theo thứ tự id để tránh deadlock |
| Upsert trong PostgreSQL? | `INSERT ... ON CONFLICT DO UPDATE` (cần unique); `UPDATE` + `IF NOT FOUND THEN INSERT` có race condition |
| Vì sao vòng lặp PL/pgSQL chậm? | Xử lý từng dòng, mỗi vòng là một truy vấn; SQL theo tập để planner tối ưu cả khối |
| `SECURITY DEFINER` nguy hiểm ở đâu? | Chạy bằng quyền người tạo; phải cố định `search_path` |
| Bắt lỗi bằng `WHEN OTHERS` có sao không? | Nuốt cả lỗi lập trình; chỉ bắt lỗi cụ thể; mỗi khối `EXCEPTION` là một subtransaction |

### 10.2 Bảng thuộc lòng

| Cần | Viết |
| --- | --- |
| Hàm một giá trị, một câu SQL | `CREATE FUNCTION f(p INT) RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT ... $$;` |
| Hàm trả bảng | `RETURNS TABLE (a INT, b TEXT) ... RETURN QUERY SELECT t.a, t.b::TEXT FROM t ...;` |
| Tham số tùy chọn | `p_x TEXT DEFAULT NULL` + `(p_x IS NULL OR col = p_x)`; gọi `f(1, p_x => 'v')` |
| Gán từ truy vấn | `SELECT col INTO v FROM ... ;` (bắt buộc đúng 1 dòng: `INTO STRICT`) |
| Báo lỗi | `RAISE EXCEPTION 'msg: %', v;` |
| Debug | `RAISE NOTICE 'v = %', v;` |
| Câu trước có chạm dòng nào? | `IF NOT FOUND THEN ... END IF;` / `GET DIAGNOSTICS n = ROW_COUNT;` |
| Duyệt từng dòng | `FOR rec IN SELECT ... LOOP ... END LOOP;` |
| Khóa dòng để sửa | `SELECT ... FOR UPDATE` |
| Bắt lỗi cụ thể | `EXCEPTION WHEN division_by_zero THEN ...` |
| Trigger audit | `RETURNS TRIGGER` + `IF NEW.c IS DISTINCT FROM OLD.c` + `AFTER UPDATE ... FOR EACH ROW` |
| Xóa hàm | `DROP FUNCTION f(integer);` / `DROP PROCEDURE p(int, int, numeric);` |
