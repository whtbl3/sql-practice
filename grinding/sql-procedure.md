# Procedure (PL/pgSQL)

> Bài liên quan: `func/06`, `07`, `10`. Output và thông báo lỗi đều chạy thật bằng `check.py`.

## Bài toán

Một ứng dụng ví cần **chuyển tiền** giữa hai tài khoản: trừ tiền ở tài khoản này, cộng vào tài khoản kia. Đây là **một nghiệp vụ** gồm nhiều câu ghi dữ liệu, và nó phải tuân theo các luật: không chuyển số âm, không chuyển cho chính mình, tài khoản phải tồn tại, phải đủ số dư. Hoặc mọi bước cùng thành công, hoặc không có gì thay đổi.

Ta gói nghiệp vụ đó thành một **procedure** tên `transfer(p_from, p_to, p_amount)`. Procedure khác function ở hai chỗ:
- Function **trả về giá trị** và chạy **bên trong** câu SQL của người gọi (`SELECT f(x)`).
- Procedure là một **hành động** riêng, không có `RETURNS`, và được gọi bằng `CALL transfer(1, 2, 50)`.

## Dữ liệu

`accounts`: mỗi dòng = 1 tài khoản.

| account_id | owner | balance |
| --- | --- | --- |
| 1 | Alice | 200.00 |
| 2 | Ben | 80.00 |
| 3 | Chloe | 0.00 |

Phần `-- CALL` của đề:

```sql
CALL transfer(1, 2, 50.00);    -- Alice chuyển 50 cho Ben
CALL transfer(2, 3, 120.00);   -- Ben chuyển 120 cho Chloe
```

Sau lần chuyển đầu, Ben có 130, nên lần chuyển thứ hai đủ tiền.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code |
| --- | --- | --- |
| B1 | Liệt kê luật nghiệp vụ | (trên giấy, trước khi viết) |
| B2 | Kiểm tra tham số | đầu thân procedure |
| B3 | Đọc và khóa dữ liệu cần dùng | `SELECT ... INTO ... FOR UPDATE` |
| B4 | Kiểm tra trên dữ liệu vừa đọc | `IF NOT FOUND`, so số dư |
| B5 | Ghi dữ liệu | các câu `UPDATE` |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Liệt kê luật nghiệp vụ

**Ý tưởng:** trước khi viết code, liệt kê đủ các luật. Nếu chỉ viết hai câu `UPDATE` (trừ rồi cộng), mọi luật đều bị bỏ qua.

Thử một bản không kiểm tra gì, với hai lần gọi: Ben chuyển 120 (khi chỉ có 80), rồi Alice chuyển 50 cho tài khoản 9 (không tồn tại):

| account_id | owner | balance after |
| --- | --- | --- |
| 1 | Alice | <span class="bad">150.00</span> |
| 2 | Ben | <span class="bad">−40.00</span> |
| 3 | Chloe | 120.00 |

Có hai chỗ sai:
- Ben bị **âm** 40.
- Alice mất 50, nhưng không ai nhận: câu `UPDATE` cộng tiền cho tài khoản 9 không khớp dòng nào, nên tiền **biến mất**.

Các luật cần có:
1. Số tiền phải lớn hơn 0.
2. Hai tài khoản phải khác nhau.
3. Cả hai tài khoản phải tồn tại.
4. Tài khoản nguồn phải đủ số dư.

Luật 1 và 2 kiểm tra được ngay trên tham số (B2). Luật 3 và 4 phải đọc bảng mới biết (B3, B4).

## B2. Kiểm tra tham số (đầu thân procedure)

**Ý tưởng:** kiểm tra những luật không cần đọc bảng **trước tiên**, để báo lỗi sớm. `RAISE EXCEPTION` dừng ngay, và hủy mọi thay đổi mà câu `CALL` này đã làm.

```sql
IF p_amount IS NULL OR p_amount <= 0 THEN
  RAISE EXCEPTION 'amount must be positive';
END IF;
IF p_from = p_to THEN
  RAISE EXCEPTION 'same account';
END IF;
```

Gọi `CALL transfer(1, 2, NULL)` thì dừng với `ERROR: amount must be positive`.

> [!CAUTION]
> ❌ **Chỉ kiểm tra `p_amount <= 0`**
>
> Với số tiền `NULL`, `NULL <= 0` không ra `true`, nên điều kiện không bắt được, và procedure chạy tiếp. Câu `UPDATE ... SET balance = balance - NULL` biến số dư của Alice thành `NULL`.
>
> → **Sửa:** `IF p_amount IS NULL OR p_amount <= 0`.

