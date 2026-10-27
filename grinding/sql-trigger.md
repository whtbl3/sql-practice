# Trigger

> Bài liên quan: `func/08`. Output và thông báo lỗi đều chạy thật bằng `check.py`.

## Bài toán

Một cửa hàng muốn **ghi lại mọi lần giá sản phẩm thay đổi** vào bảng `price_audit`: sản phẩm nào, giá cũ, giá mới. Chỉ ghi khi giá **thực sự** đổi. Sửa tên hay đặt lại đúng giá cũ thì không ghi.

Có thể để ứng dụng tự ghi log sau mỗi lần sửa giá. Nhưng chỉ cần một đoạn code quên ghi, hoặc ai đó sửa giá trực tiếp bằng SQL, là log bị thiếu. **Trigger** chạy bên trong database: mỗi khi có `INSERT`, `UPDATE` hoặc `DELETE` trên bảng, database **tự động** làm thêm một việc, và không có lối nào đi vòng qua được.

Một trigger gồm hai phần:
- Một **hàm trigger**: hàm không có tham số, khai báo `RETURNS TRIGGER`, chứa việc cần làm.
- Câu `CREATE TRIGGER` gắn hàm đó vào bảng, và nói khi nào thì chạy.

## Dữ liệu

`products`: mỗi dòng = 1 sản phẩm. Desk **chưa có giá**.

| product_id | name | price |
| --- | --- | --- |
| 1 | Mug | 8.00 |
| 2 | Lamp | 25.00 |
| 3 | Desk | NULL |
| 4 | Chair | 40.00 |

`price_audit`: ban đầu trống. Mỗi dòng = 1 lần đổi giá: `(product_id, old_price, new_price)`.

Phần `-- CALL` của đề chạy năm câu lệnh:

| # | statement | price really changes? |
| --- | --- | --- |
| 1 | Mug: 8.00 → 9.50 | yes |
| 2 | Lamp: `SET price = price` | no |
| 3 | Desk: `NULL` → 120.00 | yes |
| 4 | Chair: 40.00 → `NULL` | yes |
| 5 | Mug: only the name changes | no |

Đáp án đúng có 3 dòng log: câu 1, 3, 4.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code |
| --- | --- | --- |
| B1 | Chọn lệnh kích hoạt | `AFTER UPDATE ON products` |
| B2 | Chọn `BEFORE` hay `AFTER` | `AFTER UPDATE ON products` |
| B3 | Chọn mỗi dòng hay mỗi câu lệnh | `FOR EACH ROW` |
| B4 | Viết điều kiện bên trong hàm | `IF ... THEN INSERT ...` trong hàm trigger |
| B5 | Giá trị trả về và gắn trigger | `RETURN NEW`, `CREATE TRIGGER` |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Chọn lệnh kích hoạt

**Ý tưởng:** giá chỉ thay đổi qua câu `UPDATE`, nên trigger chạy khi có `UPDATE` trên bảng `products`. Có thể gộp nhiều lệnh (`INSERT OR UPDATE`), hoặc giới hạn theo cột (`UPDATE OF price`: chỉ chạy khi câu `UPDATE` có nhắc tới cột `price`).

## B2. Chọn `BEFORE` hay `AFTER`

**Ý tưởng:** trigger có thể chạy **trước** hoặc **sau** khi dòng được ghi:
- `BEFORE`: dùng để **sửa** dòng trước khi ghi (chuẩn hóa dữ liệu, xem V1), hoặc để chặn dòng đó. Giá trị trả về của hàm quyết định dòng nào được ghi.
- `AFTER`: dùng để ghi log hay cập nhật bảng khác, khi thay đổi đã chắc chắn được áp dụng. Giá trị trả về bị bỏ qua.

Ghi log thì chọn `AFTER`.

> [!CAUTION]
> ❌ **Ghi log bằng trigger `BEFORE` mà hàm `RETURN NULL`**
>
> Với `BEFORE`, `RETURN NULL` nghĩa là "bỏ dòng này". Câu `UPDATE` giá Mug lên 9.50 bị bỏ qua mà không báo lỗi gì: giá Mug vẫn là 8.00. Nhưng hàm đã kịp `INSERT` một dòng vào `price_audit` trước khi trả về, nên log ghi nhận một lần đổi giá **không hề xảy ra**.
>
> → **Sửa:** ghi log bằng trigger `AFTER`. Nếu dùng `BEFORE`, hàm phải `RETURN NEW`.

