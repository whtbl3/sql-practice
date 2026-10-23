# Function (PostgreSQL, `LANGUAGE sql` và PL/pgSQL)

> Bài liên quan: `func/01`–`05`, `func/09`. Output và thông báo lỗi đều chạy thật bằng `check.py`. Bài `func/*` có thêm phần `-- CALL`: đề gọi hàm của bạn ở đó.

**Câu hỏi của chủ đề:** có một phép tính hoặc một truy vấn cần dùng lại nhiều lần với các tham số khác nhau. Ví dụ: giá sau giảm, xếp loại điểm, top N khách, đơn hàng của một khách. Làm sao gói nó lại để gọi trong câu SQL như một hàm có sẵn?

**Function khác procedure ở đâu:** function **trả về giá trị** và được dùng **bên trong** câu SQL (`SELECT f(x)`, `FROM f(x)`). Procedure là một hành động riêng, gọi bằng `CALL` (xem [sql-procedure.md](sql-procedure.md)).

Năm bước:

1. Viết câu `SELECT` trước, chưa cần hàm
2. Chọn chữ ký hàm
3. Xử lý `NULL` và đầu vào sai
4. Khớp tên và kiểu
5. Khai báo volatility, gọi thử

Ví dụ chạy xuyên suốt: hàm `net_price(price, discount_pct)` tính giá sau khi giảm. Bảng `products`:

| product_id | price | discount_pct |
| --- | --- | --- |
| 1 | 100.00 | 10 |
| 2 | 59.99 | NULL |
| 3 | 20.00 | 25 |
| 4 | 9.99 | 33 |

Discount `NULL` nghĩa là không giảm.

---

## B1. Viết câu `SELECT` trước, chưa cần hàm

- **Vấn đề:** viết thẳng hàm thì khi sai, khó biết sai do công thức hay do cú pháp của hàm.
- **Tại sao:** coi tham số như cột, viết công thức trong một câu `SELECT` bình thường, và chạy cho đúng trước.

```sql
SELECT product_id, price, discount_pct,
       ROUND(price * (100 - COALESCE(discount_pct, 0)) / 100, 2) AS net
FROM products;
```

| product_id | price | discount_pct | net |
| --- | --- | --- | --- |
| 1 | 100.00 | 10 | 90.00 |
| 2 | 59.99 | NULL | 59.99 |
| 3 | 20.00 | 25 | 15.00 |
| 4 | 9.99 | 33 | 6.69 |

Với hàm trả bảng (ví dụ top N khách): viết câu `SELECT ... LIMIT 3` với một con số cố định trước, sau đó mới thay `3` bằng tham số.

## B2. Chọn chữ ký hàm

- **Vấn đề:** phải quyết định tên tham số, kiểu trả về và ngôn ngữ viết thân hàm.
- **Tại sao:**

| Phần | Chọn | Vì sao |
| --- | --- | --- |
| Tham số | thêm tiền tố `p_` (`p_price`) | để không trùng tên cột (B4) |
| `RETURNS` | một giá trị (`NUMERIC`), một bảng (`RETURNS TABLE (a INT, b TEXT)`), `VOID` | trả một giá trị thì gọi trong `SELECT`; trả bảng thì gọi trong `FROM` |
| `LANGUAGE` | `sql` nếu thân hàm chỉ là một câu truy vấn; `plpgsql` nếu cần biến, `IF`, vòng lặp, `RAISE`, bắt lỗi | `sql` ngắn hơn, và có thể được planner gộp thẳng vào câu gọi |

```sql
CREATE FUNCTION net_price(p_price NUMERIC, p_discount_pct INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ROUND(p_price * (100 - COALESCE(p_discount_pct, 0)) / 100, 2)
$$;
```

- `CREATE OR REPLACE` không đổi được kiểu trả về. Muốn đổi thì phải `DROP FUNCTION net_price(numeric, integer)` trước.
- Hai hàm cùng tên nhưng khác kiểu tham số là hai hàm khác nhau (overloading).

