# Function (PostgreSQL, `LANGUAGE sql` và PL/pgSQL)

<style>
.markdown-preview tr:has(.drop) td { background: rgba(191, 97, 106, 0.16) !important; }
</style>

> Bài liên quan: `func/01`–`05`, `func/09`. Output và thông báo lỗi đều chạy thật bằng `check.py`. Bài `func/*` có thêm phần `-- CALL`: đề gọi hàm của bạn ở đó.

## Bài toán

Cửa hàng tính **điểm thưởng** cho mỗi lần mua: cứ 10 nghìn đồng được 1 điểm (làm tròn xuống), khách hạng `gold` được nhân đôi. Công thức này cần dùng ở nhiều chỗ: báo cáo, màn hình khách hàng, email cuối tháng... Thay vì chép công thức đi khắp nơi, ta gói nó thành một **hàm** `loyalty_points(amount, tier)`, rồi gọi trong câu SQL như một hàm có sẵn.

Function khác procedure ở chỗ: function **trả về một giá trị** (hoặc một bảng) và được dùng **bên trong** câu SQL (`SELECT f(x)`, `FROM f(x)`). Procedure là một hành động riêng, gọi bằng `CALL` (xem doc procedure).

## Dữ liệu

`purchases`: mỗi dòng = 1 lần mua. Số tiền tính bằng nghìn đồng.

| purchase_id | amount | tier |
| --- | --- | --- |
| 1 | 250 | gold |
| 2 | 99 | silver |
| 3 | 120 | NULL |
| 4 | NULL | gold |

Hai chỗ dễ sai: lần mua 3 **chưa có hạng** (coi như hạng thường), lần mua 4 **chưa có số tiền** (không tính được điểm).

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code |
| --- | --- | --- |
| B1 | Viết câu `SELECT` trước, chưa cần hàm | một câu `SELECT` thường |
| B2 | Chọn chữ ký hàm | `CREATE FUNCTION ... RETURNS ... LANGUAGE` |
| B3 | Xử lý `NULL` | thân hàm, và có hay không có `STRICT` |
| B4 | Khai báo volatility, gọi thử | `IMMUTABLE` / `STABLE` / `VOLATILE`, rồi phần `-- CALL` |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Viết câu `SELECT` trước, chưa cần hàm

**Ý tưởng:** viết thẳng một hàm thì khi kết quả sai, khó biết sai do công thức hay do cú pháp hàm. Ta coi các tham số như các cột, viết công thức trong một câu `SELECT` bình thường, chạy cho đúng, rồi mới gói vào hàm.

```sql
SELECT purchase_id, amount, tier,
       FLOOR(amount / 10)::int * CASE WHEN tier = 'gold' THEN 2 ELSE 1 END AS points
FROM purchases;
```

| purchase_id | amount | tier | points |
| --- | --- | --- | --- |
| 1 | 250 | gold | 50 = 25 × 2 |
| 2 | 99 | silver | 9 = 9 × 1 |
| 3 | 120 | NULL | 12 = 12 × 1 |
| 4 | NULL | gold | NULL |

Lần mua 3 có `tier` là `NULL`. `NULL = 'gold'` không ra `true`, nên `CASE` rơi xuống `ELSE 1`: đúng là "coi như hạng thường". Lần mua 4 có `amount` là `NULL`, nên cả phép tính ra `NULL`.

## B2. Chọn chữ ký hàm (`CREATE FUNCTION ... RETURNS ... LANGUAGE`)

**Ý tưởng:** chữ ký gồm ba quyết định:
- **Tên tham số**: thêm tiền tố `p_` (`p_amount`, `p_tier`), để không bao giờ trùng tên với cột của bảng (lỗi này xuất hiện ở V2).
- **Kiểu trả về** (`RETURNS`): một giá trị (`INT`, `NUMERIC`, `TEXT`...) thì gọi trong `SELECT`. Một bảng (`RETURNS TABLE (...)`) thì gọi trong `FROM` (V2).
- **Ngôn ngữ** (`LANGUAGE`): `sql` nếu thân hàm chỉ là **một câu truy vấn**. `plpgsql` nếu cần biến, `IF`, vòng lặp, báo lỗi hay bắt lỗi (V1, V5). `sql` ngắn hơn, và PostgreSQL có thể gộp thẳng nó vào câu gọi để chạy nhanh hơn.