## B3. Đọc và khóa dữ liệu cần dùng (`SELECT ... INTO ... FOR UPDATE`)

**Ý tưởng:** đọc số dư của tài khoản nguồn vào một biến để kiểm tra ở B4. Biến được khai báo trong phần `DECLARE`, trước `BEGIN`.

Có một chuyện có thể xảy ra khi nhiều người dùng cùng lúc: hai lệnh chuyển tiền từ cùng một tài khoản chạy song song. Cả hai cùng đọc thấy số dư 200, cùng thấy đủ tiền, rồi cùng trừ. Tài khoản bị trừ hai lần dù chỉ đủ cho một. `FOR UPDATE` **khóa dòng** vừa đọc: lệnh thứ hai phải chờ lệnh thứ nhất làm xong mới đọc được, và lúc đó nó thấy số dư đã bị trừ.

```sql
DECLARE
  v_balance NUMERIC;
BEGIN
  ...
  SELECT balance INTO v_balance FROM accounts WHERE account_id = p_from FOR UPDATE;
```

`SELECT ... INTO` **không báo lỗi** khi không tìm thấy dòng nào. Nó chỉ để biến là `NULL`. Vì vậy B4 phải tự kiểm tra.

## B4. Kiểm tra trên dữ liệu vừa đọc (`IF NOT FOUND`, so số dư)

**Ý tưởng:** sau khi đọc, kiểm tra hai luật còn lại.
- `FOUND` là một biến có sẵn trong PL/pgSQL. Nó là `true` nếu câu `SELECT INTO`, `UPDATE`, `INSERT` hoặc `DELETE` vừa chạy có ảnh hưởng tới ít nhất một dòng.
- Tài khoản đích không cần khóa, chỉ cần kiểm tra là nó tồn tại, bằng `NOT EXISTS`.

```sql
IF NOT FOUND THEN
  RAISE EXCEPTION 'account not found: %', p_from;
END IF;
IF NOT EXISTS (SELECT 1 FROM accounts WHERE account_id = p_to) THEN
  RAISE EXCEPTION 'account not found: %', p_to;
END IF;
IF v_balance < p_amount THEN
  RAISE EXCEPTION 'insufficient funds: balance %, amount %', v_balance, p_amount;
END IF;
```

Trong thông báo lỗi, mỗi dấu `%` được thay bằng một giá trị, theo đúng thứ tự các giá trị đứng sau.

| call | result |
| --- | --- |
| `CALL transfer(1, 9, 10.00)` | `ERROR: account not found: 9` |
| `CALL transfer(3, 1, 500.00)` | `ERROR: insufficient funds: balance 0.00, amount 500.00` |

## B5. Ghi dữ liệu (các câu `UPDATE`)

**Ý tưởng:** chỉ ghi khi **mọi** luật đã qua. Trừ tài khoản nguồn, cộng tài khoản đích.

```sql
UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from;
UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to;
```

Kể cả khi có lỗi xảy ra **giữa** hai câu `UPDATE`, PostgreSQL vẫn hủy toàn bộ câu `CALL`. Không có chuyện tiền bị trừ mà không được cộng. Dù vậy, kiểm tra xong hết rồi mới ghi vẫn tốt hơn: code dễ đọc hơn, và không phải ghi rồi lại hủy.

> [!CAUTION]
> ❌ **Gọi procedure bằng `SELECT`**
>
> ```text
> ERROR:  transfer(integer, integer, numeric) is a procedure
> HINT:  To call a procedure, use CALL.
> ```
>
> → **Sửa:** `CALL transfer(1, 2, 10.00);`.

## Tổng kết: query đầy đủ

```sql
CREATE PROCEDURE transfer(p_from INT, p_to INT, p_amount NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  -- B2: kiểm tra tham số
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  IF p_from = p_to THEN
    RAISE EXCEPTION 'same account';
  END IF;

  -- B3: đọc và khóa tài khoản nguồn
  SELECT balance INTO v_balance FROM accounts WHERE account_id = p_from FOR UPDATE;

  -- B4: kiểm tra trên dữ liệu vừa đọc
  IF NOT FOUND THEN
    RAISE EXCEPTION 'account not found: %', p_from;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM accounts WHERE account_id = p_to) THEN
    RAISE EXCEPTION 'account not found: %', p_to;
  END IF;
  IF v_balance < p_amount THEN
    RAISE EXCEPTION 'insufficient funds: balance %, amount %', v_balance, p_amount;
  END IF;

  -- B5: ghi
  UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from;
  UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to;
END;
$$;
```