## B3. Xử lý `NULL` và đầu vào sai

- **Vấn đề:** mỗi tham số có thể là `NULL` hoặc nằm ngoài giá trị hợp lệ, và đề thường gán cho từng trường hợp một nghĩa riêng.
- **Tại sao:**
  - `STRICT` nghĩa là "có **bất kỳ** tham số nào là `NULL` thì trả `NULL`, không chạy thân hàm". Ở bài này, thêm `STRICT` thì sản phẩm 2 (discount `NULL`) ra `NULL` thay vì 59.99.
  - Trong PL/pgSQL, kiểm tra `IS NULL` **trước** mọi phép so sánh. `NULL >= 90` không ra `true` cũng không ra `false`, nên sẽ rơi xuống nhánh cuối cùng.
  - Gặp dữ liệu không hợp lệ thì `RAISE EXCEPTION`. Đừng trả về một giá trị trông có vẻ đúng.

Với `STRICT`:

| product_id | net |
| --- | --- |
| 1 | 90.00 |
| 2 | **NULL** |
| 3 | 15.00 |
| 4 | 6.69 |

Hàm xếp loại điểm (`func/02`) mà quên kiểm tra `NULL`: học sinh 4 có điểm `NULL` ra `F` thay vì `N/A`.

```sql
BEGIN
  IF p_score IS NULL THEN RETURN 'N/A';
  ELSIF p_score < 0 OR p_score > 100 THEN RAISE EXCEPTION 'invalid score: %', p_score;
  ELSIF p_score >= 90 THEN RETURN 'A';
  ELSIF p_score >= 80 THEN RETURN 'B';
  ELSIF p_score >= 65 THEN RETURN 'C';
  END IF;
  RETURN 'F';
END;
```

Gọi `grade_of(120)` thì báo `ERROR: invalid score: 120`.

**Khi tham số dùng để lọc, và `NULL` nghĩa là không lọc:**
- Khai báo `p_status TEXT DEFAULT NULL`, và viết điều kiện `(p_status IS NULL OR o.status = p_status)`.
- Nếu chỉ viết `o.status = p_status`, thì khi không truyền `p_status` hàm trả về **0 dòng**, vì so sánh với `NULL` không ra `true`.
- Gọi theo tên tham số: `customer_orders(1, p_status => 'paid')`.

**Khi một thao tác có thể lỗi và đề muốn trả `NULL` thay vì dừng** (ví dụ ép `'abc'::INT`):
- Bắt **đúng** những lỗi đã biết bằng `EXCEPTION WHEN`.
- Đừng dùng `WHEN OTHERS`, vì nó nuốt cả lỗi lập trình (sai tên bảng, sai tên cột).

```sql
BEGIN
  RETURN p_text::INT;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN RETURN NULL;
END;
```

| row_id | qty_text | không bắt lỗi | có bắt lỗi |
| --- | --- | --- | --- |
| 1 | 12 | 12 | 12 |
| 2 | abc | `invalid input syntax for type integer: "abc"` | NULL |
| 5 | 99999999999 | `value "99999999999" is out of range for type integer` | NULL |
| 6 | -4 | -4 | -4 |

## B4. Khớp tên và kiểu

- **Vấn đề:** với hàm trả bảng viết bằng PL/pgSQL, có hai lỗi gần như chắc chắn sẽ gặp.
- **Tại sao:**
  - **Trùng tên.** Các cột trong `RETURNS TABLE (customer_id INT, ...)` cũng là **biến** trong thân hàm. Viết `SELECT customer_id FROM orders` thì PostgreSQL không biết `customer_id` là biến hay cột:

    ```
    ERROR:  column reference "customer_id" is ambiguous
    DETAIL:  It could refer to either a PL/pgSQL variable or a table column.
    ```

    Cách sửa: đặt alias cho bảng và ghi `o.customer_id` ở mọi chỗ. Với `ORDER BY`, dùng số thứ tự cột.
  - **Sai kiểu.** `RETURN QUERY` đòi kiểu của từng cột phải khớp **chính xác**. `SUM` của cột `INT` trả về `BIGINT`, không phải `NUMERIC`:

    ```
    ERROR:  structure of query does not match function result type
    DETAIL:  Returned type bigint does not match expected type numeric in column 2.
    ```

    Cách sửa: ép kiểu, ví dụ `SUM(o.amount)::NUMERIC`.

