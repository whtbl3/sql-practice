# Trigger

> Bài liên quan: `func/08`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** làm sao để mỗi khi có `INSERT`, `UPDATE` hoặc `DELETE` trên một bảng, database **tự động** làm thêm một việc (ghi log, kiểm tra ràng buộc, cập nhật cột dẫn xuất) mà không ứng dụng nào lách qua được?

**Vì sao không để ứng dụng tự làm:** chỉ cần một đoạn code quên gọi, hoặc ai đó sửa dữ liệu trực tiếp bằng SQL, là log bị thiếu. Trigger chạy **bên trong database**, nên không có lối nào đi vòng qua được.

Một trigger gồm hai phần:
- Một **hàm trigger**: không có tham số, khai báo `RETURNS TRIGGER`.
- Câu `CREATE TRIGGER` gắn hàm đó vào bảng.

Năm bước:

1. Chọn lệnh kích hoạt
2. Chọn `BEFORE` hay `AFTER`
3. Chọn `FOR EACH ROW` hay `FOR EACH STATEMENT`
4. Viết điều kiện bên trong hàm
5. Chọn giá trị trả về

Ví dụ chạy xuyên suốt: ghi vào bảng `price_audit` mỗi khi giá sản phẩm **thực sự** thay đổi. Bảng `products`:

| product_id | name | price |
| --- | --- | --- |
| 1 | Pen | 1.50 |
| 2 | Book | 12.00 |
| 3 | Bag | NULL |

Phần `-- CALL` của đề chạy bốn câu lệnh:
1. Giá Pen: 1.50 → 2.00
2. Giá Book giữ nguyên (`SET price = price`)
3. Giá Bag: `NULL` → 30.00
4. Chỉ đổi tên Pen

Đáp án đúng chỉ có 2 dòng log: câu 1 và câu 3.

---

## B1. Chọn lệnh kích hoạt

- **Vấn đề:** lệnh nào trên bảng làm trigger chạy?
- **Tại sao:** giá chỉ thay đổi qua `UPDATE`, nên chọn `AFTER UPDATE ON products`. Có thể gộp nhiều lệnh, ví dụ `INSERT OR UPDATE`. Có thể giới hạn theo cột, ví dụ `UPDATE OF price`.

## B2. Chọn `BEFORE` hay `AFTER`

- **Vấn đề:** trigger chạy trước hay sau khi dòng được ghi?
- **Tại sao:**

| | Dùng để | Giá trị trả về |
| --- | --- | --- |
| `BEFORE` | **sửa** dòng trước khi ghi (chuẩn hóa email, gán `updated_at`), hoặc chặn dòng đó | `RETURN NEW` thì ghi dòng (đã sửa). `RETURN NULL` thì **bỏ qua dòng đó mà không báo gì** |
| `AFTER` | ghi log, cập nhật bảng khác, khi thay đổi đã chắc chắn được áp dụng | bị bỏ qua |

Ghi log thì chọn `AFTER`. Nếu dùng `BEFORE` mà `RETURN NULL`, câu `UPDATE` bị bỏ qua mà không báo lỗi gì. Thử với giá Pen = 2.00, sau khi chạy giá vẫn là 1.50:

| product_id | name | price |
| --- | --- | --- |
| 1 | Pen | **1.50** |
| 2 | Book | 12.00 |
| 3 | Bag | NULL |

## B3. Chọn `FOR EACH ROW` hay `FOR EACH STATEMENT`

- **Vấn đề:** cần biết giá cũ và giá mới của **từng dòng**.
- **Tại sao:**
  - `FOR EACH ROW` chạy một lần cho mỗi dòng bị ảnh hưởng, và có sẵn hai biến `OLD` và `NEW`.
  - `FOR EACH STATEMENT` chạy một lần cho cả câu lệnh. Khi đó `OLD` và `NEW` là `NULL`, nên điều kiện so sánh luôn sai và **không ghi được dòng log nào** (kết quả 0 dòng).

Biến có sẵn trong hàm trigger:
- `NEW`: không có khi `DELETE`.
- `OLD`: không có khi `INSERT`.
- `TG_OP`: `'INSERT'`, `'UPDATE'` hoặc `'DELETE'`.
- `TG_TABLE_NAME`: tên bảng.

## B4. Viết điều kiện bên trong hàm

- **Vấn đề:** chỉ ghi log khi giá **thực sự** đổi.
- **Tại sao:**

  Không có điều kiện thì ghi 4 dòng. Câu 2 (giá giữ nguyên) và câu 4 (chỉ đổi tên) cũng bị ghi:

  | product_id | old_price | new_price |
  | --- | --- | --- |
  | 1 | 1.50 | 2.00 |
  | 2 | 12.00 | 12.00 |
  | 3 | NULL | 30.00 |
  | 1 | 2.00 | 2.00 |

  Dùng `NEW.price <> OLD.price` thì mất dòng của Bag, vì `NULL <> 30` không ra `true`:

  | product_id | old_price | new_price |
  | --- | --- | --- |
  | 1 | 1.50 | 2.00 |

  `IS DISTINCT FROM` coi `NULL` là một giá trị bình thường, nên cho kết quả đúng.

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

Điều kiện này cũng có thể đặt ngay trong định nghĩa trigger, để hàm không chạy khi không cần: `... FOR EACH ROW WHEN (OLD.price IS DISTINCT FROM NEW.price) EXECUTE FUNCTION ...`.

## B5. Chọn giá trị trả về và gắn trigger

- **Vấn đề:** hàm trigger phải trả về một dòng, hoặc `NULL`.
- **Tại sao:**
  - Với `AFTER`, giá trị trả về bị bỏ qua. Cứ viết `RETURN NEW` cho quen tay.
  - Với `BEFORE`, phải `RETURN NEW`. Nếu không, dòng bị bỏ (xem B2).
  - Đừng `UPDATE` chính bảng của trigger từ bên trong trigger đó, vì sẽ gây đệ quy vô hạn. Muốn sửa dòng đang ghi thì dùng `BEFORE` và gán giá trị vào `NEW`.

```sql
CREATE TRIGGER trg_price_audit
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_price_change();
```

`price_audit` sau bốn câu lệnh:

| product_id | old_price | new_price |
| --- | --- | --- |
| 1 | 1.50 | 2.00 |
| 3 | NULL | 30.00 |

Nên giữ trigger nhỏ. Logic nghiệp vụ nặng đặt trong trigger sẽ khó debug, vì nó chạy ngầm, và làm chậm mọi câu ghi vào bảng.

---

## Tổng kết: query đầy đủ

Hàm trigger và trigger đầy đủ sau B1 → B5. Bảng `price_audit` sau bốn câu lệnh của đề:

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
FOR EACH ROW                                       -- B3: từng dòng, có OLD/NEW
EXECUTE FUNCTION log_price_change();
```

| product_id | old_price | new_price |
| --- | --- | --- |
| 1 | 1.50 | 2.00 |
| 3 | NULL | 30.00 |
