# Procedure (PL/pgSQL)

> Bài liên quan: `func/06`, `07`, `10`. Output và thông báo lỗi đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** làm sao thực hiện **một nghiệp vụ** gồm nhiều câu ghi dữ liệu (chuyển tiền, tính lãi cho cả loạt tài khoản, cập nhật hoặc thêm mới) sao cho hoặc tất cả cùng thành công, hoặc không có gì thay đổi?

**Vì sao không dùng function:**
- Function trả giá trị và chạy **bên trong** câu SQL của người gọi.
- Procedure là một **hành động** riêng, gọi bằng `CALL`, không có `RETURNS`. Procedure được phép tự `COMMIT`/`ROLLBACK` giữa chừng, miễn là `CALL` không nằm trong một transaction mà phía gọi đã mở.
- Gọi procedure bằng `SELECT transfer(1, 2, 10)` sẽ báo lỗi `transfer(integer, integer, integer) is a procedure`, kèm gợi ý `To call a procedure, use CALL`.

Năm bước:

1. Liệt kê luật nghiệp vụ
2. Kiểm tra tham số
3. Đọc và khóa dữ liệu cần dùng
4. Kiểm tra trên dữ liệu vừa đọc
5. Ghi dữ liệu

Ví dụ chạy xuyên suốt: `transfer(p_from, p_to, p_amount)` chuyển tiền giữa hai tài khoản. Bảng `accounts`:

| account_id | owner | balance |
| --- | --- | --- |
| 1 | An | 100.00 |
| 2 | Binh | 50.00 |
| 3 | Chi | 0.00 |

Phần `-- CALL` của đề:
- `CALL transfer(1, 2, 30.00);`
- `CALL transfer(2, 3, 80.00);`

---

## B1. Liệt kê luật nghiệp vụ

- **Vấn đề:** chỉ viết hai câu `UPDATE` thì mọi luật nghiệp vụ đều bị bỏ qua.
- **Tại sao:** chạy bản không kiểm tra gì với `transfer(2, 3, 80)` và `transfer(1, 9, 30)` (tài khoản 9 không tồn tại):

| account_id | owner | balance |
| --- | --- | --- |
| 1 | An | **70.00** |
| 2 | Binh | **-30.00** |
| 3 | Chi | 80.00 |

Có hai chỗ sai:
- Binh bị âm tiền.
- An mất 30 vào một tài khoản không tồn tại, nên tiền biến mất.

Vì vậy, trước khi viết code, hãy liệt kê đủ các luật:
- Số tiền phải lớn hơn 0.
- Hai tài khoản phải khác nhau.
- Cả hai tài khoản đều phải tồn tại.
- Tài khoản nguồn phải đủ số dư.

## B2. Kiểm tra tham số

- **Vấn đề:** có những luật kiểm tra được ngay trên tham số, không cần đọc bảng.
- **Tại sao:**
  - Kiểm tra những luật này trước, để báo lỗi sớm.
  - `p_amount <= 0` không bắt được `NULL`, nên phải thêm `IS NULL`.
  - `RAISE EXCEPTION` dừng ngay, và hủy mọi thay đổi của câu `CALL`.

```sql
IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'amount must be positive'; END IF;
IF p_from = p_to THEN RAISE EXCEPTION 'same account'; END IF;
```

## B3. Đọc và khóa dữ liệu cần dùng

- **Vấn đề:** hai phiên chuyển tiền chạy song song từ cùng một tài khoản. Cả hai cùng đọc thấy số dư 100, rồi cùng trừ, nên tài khoản bị trừ hai lần.
- **Tại sao:**
  - `SELECT ... INTO ... FOR UPDATE` đọc số dư vào biến và **khóa dòng** đó. Phiên thứ hai phải chờ phiên thứ nhất xong mới đọc được.
  - `SELECT ... INTO` không báo lỗi khi không có dòng nào, mà để biến là `NULL`. Phải kiểm tra bằng `FOUND` ở B4.

```sql
SELECT balance INTO v_balance FROM accounts WHERE account_id = p_from FOR UPDATE;
```

## B4. Kiểm tra trên dữ liệu vừa đọc

- **Vấn đề:** các luật "tài khoản tồn tại" và "đủ số dư" chỉ kiểm tra được sau khi đã đọc bảng.
- **Tại sao:**
  - `FOUND` là biến có sẵn. Nó là `true` nếu câu `SELECT INTO`, `UPDATE`, `INSERT` hoặc `DELETE` vừa chạy có ảnh hưởng tới ít nhất một dòng.
  - Trong thông báo lỗi, mỗi `%` được thay bằng một giá trị, theo thứ tự các tham số đi sau.