Thân hàm nằm giữa hai dấu `$$`. Nó chính là câu `SELECT` của B1, với các cột được thay bằng tham số:

```sql
CREATE FUNCTION loyalty_points(p_amount NUMERIC, p_tier TEXT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT FLOOR(p_amount / 10)::int * CASE WHEN p_tier = 'gold' THEN 2 ELSE 1 END
$$;
```

Hai hàm cùng tên nhưng khác kiểu tham số là hai hàm khác nhau (gọi là overloading).

> [!CAUTION]
> ❌ **Đổi kiểu trả về bằng `CREATE OR REPLACE`**
>
> ```text
> ERROR:  cannot change return type of existing function
> HINT:  Use DROP FUNCTION loyalty_points(numeric,text) first.
> ```
>
> `CREATE OR REPLACE` chỉ thay được thân hàm, không đổi được kiểu trả về.
>
> → **Sửa:** `DROP FUNCTION loyalty_points(numeric, text);` rồi tạo lại.

## B3. Xử lý `NULL` (thân hàm, và `STRICT`)

**Ý tưởng:** mỗi tham số có thể là `NULL`, và đề thường gán cho mỗi trường hợp một nghĩa riêng. Ở đây: hạng `NULL` nghĩa là hạng thường, còn số tiền `NULL` thì điểm là `NULL`. Thân hàm từ B1 đã xử lý đúng cả hai, nhờ cách `CASE` và phép nhân đối xử với `NULL`.

PostgreSQL có từ khóa `STRICT`: nếu **bất kỳ** tham số nào là `NULL` thì hàm trả về `NULL` ngay, không chạy thân hàm. Nghe tiện, nhưng nó áp cho **mọi** tham số, kể cả những tham số mà `NULL` có nghĩa riêng.

**Ví dụ nhỏ:** cùng thân hàm, có và không có `STRICT`.

| purchase_id | amount | tier | without `STRICT` | with `STRICT` |
| --- | --- | --- | --- | --- |
| 3 | 120 | NULL | 12 | <span class="drop">NULL</span> |
| 4 | NULL | gold | NULL | NULL |
| ... | | | | |

> [!CAUTION]
> ❌ **Thêm `STRICT` khi một tham số `NULL` có nghĩa riêng**
>
> Lần mua 3 có hạng `NULL`. Đề muốn coi đó là hạng thường, ra 12 điểm. Nhưng với `STRICT`, chỉ cần `p_tier` là `NULL` thì hàm trả `NULL` mà không tính gì.
>
> → **Sửa:** chỉ dùng `STRICT` khi **mọi** tham số `NULL` đều có nghĩa "không tính được". Ngược lại, tự xử lý `NULL` trong thân hàm bằng `COALESCE` hoặc `CASE`.

## B4. Khai báo volatility, gọi thử

**Ý tưởng:** PostgreSQL cần biết hàm có đọc bảng hay ghi dữ liệu không, để biết được phép tối ưu tới đâu. Có ba mức:
- `IMMUTABLE`: chỉ tính trên tham số, cùng đầu vào luôn ra cùng kết quả. Ví dụ `loyalty_points`.
- `STABLE`: có **đọc** bảng, nhưng không ghi. Trong một câu lệnh, cùng đầu vào ra cùng kết quả. Ví dụ hàm đếm ngày làm việc đọc bảng ngày lễ (V4).
- `VOLATILE` (mặc định nếu không ghi gì): có **ghi** dữ liệu, hoặc kết quả có thể khác nhau mỗi lần gọi (ví dụ dùng `random()`).