```sql
CREATE FUNCTION top_customers(p_n INT)
RETURNS TABLE (customer_id INT, total_spent NUMERIC)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT o.customer_id, SUM(o.amount)::NUMERIC
  FROM orders o WHERE o.status = 'paid'
  GROUP BY o.customer_id
  ORDER BY 2 DESC, 1
  LIMIT p_n;
END;
$$;
```

`SELECT * FROM top_customers(3);`

| customer_id | total_spent |
| --- | --- |
| 2 | 200 |
| 1 | 150 |
| 4 | 150 |

| Biểu thức | Kiểu trả về |
| --- | --- |
| `COUNT(*)`, `SUM(cột INT)` | `BIGINT` |
| `SUM(cột BIGINT / NUMERIC)`, `AVG(...)`, `ROUND(numeric, n)` | `NUMERIC` |
| chuỗi `'abc'` | phải ép `::TEXT` nếu cột trả về là `TEXT` |

## B5. Khai báo volatility, gọi thử

- **Vấn đề:** planner cần biết hàm có đọc bảng hay ghi dữ liệu không, để biết có được tối ưu hay không.
- **Tại sao:** khai báo sai rất nguy hiểm. Một hàm đọc bảng mà khai `IMMUTABLE` có thể bị cache kết quả cũ.

| Hàm | Khai báo | Ví dụ |
| --- | --- | --- |
| chỉ tính trên tham số | `IMMUTABLE` | `net_price`, `grade_of`, `to_int_or_null` |
| có đọc bảng, không ghi | `STABLE` | `top_customers`, đếm ngày làm việc (đọc bảng `holidays`) |
| có ghi dữ liệu, hoặc kết quả ngẫu nhiên | `VOLATILE` (mặc định) | hàm có `INSERT`, hàm dùng `random()` |

- Chỉ hàm `IMMUTABLE` mới dùng được trong index biểu thức, ví dụ `CREATE INDEX ON users (lower(email))`.
- Gọi thử bằng đúng câu trong phần `-- CALL` của đề. Muốn debug, thêm `RAISE NOTICE 'x = %', v;` vào thân hàm; `check.py` in các NOTICE phía trên output.

**Khi một câu SQL đã giải được, đừng viết vòng lặp.** Ví dụ đếm số ngày làm việc:
- `generate_series` sinh từng ngày, `EXTRACT(ISODOW ...) < 6` giữ ngày thường, `NOT EXISTS` loại ngày lễ.
- Một câu `LANGUAGE sql` như vậy ngắn hơn và nhanh hơn một vòng `WHILE` trong PL/pgSQL.

---

## Tổng kết: query đầy đủ

Hàm đầy đủ sau B1 → B5, gọi bằng `SELECT product_id, net_price(price, discount_pct) AS net FROM products`:

```sql
CREATE FUNCTION net_price(p_price NUMERIC, p_discount_pct INT)   -- B2: tham số p_, kiểu trả về
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE                                                        -- B5: chỉ tính trên tham số
AS $$
  SELECT ROUND(p_price * (100 - COALESCE(p_discount_pct, 0)) / 100, 2)   -- B1 + B3: công thức, NULL = không giảm
$$;
```

| product_id | net |
| --- | --- |
| 1 | 90.00 |
| 2 | 59.99 |
| 3 | 15.00 |
| 4 | 6.69 |