```sql
IF NOT FOUND THEN RAISE EXCEPTION 'account not found: %', p_from; END IF;
IF NOT EXISTS (SELECT 1 FROM accounts WHERE account_id = p_to) THEN
  RAISE EXCEPTION 'account not found: %', p_to;
END IF;
IF v_balance < p_amount THEN
  RAISE EXCEPTION 'insufficient funds: balance %, amount %', v_balance, p_amount;
END IF;
```

Chạy thêm `CALL transfer(3, 1, 500.00)` thì báo `ERROR: insufficient funds: balance 80.00, amount 500.00`.

## B5. Ghi dữ liệu

- **Vấn đề:** cập nhật hai tài khoản.
- **Tại sao:**
  - Chỉ ghi khi **mọi** luật đã qua.
  - Dù có lỗi xảy ra **sau** khi đã `UPDATE` một tài khoản, PostgreSQL vẫn hủy toàn bộ câu `CALL`, nên không có chuyện tiền bị trừ mà không được cộng. Tuy vậy, kiểm tra xong hết rồi mới ghi vẫn dễ đọc hơn, và không phải ghi rồi lại hủy.

```sql
UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from;
UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to;
```

Kết quả sau hai câu `CALL` của đề:

| account_id | owner | balance |
| --- | --- | --- |
| 1 | An | 70.00 |
| 2 | Binh | 0.00 |
| 3 | Chi | 80.00 |

## Tổng kết: query đầy đủ

Procedure đầy đủ sau B1 → B5. Bảng `accounts` sau hai câu `CALL` của đề:

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

| account_id | owner | balance |
| --- | --- | --- |
| 1 | An | 70.00 |
| 2 | Binh | 0.00 |
| 3 | Chi | 80.00 |


---

**Khi cần "có rồi thì sửa, chưa có thì thêm" (upsert):**
- `UPDATE` trước, rồi `IF NOT FOUND THEN INSERT`.
- Nếu bảng có `UNIQUE` thì dùng `INSERT ... ON CONFLICT (sku) DO UPDATE`. Cách này là một câu duy nhất, và an toàn khi nhiều phiên chạy cùng lúc. Cách `UPDATE` rồi `INSERT` thì có thể sinh ra hai dòng trùng khi hai phiên cùng chạy.

```sql
UPDATE price_list SET price = p_price, updated_count = updated_count + 1 WHERE sku = p_sku;
IF NOT FOUND THEN
  INSERT INTO price_list (sku, price, updated_count) VALUES (p_sku, p_price, 0);
END IF;
```

Sau các lệnh `CALL upsert_price('B', 6.00)`, `('C', 3.50)`, `('C', 4.00)`:

| sku | price | updated_count |
| --- | --- | --- |
| A | 10.00 | 0 |
| B | 6.00 | 3 |
| C | 4.00 | 1 |

Muốn biết câu vừa chạy ảnh hưởng **bao nhiêu** dòng, dùng `GET DIAGNOSTICS v_rows = ROW_COUNT;`.

**Khi phải xử lý nhiều dòng** (tính lãi cho mọi tài khoản tiết kiệm), có hai cách cho cùng một kết quả:

Cách 1, vòng lặp. Dễ đọc theo từng bước:

```sql
FOR rec IN SELECT account_id, balance FROM accounts WHERE type = 'savings' LOOP
  v_interest := ROUND(rec.balance * p_rate, 2);
  CONTINUE WHEN v_interest <= 0;
  UPDATE accounts SET balance = balance + v_interest WHERE account_id = rec.account_id;
  INSERT INTO interest_log (account_id, interest) VALUES (rec.account_id, v_interest);
END LOOP;
```

Cách 2, theo tập. Một câu lệnh duy nhất, nhanh hơn nhiều khi có hàng triệu dòng:

```sql
WITH calc AS (
  SELECT account_id, ROUND(balance * p_rate, 2) AS interest
  FROM accounts WHERE type = 'savings' AND ROUND(balance * p_rate, 2) > 0
), upd AS (
  UPDATE accounts a SET balance = a.balance + c.interest
  FROM calc c WHERE a.account_id = c.account_id
  RETURNING c.account_id, c.interest
)
INSERT INTO interest_log (account_id, interest) SELECT account_id, interest FROM upd;
```

Ở cách 2, phải tính tiền lãi ở `calc` **trước** khi `UPDATE`. `RETURNING` chỉ thấy số dư **mới**, nên không suy ngược lại tiền lãi từ đó được.

| account_id | balance | interest |
| --- | --- | --- |
| 1 | 1010.00 | 10.00 |
| 2 | 500.00 | NULL |
| 3 | 0.00 | NULL |
| 4 | 0.40 | NULL |
| 5 | 253.01 | 2.51 |

Tài khoản 4 có tiền lãi `ROUND(0.40 × 0.01, 2) = 0`, nên bị bỏ qua.