Khai báo sai rất nguy hiểm: một hàm đọc bảng mà khai `IMMUTABLE` có thể bị PostgreSQL ghi nhớ kết quả cũ, dù bảng đã đổi. Chỉ hàm `IMMUTABLE` mới dùng được trong index biểu thức, ví dụ `CREATE INDEX ON users (lower(email))`.

Gọi thử bằng đúng câu trong phần `-- CALL` của đề:

```sql
SELECT purchase_id, loyalty_points(amount, tier) AS points
FROM purchases
ORDER BY purchase_id;
```

Muốn xem giá trị trung gian khi debug một hàm PL/pgSQL, thêm `RAISE NOTICE 'x = %', v;` vào thân hàm. `check.py` in các NOTICE phía trên output.

## Tổng kết: query đầy đủ

```sql
CREATE FUNCTION loyalty_points(p_amount NUMERIC, p_tier TEXT)   -- B2: tham số p_, kiểu trả về
RETURNS INT
LANGUAGE sql                                                     -- B2: thân hàm là một câu truy vấn
IMMUTABLE                                                        -- B4: chỉ tính trên tham số
AS $$
  SELECT FLOOR(p_amount / 10)::int * CASE WHEN p_tier = 'gold' THEN 2 ELSE 1 END   -- B1 + B3
$$;

-- gọi thử (phần -- CALL)
SELECT purchase_id, loyalty_points(amount, tier) AS points FROM purchases ORDER BY purchase_id;
```

| purchase_id | points |
| --- | --- |
| 1 | 50 |
| 2 | 9 |
| 3 | 12 |
| 4 | NULL |

---

# Phần 2: Biến thể

Mỗi biến thể dưới đây là một dạng hàm hay gặp. Mỗi mục kể một tình huống, thử cách viết quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi cần `IF` và báo lỗi (PL/pgSQL)

Đề: hàm `delivery_label(p_days INT)` gắn nhãn cho thời gian giao hàng: 0 tới 2 ngày là `fast`, 3 tới 5 là `normal`, lâu hơn là `slow`. Chưa có dữ liệu (`NULL`) thì là `unknown`. Số ngày âm là dữ liệu sai: phải **báo lỗi** với nội dung `invalid days: <số ngày>`.

```text
shipments (shipment_id, days)   -- mới: 1, 4, 9, NULL, 2
```

Báo lỗi cần một câu lệnh, không chỉ một biểu thức, nên phải viết bằng PL/pgSQL. Thân hàm PL/pgSQL nằm giữa `BEGIN` và `END`, dùng `IF ... ELSIF ... END IF`, `RETURN` để trả kết quả và `RAISE EXCEPTION` để báo lỗi:

```sql
CREATE FUNCTION delivery_label(p_days INT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_days IS NULL THEN
    RETURN 'unknown';
  ELSIF p_days < 0 THEN
    RAISE EXCEPTION 'invalid days: %', p_days;
  ELSIF p_days <= 2 THEN
    RETURN 'fast';
  ELSIF p_days <= 5 THEN
    RETURN 'normal';
  END IF;
  RETURN 'slow';
END;
$$;
```

| shipment_id | days | label |
| --- | --- | --- |
| 1 | 1 | fast |
| 2 | 4 | normal |
| 3 | 9 | slow |
| 4 | NULL | unknown |
| 5 | 2 | fast |

Gọi `delivery_label(-3)` thì câu lệnh dừng với lỗi `ERROR: invalid days: -3`. Dấu `%` trong thông báo được thay bằng giá trị đứng sau. Báo lỗi tốt hơn là trả về một nhãn trông có vẻ đúng cho dữ liệu sai.

### Chỗ dễ sai: kiểm tra `NULL` sau cùng, hoặc quên kiểm tra

Nếu bỏ nhánh `IS NULL`, lô hàng 4 ra `slow` thay vì `unknown`. Với `NULL`, mọi phép so sánh (`NULL < 0`, `NULL <= 2`...) đều không ra `true`, nên rơi thẳng xuống `RETURN 'slow'` ở cuối. Kiểm tra `IS NULL` phải đặt **trước** mọi phép so sánh.