## B3. Chọn mỗi dòng hay mỗi câu lệnh (`FOR EACH ROW`)

**Ý tưởng:** cần biết giá cũ và giá mới của **từng dòng**.
- `FOR EACH ROW`: hàm chạy một lần cho **mỗi dòng** bị ảnh hưởng, và có sẵn hai biến: `OLD` (dòng trước khi sửa) và `NEW` (dòng sau khi sửa).
- `FOR EACH STATEMENT`: hàm chạy một lần cho **cả câu lệnh**, dù câu lệnh sửa bao nhiêu dòng. Không có `OLD` / `NEW` của từng dòng.

Các biến có sẵn trong hàm trigger:
- `NEW`: dòng mới. Không có khi `DELETE`.
- `OLD`: dòng cũ. Không có khi `INSERT`.
- `TG_OP`: tên lệnh đang chạy, `'INSERT'`, `'UPDATE'` hoặc `'DELETE'`. Dùng khi một hàm phục vụ nhiều lệnh.
- `TG_TABLE_NAME`: tên bảng.

> [!CAUTION]
> ❌ **Dùng `FOR EACH STATEMENT` khi cần `OLD` / `NEW`**
>
> Ở mức câu lệnh, `OLD` và `NEW` là `NULL`. Điều kiện so sánh giá không bao giờ đúng, và sau năm câu lệnh, `price_audit` vẫn **trống**.
>
> → **Sửa:** `FOR EACH ROW`.

## B4. Viết điều kiện bên trong hàm (`IF ... THEN INSERT ...`)

**Ý tưởng:** chỉ ghi log khi giá cũ và giá mới **khác nhau**. So hai giá trị có thể là `NULL` thì dùng `IS DISTINCT FROM`: nó coi `NULL` là một giá trị bình thường, nên `NULL IS DISTINCT FROM 120` là `true`, còn `NULL IS DISTINCT FROM NULL` là `false`.

```sql
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
```

**Ví dụ nhỏ:** ba cách viết điều kiện, chạy trên năm câu lệnh.

| # | OLD.price → NEW.price | no condition | `<>` | `IS DISTINCT FROM` |
| --- | --- | --- | --- | --- |
| 1 | 8.00 → 9.50 | logged | logged | logged |
| 2 | 25.00 → 25.00 | <span class="bad">logged</span> | | |
| 3 | NULL → 120.00 | logged | <span class="bad">missed</span> | logged |
| 4 | 40.00 → NULL | logged | <span class="bad">missed</span> | logged |
| 5 | 9.50 → 9.50 (name only) | <span class="bad">logged</span> | | |

- Không có điều kiện: ghi 5 dòng, kể cả câu 2 (đặt lại đúng giá cũ) và câu 5 (chỉ đổi tên). Với `FOR EACH ROW`, trigger chạy cho mọi dòng bị `UPDATE`, bất kể cột nào đổi.
- `NEW.price <> OLD.price`: mất câu 3 và câu 4, vì so sánh với `NULL` không ra `true`. Chỉ còn 1 dòng.

Điều kiện cũng có thể đặt ngay trong định nghĩa trigger, để hàm không chạy khi không cần: `... FOR EACH ROW WHEN (OLD.price IS DISTINCT FROM NEW.price) EXECUTE FUNCTION ...`.

## B5. Giá trị trả về và gắn trigger (`RETURN NEW`, `CREATE TRIGGER`)

**Ý tưởng:** hàm trigger luôn phải trả về một dòng hoặc `NULL`.
- Với `AFTER`, giá trị trả về bị bỏ qua. Cứ viết `RETURN NEW` cho quen tay.
- Với `BEFORE`, `RETURN NEW` để ghi dòng (có thể đã sửa), `RETURN NULL` để bỏ dòng (xem B2).