Bảng `accounts` sau hai câu `CALL` của đề:

| account_id | owner | balance |
| --- | --- | --- |
| 1 | Alice | 150.00 |
| 2 | Ben | 10.00 |
| 3 | Chloe | 120.00 |

---

# Phần 2: Biến thể

Mỗi biến thể dưới đây là một dạng procedure hay gặp. Mỗi mục kể một tình huống, thử cách viết quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi "có rồi thì sửa, chưa có thì thêm" (upsert)

Một bảng giá lưu giá hiện tại của mỗi mã hàng, kèm số lần đã sửa giá. Đề: procedure `upsert_price(p_sku, p_price)`. Nếu mã hàng đã có, đặt giá mới và tăng `updated_count` thêm 1. Nếu chưa có, thêm mới với `updated_count = 0`. Giá `NULL` hoặc âm thì báo lỗi.

```text
price_list (sku, price, updated_count)   -- mới; không có ràng buộc UNIQUE trên sku
```

| sku | price | updated_count |
| --- | --- | --- |
| X | 12.00 | 0 |
| Y | 7.00 | 1 |

Các lệnh gọi: `upsert_price('Y', 7.50)`, `upsert_price('Z', 2.00)`, `upsert_price('Z', 2.50)`.

### Thử cách tự nhiên nhất

Chỉ viết một câu `INSERT`. Kết quả có **hai dòng Y** và **hai dòng Z**:

| sku | price | updated_count |
| --- | --- | --- |
| X | 12.00 | 0 |
| Y | 7.00 | 1 |
| <span class="drop">Y</span> | <span class="drop">7.50</span> | <span class="drop">0</span> |
| Z | 2.00 | 0 |
| <span class="drop">Z</span> | <span class="drop">2.50</span> | <span class="drop">0</span> |

### Cách sửa: `UPDATE` trước, `INSERT` nếu không có gì để sửa

Thử `UPDATE` trước. Biến `FOUND` (B4) cho biết `UPDATE` có sửa được dòng nào không. Nếu không, tức là mã hàng chưa có, thì `INSERT`:

```sql
CREATE PROCEDURE upsert_price(p_sku TEXT, p_price NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_price IS NULL OR p_price < 0 THEN
    RAISE EXCEPTION 'price must be non-negative';
  END IF;

  UPDATE price_list
  SET price = p_price, updated_count = updated_count + 1
  WHERE sku = p_sku;

  IF NOT FOUND THEN
    INSERT INTO price_list (sku, price, updated_count) VALUES (p_sku, p_price, 0);
  END IF;
END;
$$;
```

| call | `UPDATE` matched? | action |
| --- | --- | --- |
| ('Y', 7.50) | yes | Y → 7.50, count 1 → 2 |
| ('Z', 2.00) | no | insert Z, 2.00, count 0 |
| ('Z', 2.50) | yes | Z → 2.50, count 0 → 1 |

| sku | price | updated_count |
| --- | --- | --- |
| X | 12.00 | 0 |
| Y | 7.50 | 2 |
| Z | 2.50 | 1 |

Nếu bảng có ràng buộc `UNIQUE` trên `sku`, PostgreSQL có một câu lệnh làm sẵn việc này: `INSERT ... ON CONFLICT (sku) DO UPDATE SET ...`. Cách đó an toàn hơn khi nhiều phiên chạy cùng lúc. Với `UPDATE` rồi `INSERT`, hai phiên cùng thêm một mã hàng mới có thể cùng thấy "chưa có" và cùng `INSERT`, sinh ra hai dòng trùng. Muốn biết `UPDATE` vừa sửa **bao nhiêu** dòng (không chỉ có hay không), dùng `GET DIAGNOSTICS v_rows = ROW_COUNT;`.

> [!TIP]
> **Ghi nhớ:** upsert không có `UNIQUE` thì `UPDATE` trước, rồi `IF NOT FOUND THEN INSERT`. Có `UNIQUE` thì dùng `INSERT ... ON CONFLICT DO UPDATE`.

## V2. Khi phải xử lý nhiều dòng