> [!TIP]
> **Ghi nhớ:** cần `IF`, biến hay báo lỗi thì dùng `LANGUAGE plpgsql`. Kiểm tra `IS NULL` đầu tiên, và `RAISE EXCEPTION` cho dữ liệu sai.

## V2. Khi hàm trả về một bảng

Đề: hàm `top_products(p_n INT)` trả về `p_n` sản phẩm bán chạy nhất (tổng số lượng của các đơn đã thanh toán), dạng bảng `(product TEXT, total_qty NUMERIC)`.

```text
order_items (order_id, product, qty, status)   -- mới
```

| order_id | product | qty | status |
| --- | --- | --- | --- |
| 1 | Tea | 3 | paid |
| 2 | Coffee | 5 | paid |
| 3 | Tea | 4 | paid |
| 4 | Cocoa | 2 | paid |
| 5 | Cocoa | 6 | refunded |
| 6 | Juice | 5 | paid |

Hàm trả bảng khai báo `RETURNS TABLE (cột kiểu, ...)`. Trong PL/pgSQL, `RETURN QUERY <câu SELECT>` đẩy kết quả của câu đó ra làm bảng trả về. Gọi hàm trong `FROM`: `SELECT * FROM top_products(2)`.

### Thử cách tự nhiên nhất

Chép câu `SELECT` vào thân hàm như B1:

```sql
RETURN QUERY
SELECT product, SUM(qty)::NUMERIC FROM order_items WHERE status = 'paid'
GROUP BY product ORDER BY 2 DESC LIMIT p_n;
```

```text
ERROR:  column reference "product" is ambiguous
DETAIL:  It could refer to either a PL/pgSQL variable or a table column.
```

Các cột khai báo trong `RETURNS TABLE (product TEXT, ...)` cũng là **biến** trong thân hàm. Viết `product`, PostgreSQL không biết đó là biến `product` hay cột `order_items.product`.

Sửa bằng cách đặt alias cho bảng và ghi `oi.product` ở mọi chỗ. Nhưng chạy lại thì gặp lỗi thứ hai, nếu quên `::NUMERIC`:

```text
ERROR:  structure of query does not match function result type
DETAIL:  Returned type bigint does not match expected type numeric in column 2.
```

`RETURN QUERY` đòi kiểu của từng cột phải khớp **chính xác** với `RETURNS TABLE`. `SUM` của một cột `INT` trả về `BIGINT`, không phải `NUMERIC`.

### Cách đúng

```sql
CREATE FUNCTION top_products(p_n INT)
RETURNS TABLE (product TEXT, total_qty NUMERIC)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT oi.product, SUM(oi.qty)::NUMERIC
  FROM order_items oi
  WHERE oi.status = 'paid'
  GROUP BY oi.product
  ORDER BY 2 DESC, 1
  LIMIT p_n;
END;
$$;
```

`SELECT * FROM top_products(2);`

| product | total_qty |
| --- | --- |
| Tea | 7 |
| Coffee | 5 |

Coffee và Juice cùng 5. `ORDER BY 2 DESC, 1` xếp theo cột thứ 2 (số lượng), rồi theo cột thứ 1 (tên) khi bằng nhau, nên Coffee đứng trước. Dùng số thứ tự cột trong `ORDER BY` để tránh trùng tên lần nữa. Hàm đọc bảng nên khai `STABLE`.

Kiểu trả về của vài biểu thức hay gặp: `COUNT(*)` và `SUM(cột INT)` ra `BIGINT`. `SUM(cột BIGINT hoặc NUMERIC)`, `AVG(...)`, `ROUND(numeric, n)` ra `NUMERIC`.

> [!TIP]
> **Ghi nhớ:** trong hàm `RETURNS TABLE` viết bằng PL/pgSQL, luôn đặt alias cho bảng (`oi.product`), và ép kiểu cho khớp chính xác với khai báo.

## V3. Khi tham số lọc là tùy chọn