Gắn hàm vào bảng bằng `CREATE TRIGGER`:

```sql
CREATE TRIGGER trg_price_audit
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_price_change();
```

Nên giữ trigger nhỏ. Logic nghiệp vụ nặng đặt trong trigger sẽ khó debug, vì nó chạy ngầm mỗi khi ghi, và làm chậm mọi câu ghi vào bảng.

## Tổng kết: query đầy đủ

```sql
CREATE FUNCTION log_price_change()                 -- hàm trigger: không tham số
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.price IS DISTINCT FROM OLD.price THEN     -- B4: chỉ khi giá thực sự đổi (an toàn với NULL)
    INSERT INTO price_audit (product_id, old_price, new_price)
    VALUES (NEW.product_id, OLD.price, NEW.price);
  END IF;
  RETURN NEW;                                      -- B5
END;
$$;

CREATE TRIGGER trg_price_audit
AFTER UPDATE ON products                           -- B1 + B2: sau mỗi UPDATE
FOR EACH ROW                                       -- B3: từng dòng, có OLD / NEW
EXECUTE FUNCTION log_price_change();
```

`price_audit` sau năm câu lệnh của đề:

| product_id | old_price | new_price |
| --- | --- | --- |
| 1 | 8.00 | 9.50 |
| 3 | NULL | 120.00 |
| 4 | 40.00 | NULL |

---

# Phần 2: Biến thể

## V1. Khi cần sửa dữ liệu trước khi ghi

Đề: email người dùng phải luôn được lưu ở dạng **chữ thường, không có khoảng trắng ở hai đầu**, dù ứng dụng gửi vào dạng gì. Ví dụ `'  Alice@Mail.COM '` phải được lưu thành `'alice@mail.com'`.

```text
users (user_id, email)   -- mới; ban đầu có (1, 'ben@mail.com')
```

Đây là việc của trigger `BEFORE` (B2): sửa dòng **trước khi** nó được ghi. Trong trigger `BEFORE ... FOR EACH ROW`, `NEW` là dòng sắp được ghi. Gán giá trị mới vào `NEW.email`, rồi `RETURN NEW` để ghi dòng đã sửa:

```sql
CREATE FUNCTION normalize_email()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.email := LOWER(TRIM(NEW.email));
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_normalize_email
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION normalize_email();
```

| statement | email sent | email stored |
| --- | --- | --- |
| `INSERT ... (2, '  Alice@Mail.COM ')` | `'  Alice@Mail.COM '` | `alice@mail.com` |
| `UPDATE ... SET email = 'BEN@Work.com' WHERE user_id = 1` | `'BEN@Work.com'` | `ben@work.com` |

`INSERT OR UPDATE` để trigger chạy cả khi thêm mới lẫn khi sửa.

### Ba chỗ dễ sai

**Dùng `AFTER` thay cho `BEFORE`.** Với `AFTER`, dòng đã được ghi xong khi hàm chạy, và giá trị trả về bị bỏ qua. Gán vào `NEW.email` không có tác dụng gì: email của Alice vẫn được lưu nguyên là `'  Alice@Mail.COM '`.

**Quên `RETURN NEW`.** Hàm trigger PL/pgSQL bắt buộc phải có `RETURN`:

```text
ERROR:  control reached end of trigger procedure without RETURN
```

**Sửa bằng cách `UPDATE` chính bảng đó từ trong trigger.** Ví dụ, trong một trigger `AFTER INSERT OR UPDATE` trên `users`, viết `UPDATE users SET email = LOWER(TRIM(email)) WHERE user_id = NEW.user_id`. Câu `UPDATE` này lại kích hoạt chính trigger đó, trigger lại `UPDATE`, cứ thế mãi:

```text
ERROR:  stack depth limit exceeded
```

Muốn sửa dòng đang ghi thì dùng `BEFORE` và gán vào `NEW`, như ở trên.

> [!TIP]
> **Ghi nhớ:** sửa dữ liệu trước khi ghi thì dùng trigger `BEFORE ... FOR EACH ROW`, gán vào `NEW`, và `RETURN NEW`. Không bao giờ `UPDATE` chính bảng của trigger từ bên trong nó.