Đề: procedure `apply_interest(p_rate)` tính lãi cho **mọi** tài khoản tiết kiệm. Tiền lãi = `ROUND(balance × p_rate, 2)`. Nếu tiền lãi lớn hơn 0, cộng vào số dư và ghi một dòng vào `interest_log`. Lãi suất `NULL` hoặc âm thì báo lỗi.

```text
savings      (account_id, type, balance)   -- mới
interest_log (account_id, interest)        -- mới, ban đầu trống
```

| account_id | type | balance |
| --- | --- | --- |
| 1 | savings | 2000.00 |
| 2 | checking | 300.00 |
| 3 | savings | 0.30 |
| 4 | savings | 120.40 |
| 5 | savings | 0.00 |

Gọi `CALL apply_interest(0.015)`, tức lãi 1.5%.

### Cách 1: vòng lặp từng dòng

`FOR rec IN <câu SELECT> LOOP ... END LOOP` chạy thân vòng lặp một lần cho mỗi dòng. `rec` là một biến kiểu `RECORD` (khai báo trong `DECLARE`), chứa dòng hiện tại: `rec.account_id`, `rec.balance`. `CONTINUE WHEN <điều kiện>` bỏ qua phần còn lại của lượt này và sang dòng kế tiếp:

```sql
CREATE PROCEDURE apply_interest(p_rate NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
  rec RECORD;
  v_interest NUMERIC;
BEGIN
  IF p_rate IS NULL OR p_rate < 0 THEN
    RAISE EXCEPTION 'rate must be non-negative';
  END IF;

  FOR rec IN SELECT account_id, balance FROM savings WHERE type = 'savings' LOOP
    v_interest := ROUND(rec.balance * p_rate, 2);
    CONTINUE WHEN v_interest <= 0;
    UPDATE savings SET balance = balance + v_interest WHERE account_id = rec.account_id;
    INSERT INTO interest_log (account_id, interest) VALUES (rec.account_id, v_interest);
  END LOOP;
END;
$$;
```

| account_id | balance × 1.5% | rounded interest | action |
| --- | --- | --- | --- |
| 1 | 30.000 | 30.00 | add, log |
| 3 | 0.0045 | 0.00 | skip |
| 4 | 1.806 | 1.81 | add, log |
| 5 | 0 | 0.00 | skip |

Tài khoản 2 là `checking`, nên không có trong vòng lặp.

Nếu quên `CONTINUE WHEN v_interest <= 0`, tài khoản 3 và 5 vẫn được ghi vào `interest_log` với tiền lãi **0.00**: hai dòng log vô nghĩa.

### Cách 2: một câu lệnh theo tập

Cùng kết quả, viết trong **một câu lệnh** thay vì một vòng lặp. Với hàng triệu tài khoản, cách này nhanh hơn rất nhiều, vì PostgreSQL xử lý cả tập một lần thay vì chạy hàng triệu câu `UPDATE` nhỏ:

```sql
WITH calc AS (                                     -- tính tiền lãi trước
  SELECT account_id, ROUND(balance * p_rate, 2) AS interest
  FROM savings
  WHERE type = 'savings' AND ROUND(balance * p_rate, 2) > 0
),
upd AS (                                           -- cộng vào số dư
  UPDATE savings s SET balance = s.balance + c.interest
  FROM calc c
  WHERE s.account_id = c.account_id
  RETURNING c.account_id, c.interest
)
INSERT INTO interest_log (account_id, interest)    -- ghi log
SELECT account_id, interest FROM upd;
```

Một CTE có thể chứa câu `UPDATE`. `RETURNING` cho câu `UPDATE` trả về các dòng vừa sửa, để bước sau dùng tiếp. Tiền lãi phải tính ở `calc` **trước** khi `UPDATE`: sau khi cập nhật, `RETURNING` chỉ còn thấy số dư **mới**, không suy ngược lại tiền lãi từ đó được.

Cả hai cách cho cùng kết quả:

| account_id | balance | interest |
| --- | --- | --- |
| 1 | 2030.00 | 30.00 |
| 2 | 300.00 | NULL |
| 3 | 0.30 | NULL |
| 4 | 122.21 | 1.81 |
| 5 | 0.00 | NULL |

> [!TIP]
> **Ghi nhớ:** vòng `FOR rec IN SELECT ... LOOP` dễ đọc theo từng bước. Một câu lệnh theo tập (CTE + `UPDATE ... RETURNING`) nhanh hơn nhiều khi có nhiều dòng.