Đề: hàm `orders_of(p_customer_id INT, p_status TEXT DEFAULT NULL)` trả về các đơn của một khách. Nếu không truyền `p_status` (hoặc truyền `NULL`), trả về mọi trạng thái. Nếu có, chỉ trả về trạng thái đó.

```text
customer_orders_tbl (order_id, customer_id, status, amount)   -- mới
```

| order_id | customer_id | status | amount |
| --- | --- | --- | --- |
| 11 | 7 | paid | 80 |
| 12 | 7 | pending | 40 |
| 13 | 8 | paid | 60 |
| 14 | 7 | paid | 25 |

`DEFAULT NULL` cho phép gọi hàm mà bỏ qua tham số đó: `orders_of(7)`. Có thể gọi theo tên tham số: `orders_of(7, p_status => 'paid')`.

### Thử cách tự nhiên nhất

Lọc thẳng bằng `o.status = p_status`. Gọi `orders_of(7)` ra **0 dòng**. Khi không truyền, `p_status` là `NULL`, và `o.status = NULL` không bao giờ ra `true`.

### Cách sửa: `NULL` nghĩa là không lọc

```sql
CREATE FUNCTION orders_of(p_customer_id INT, p_status TEXT DEFAULT NULL)
RETURNS TABLE (order_id INT, status TEXT, amount INT)
LANGUAGE sql
STABLE
AS $$
  SELECT o.order_id, o.status, o.amount
  FROM customer_orders_tbl o
  WHERE o.customer_id = p_customer_id
    AND (p_status IS NULL OR o.status = p_status)
  ORDER BY o.order_id
$$;
```

| call | rows |
| --- | --- |
| `orders_of(7)` | 11 paid, 12 pending, 14 paid |
| `orders_of(7, p_status => 'paid')` | 11 paid, 14 paid |

`(p_status IS NULL OR o.status = p_status)`: khi `p_status` là `NULL`, vế đầu đúng với mọi dòng, nên không lọc gì.

> [!TIP]
> **Ghi nhớ:** tham số lọc tùy chọn thì khai `DEFAULT NULL` và viết `(p IS NULL OR cột = p)`.

## V4. Khi hàm đọc một bảng khác

Đề: hàm `business_days(p_from DATE, p_to DATE)` đếm số **ngày làm việc** từ `p_from` tới `p_to` (tính cả hai đầu): thứ Hai tới thứ Sáu, trừ các ngày lễ trong bảng `holidays`. Nếu `p_from` sau `p_to` thì trả về 0.

```text
holidays (holiday_date, name)          -- mới: 2024-04-30, 2024-05-01
tickets  (ticket_id, opened, closed)   -- mới
```

| ticket_id | opened | closed |
| --- | --- | --- |
| 1 | 2024-04-29 (Mon) | 2024-05-03 (Fri) |
| 2 | 2024-05-03 (Fri) | 2024-05-06 (Mon) |
| 3 | 2024-05-04 (Sat) | 2024-05-05 (Sun) |
| 4 | 2024-05-10 | 2024-05-08 |

Cách nghĩ đầu tiên với PL/pgSQL là một vòng `WHILE` đi từng ngày, đếm từng ngày một. Nhưng một câu SQL đã làm được việc đó: `generate_series` sinh ra từng ngày, rồi đếm những ngày thỏa điều kiện. Hàm `LANGUAGE sql` như vậy ngắn hơn và nhanh hơn vòng lặp:

```sql
CREATE FUNCTION business_days(p_from DATE, p_to DATE)
RETURNS INT
LANGUAGE sql
STABLE
AS $$
  SELECT COUNT(*)::INT
  FROM generate_series(p_from, p_to, INTERVAL '1 day') AS g(d)
  WHERE EXTRACT(ISODOW FROM g.d) < 6
    AND NOT EXISTS (SELECT 1 FROM holidays h WHERE h.holiday_date = g.d::date)
$$;
```

| ticket_id | days in range | weekdays, not holidays | days |
| --- | --- | --- | --- |
| 1 | Mon 04-29 … Fri 05-03 | 04-29, 05-02, 05-03 (04-30, 05-01 are holidays) | 3 |
| 2 | Fri 05-03 … Mon 05-06 | 05-03, 05-06 | 2 |
| 3 | Sat 05-04 … Sun 05-05 | (none) | 0 |
| 4 | 05-10 … 05-08 | `generate_series` gives no days | 0 |

Đọc từng phần:
- `EXTRACT(ISODOW ...)` đánh số thứ Hai = 1, ..., Chủ nhật = 7, nên `< 6` giữ thứ Hai tới thứ Sáu. Nếu dùng `EXTRACT(DOW ...)`, Chủ nhật lại là **0**, cũng `< 6`, và phiếu 3 ra 1 thay vì 0.
- Khi `p_from` sau `p_to`, `generate_series` không sinh ngày nào, nên `COUNT(*)` tự ra 0, không cần `IF`.
- Hàm đọc bảng `holidays`, nên khai `STABLE`, không phải `IMMUTABLE`.

> [!TIP]
> **Ghi nhớ:** khi một câu SQL đã giải được, đừng viết vòng lặp. Hàm có đọc bảng thì khai `STABLE`.

## V5. Khi một thao tác có thể lỗi và đề muốn trả `NULL`

Dữ liệu nhập từ file Excel có cột số lượng dạng chữ. Đề: hàm `to_int_or_null(p_text TEXT)` đổi chữ thành số nguyên, trả `NULL` nếu chữ không phải số nguyên hợp lệ, hoặc vượt giới hạn của kiểu `INT`.

```text
raw_rows (row_id, qty_text)   -- mới: '7', 'x12', '2.0', NULL, '3000000000', '+5'
```

### Thử cách tự nhiên nhất

```sql
CREATE FUNCTION to_int_or_null(p_text TEXT) RETURNS INT LANGUAGE sql IMMUTABLE
AS $$ SELECT p_text::INT $$;
```

Gọi trên cả bảng thì dừng ngay ở dòng 2:

```text
ERROR:  invalid input syntax for type integer: "x12"
```

Một lỗi làm dừng cả câu lệnh, không chỉ dòng đó.

### Cách sửa: bắt đúng những lỗi đã biết

PL/pgSQL có khối `EXCEPTION WHEN <tên lỗi> THEN ...` để bắt lỗi xảy ra trong `BEGIN ... END`. Ta chỉ bắt **đúng hai lỗi** có thể xảy ra khi ép kiểu: chữ không phải số (`invalid_text_representation`) và số quá lớn (`numeric_value_out_of_range`):

```sql
CREATE FUNCTION to_int_or_null(p_text TEXT)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN p_text::INT;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN NULL;
END;
$$;
```

| row_id | qty_text | qty | why |
| --- | --- | --- | --- |
| 1 | 7 | 7 | |
| 2 | x12 | NULL | not a number |
| 3 | 2.0 | NULL | not an integer |
| 4 | NULL | NULL | `NULL::INT` is `NULL` |
| 5 | 3000000000 | NULL | above the `INT` limit (about 2.1 billion) |
| 6 | +5 | 5 | sign is allowed |

> [!CAUTION]
> ❌ **Bắt mọi lỗi bằng `EXCEPTION WHEN OTHERS`**
>
> `WHEN OTHERS` bắt **mọi** lỗi, kể cả lỗi do chính ta viết sai. Một hàm đếm dòng viết nhầm tên bảng thành `raw_rowz`, có `WHEN OTHERS THEN RETURN NULL`, chạy không báo lỗi gì mà chỉ lặng lẽ trả `NULL`. Lỗi lập trình bị giấu đi, rất khó phát hiện.
>
> → **Sửa:** chỉ bắt những lỗi cụ thể mà mình biết sẽ xảy ra.

> [!TIP]
> **Ghi nhớ:** muốn biến một lỗi đã biết thành `NULL`, dùng `EXCEPTION WHEN <tên lỗi cụ thể> THEN RETURN NULL`. Không dùng `WHEN OTHERS`.
