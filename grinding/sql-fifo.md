# FIFO (nhập trước, xuất trước)

> Bài liên quan: `fifo/01`–`03`. Output đều chạy thật bằng `check.py`.

## Bài toán

Một cửa hàng nhập hàng thành nhiều **lô**, mỗi lô một giá vốn khác nhau. Khi bán, hàng luôn được lấy từ **lô cũ nhất trước** (FIFO: first in, first out). Câu hỏi: sau khi bán, mỗi lô còn lại bao nhiêu, và hàng tồn kho đáng bao nhiêu tiền?

Cách nghĩ tự nhiên là mô phỏng từng bước: lấy lô 1 cho tới khi hết, rồi sang lô 2... Đó là một vòng lặp, mà SQL không có vòng lặp. Mẹo là **xếp các lô nối tiếp nhau trên một trục số**, rồi xem lượng đã bán phủ tới đâu trên trục đó:

```text
lô 1 (40)  → (0, 40]     lô 2 (30) → (40, 70]     lô 3 (20) → (70, 90]     lô 4 (50) → (90, 140]
đã bán 65  → (0, 65]
⇒ lô 1 hết, lô 2 còn 5 (từ 65 tới 70), lô 3 và lô 4 còn nguyên
```

## Dữ liệu

Hai bảng: các lô nhập và các lần bán. Giá tính bằng nghìn đồng.

`purchases`: mỗi dòng = 1 lô nhập. Các dòng **không** theo thứ tự thời gian.

| lot_id | product | purchase_date | qty | unit_cost_k |
| --- | --- | --- | --- | --- |
| 1 | Green tea | 2024-01-02 | 40 | 10 |
| 4 | Green tea | 2024-02-01 | 50 | 13 |
| 2 | Green tea | 2024-01-10 | 30 | 12 |
| 3 | Green tea | 2024-01-10 | 20 | 11 |
| 5 | Honey | 2024-01-05 | 20 | 50 |
| 6 | Honey | 2024-01-25 | 20 | 55 |
| 7 | Cocoa | 2024-01-15 | 15 | 80 |

`sales`: mỗi dòng = 1 lần bán. Cột `unit_price_k` chỉ dùng ở V2.

| sale_id | product | sale_date | qty | unit_price_k |
| --- | --- | --- | --- | --- |
| 1 | Green tea | 2024-01-20 | 25 | 20 |
| 2 | Green tea | 2024-02-05 | 40 | 21 |
| 3 | Honey | 2024-02-10 | 20 | 70 |

Ba chỗ dễ sai: lô 2 và lô 3 **nhập cùng ngày** 01-10, lô 4 **đứng trước** lô 2 trong bảng, và Cocoa **chưa bán** lần nào.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Tổng đã bán mỗi sản phẩm | CTE `sold` | 1 sản phẩm |
| B2 | Biến mỗi lô thành một đoạn trên trục số | CTE `lots` | **1 lô**, kèm vị trí và tổng đã bán |
| B3 | Phần còn lại của mỗi lô | biểu thức `remaining` | 1 lô, thêm `remaining` |
| B4 | Gộp theo sản phẩm | query cuối | **1 sản phẩm** |

Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Tổng đã bán mỗi sản phẩm (CTE `sold`)

**Ý tưởng:** để biết mỗi lô còn bao nhiêu, ta chỉ cần **tổng** lượng đã bán của sản phẩm. Thứ tự từng lần bán không quan trọng.

| product | sales | sold_qty |
| --- | --- | --- |
| Green tea | 25 + 40 | 65 |
| Honey | 20 | 20 |

```sql
WITH sold AS (
  SELECT product, SUM(qty) AS sold_qty
  FROM sales
  GROUP BY product
)
```

> [!CAUTION]
> ❌ **`JOIN` thẳng `purchases` với `sales`**
>
> Green tea có 4 lô và 2 lần bán. Nối thẳng thì mỗi lô gặp mỗi lần bán, ra 4 × 2 = 8 dòng. Tổng lượng nhập bị tính thành 280 thay vì 140.
>
> → **Sửa:** gộp `sales` về **một dòng mỗi sản phẩm** trước, rồi mới nối với các lô.

## B2. Biến mỗi lô thành một đoạn trên trục số (CTE `lots`)

**Ý tưởng:** xếp các lô theo thứ tự nhập, rồi cộng dồn `qty`. Tổng cộng dồn tới hết lô là **điểm cuối** của lô trên trục số. Điểm đầu là điểm cuối trừ đi `qty` của lô.

**Ví dụ nhỏ:** Green tea.

| lot_id | purchase_date | qty | cum_qty (end point) | range |
| --- | --- | --- | --- | --- |
| 1 | 01-02 | 40 | 40 | (0, 40] |
| 2 | 01-10 | 30 | 70 | (40, 70] |
| 3 | 01-10 | 20 | 90 | (70, 90] |
| 4 | 02-01 | 50 | 140 | (90, 140] |

```sql
lots AS (
  SELECT p.lot_id, p.product, p.purchase_date, p.qty, p.unit_cost_k,
         SUM(p.qty) OVER (PARTITION BY p.product ORDER BY p.purchase_date, p.lot_id) AS cum_qty,
         COALESCE(s.sold_qty, 0) AS sold_qty
  FROM purchases p
  LEFT JOIN sold s ON s.product = p.product
)
```

Đọc từng phần:
- `ORDER BY` bên trong `OVER` quyết định thứ tự cộng dồn, không phụ thuộc thứ tự dòng trong bảng. Lô 4 đứng trước lô 2 trong bảng, nhưng vẫn được cộng sau cùng.
- `LEFT JOIN sold` để Cocoa (chưa bán) vẫn còn. `COALESCE` đổi `NULL` thành 0 bán.

> [!CAUTION]
> ❌ **`ORDER BY purchase_date` mà không có `lot_id`**
>
> Lô 2 và lô 3 cùng ngày 01-10. Khi `ORDER BY` chỉ có ngày, `SUM ... OVER` mặc định cộng **cả nhóm các dòng cùng giá trị** một lúc, nên cả hai lô nhận cùng `cum_qty` = 90. Lô 2 bị coi như nằm ở đoạn (60, 90], và còn lại 25 thay vì 5. Tổng tồn kho Green tea ra 95 thay vì 75.
>
> → **Sửa:** thêm cột phân định thứ tự: `ORDER BY purchase_date, lot_id`. Hai lô cùng ngày thì lô có id nhỏ hơn được dùng trước.

## B3. Phần còn lại của mỗi lô (biểu thức `remaining`)

**Ý tưởng:** lượng đã bán phủ trục số từ 0 tới `sold_qty`. Phần còn lại của một lô là phần đoạn của nó nằm **sau** điểm `sold_qty`. Con số `cum_qty − sold_qty` cho biết từ điểm đã bán tới cuối lô còn bao xa, rồi ta kẹp nó vào khoảng từ 0 tới `qty`:
- `cum_qty − sold_qty ≤ 0`: cả lô nằm trong phần đã bán, còn 0.
- `0 < cum_qty − sold_qty < qty`: lô đang bán dở, còn `cum_qty − sold_qty`.
- `cum_qty − sold_qty ≥ qty`: lô chưa bị đụng tới, còn nguyên `qty`.

**Ví dụ nhỏ:** Green tea, đã bán 65.

| lot_id | qty | cum_qty | cum_qty − 65 | remaining |
| --- | --- | --- | --- | --- |
| 1 | 40 | 40 | −25 | 0 (sold out) |
| 2 | 30 | 70 | 5 | 5 (partly sold) |
| 3 | 20 | 90 | 25 | 20 (untouched, capped at qty) |
| 4 | 50 | 140 | 75 | 50 (untouched, capped at qty) |

```sql
GREATEST(0, LEAST(qty, cum_qty - sold_qty)) AS remaining
```

`LEAST(qty, ...)` chặn trên ở `qty`, `GREATEST(0, ...)` chặn dưới ở 0.

> [!CAUTION]
> ❌ **Lấy `qty − sold_qty` cho từng lô**
>
> Mỗi lô bị trừ **toàn bộ** lượng đã bán, như thể mỗi lô đều bị bán 65. Mọi lô Green tea đều ra số âm (−25, −35, −45, −15).
>
> → **Sửa:** dùng `cum_qty − sold_qty`, rồi kẹp bằng `GREATEST(0, LEAST(qty, ...))`.

## B4. Gộp theo sản phẩm (query cuối)

**Ý tưởng:** cộng phần còn lại của các lô để ra tồn kho mỗi sản phẩm. Mỗi lô có giá vốn riêng, nên giá trị tồn kho là tổng `remaining × unit_cost_k` của từng lô.

**Ví dụ nhỏ:** Green tea.

| lot_id | remaining | unit_cost_k | value |
| --- | --- | --- | --- |
| 2 | 5 | 12 | 60 |
| 3 | 20 | 11 | 220 |
| 4 | 50 | 13 | 650 |
| | **75** | | **930** |

```sql
SELECT product,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)))               AS remaining_qty,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)) * unit_cost_k) AS inventory_value_k
FROM lots
GROUP BY product
ORDER BY product;
```

## Tổng kết: query đầy đủ

```sql
WITH sold AS (                                     -- B1: tổng đã bán mỗi sản phẩm
  SELECT product, SUM(qty) AS sold_qty
  FROM sales
  GROUP BY product
),
lots AS (                                          -- B2: mỗi lô là đoạn (cum_qty − qty, cum_qty]
  SELECT p.lot_id, p.product, p.purchase_date, p.qty, p.unit_cost_k,
         SUM(p.qty) OVER (PARTITION BY p.product ORDER BY p.purchase_date, p.lot_id) AS cum_qty,
         COALESCE(s.sold_qty, 0) AS sold_qty
  FROM purchases p
  LEFT JOIN sold s ON s.product = p.product
)
SELECT product,                                    -- B3 + B4: phần còn lại mỗi lô, gộp theo sản phẩm
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)))               AS remaining_qty,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)) * unit_cost_k) AS inventory_value_k
FROM lots
GROUP BY product
ORDER BY product;
```

Phần còn lại của từng lô sau B3:

| product | lot_id | qty | lo | hi | sold_qty | remaining |
| --- | --- | --- | --- | --- | --- | --- |
| Cocoa | 7 | 15 | 0 | 15 | 0 | 15 |
| Green tea | 1 | 40 | 0 | 40 | 65 | 0 |
| Green tea | 2 | 30 | 40 | 70 | 65 | 5 |
| Green tea | 3 | 20 | 70 | 90 | 65 | 20 |
| Green tea | 4 | 50 | 90 | 140 | 65 | 50 |
| Honey | 5 | 20 | 0 | 20 | 20 | 0 |
| Honey | 6 | 20 | 20 | 40 | 20 | 20 |

Kết quả cuối:

| product | remaining_qty | inventory_value_k |
| --- | --- | --- |
| Cocoa | 15 | 1200 |
| Green tea | 75 | 930 |
| Honey | 20 | 1100 |

---

# Phần 2: Biến thể

Cách "xếp lên trục số rồi xem phủ tới đâu" dùng được cho mọi bài trừ dần một lượng vào các phần theo thứ tự. Mỗi mục dưới đây kể một tình huống như vậy, thử cách làm quen thuộc trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi trả tiền vào hóa đơn cũ nhất trước

Một nhà phân phối có nhiều hóa đơn chưa thanh toán với mỗi khách. Tiền khách trả luôn được trừ vào **hóa đơn cũ nhất trước**. Tiền thừa sau hóa đơn cuối được giữ làm tín dụng, không tính ở đây. Đề: mỗi hóa đơn đã được trả bao nhiêu, còn nợ bao nhiêu, và trạng thái là `Paid`, `Partial` hay `Unpaid`?

```text
invoices (invoice_id, customer, invoice_date, amount_k)   -- mới
payments (payment_id, customer, paid_date, amount_k)      -- mới
```

| invoice_id | customer | invoice_date | amount_k |
| --- | --- | --- | --- |
| 201 | Alpha Mart | 2024-03-01 | 400 |
| 202 | Alpha Mart | 2024-03-10 | 300 |
| 203 | Alpha Mart | 2024-03-20 | 500 |
| 204 | Beta Shop | 2024-03-05 | 600 |
| 205 | Gamma Store | 2024-03-08 | 250 |

| payment_id | customer | paid_date | amount_k |
| --- | --- | --- | --- |
| 1 | Alpha Mart | 2024-03-12 | 350 |
| 2 | Alpha Mart | 2024-03-25 | 200 |
| 3 | Beta Shop | 2024-03-15 | 800 |

Đây đúng là bài FIFO của Phần 1, chỉ đổi tên: lô hàng thành **hóa đơn**, lượng đã bán thành **tổng tiền đã trả**. Thay vì "lô còn lại bao nhiêu", ta hỏi "hóa đơn đã được trả bao nhiêu".

Alpha Mart đã trả tổng cộng 350 + 200 = 550. Xếp các hóa đơn lên trục số: 201 là (0, 400], 202 là (400, 700], 203 là (700, 1200]. Tiền trả phủ (0, 550], nên 201 được trả đủ, 202 được trả 150 (từ 400 tới 550), và 203 chưa được trả gì.

Phần đã trả của một hóa đơn là phần đoạn của nó nằm **trong** đoạn đã trả. Gọi `owed_before` là tổng các hóa đơn trước nó (`cum_amount − amount_k`). Phần đã trả là `total_paid − owed_before`, kẹp vào khoảng 0 tới `amount_k`:

```sql
WITH paid AS (
  SELECT customer, SUM(amount_k) AS total_paid
  FROM payments
  GROUP BY customer
),
inv AS (
  SELECT i.invoice_id, i.customer, i.invoice_date, i.amount_k,
         SUM(i.amount_k) OVER (PARTITION BY i.customer ORDER BY i.invoice_date, i.invoice_id) AS cum_amount,
         COALESCE(p.total_paid, 0) AS total_paid
  FROM invoices i
  LEFT JOIN paid p ON p.customer = i.customer
),
applied AS (
  SELECT invoice_id, customer, invoice_date, amount_k,
         GREATEST(0, LEAST(amount_k, total_paid - (cum_amount - amount_k))) AS paid_k
  FROM inv
)
SELECT invoice_id, customer, amount_k, paid_k, amount_k - paid_k AS outstanding_k,
       CASE WHEN paid_k = amount_k THEN 'Paid'
            WHEN paid_k = 0        THEN 'Unpaid'
            ELSE 'Partial' END AS status
FROM applied
ORDER BY customer, invoice_date, invoice_id;
```

| invoice_id | customer | amount_k | owed_before | total_paid | paid_k | outstanding_k | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201 | Alpha Mart | 400 | 0 | 550 | 400 | 0 | Paid |
| 202 | Alpha Mart | 300 | 400 | 550 | 150 | 150 | Partial |
| 203 | Alpha Mart | 500 | 700 | 550 | 0 | 500 | Unpaid |
| 204 | Beta Shop | 600 | 0 | 800 | 600 | 0 | Paid |
| 205 | Gamma Store | 250 | 0 | 0 | 0 | 250 | Unpaid |

Beta Shop trả 800 cho hóa đơn 600: `LEAST(amount_k, ...)` chặn phần đã trả ở 600, phần thừa 200 bị bỏ qua. Gamma Store chưa trả đồng nào: nhờ `LEFT JOIN` và `COALESCE`, khách này vẫn có dòng với `total_paid` là 0. Nếu dùng `JOIN` thường, hóa đơn 205 biến mất khỏi kết quả.

> [!TIP]
> **Ghi nhớ:** trừ dần một khoản tiền vào các hóa đơn theo thứ tự cũng là FIFO. Phần đã trả của mỗi hóa đơn là `GREATEST(0, LEAST(amount, total_paid − owed_before))`.

## V2. Khi cần biết từng lần bán lấy từ lô nào

Phần 1 chỉ cần tổng đã bán. Đề này hỏi kỹ hơn: **mỗi lần bán có giá vốn bao nhiêu?** Một lần bán có thể lấy hàng từ nhiều lô với giá khác nhau, nên phải biết lần bán đó lấy bao nhiêu đơn vị từ lô nào.

Lần bán 2 của Green tea (40 đơn vị) xảy ra sau lần bán 1 (25 đơn vị). Lô 1 có 40, lần bán 1 đã lấy 25, nên lần bán 2 lấy 15 đơn vị còn lại của lô 1, rồi 25 đơn vị từ lô 2.

### Cả hai phía đều thành đoạn trên trục số

Ở Phần 1, chỉ các lô thành đoạn, phía bán gộp thành một con số. Ở đây ta biến **cả các lần bán** thành đoạn, theo thứ tự bán:

| side | id | qty | range |
| --- | --- | --- | --- |
| lot | 1 | 40 | (0, 40] |
| lot | 2 | 30 | (40, 70] |
| sale | 1 | 25 | (0, 25] |
| sale | 2 | 40 | (25, 65] |

Lần bán 2 là đoạn (25, 65]. Nó chồng lên lô 1 ở (25, 40], tức 15 đơn vị, và chồng lên lô 2 ở (40, 65], tức 25 đơn vị. Đây đúng là bài **tìm hai khoảng chồng nhau** trong doc intervals: nối mỗi lần bán với những lô có đoạn chồng lên đoạn của nó, rồi lấy độ dài phần giao `LEAST(hi) − GREATEST(lo)`.

```sql
WITH lot_ranges AS (
  SELECT lot_id, product, unit_cost_k,
         SUM(qty) OVER (PARTITION BY product ORDER BY purchase_date, lot_id) - qty AS lo,
         SUM(qty) OVER (PARTITION BY product ORDER BY purchase_date, lot_id)       AS hi
  FROM purchases
),
sale_ranges AS (
  SELECT sale_id, product, qty, unit_price_k,
         SUM(qty) OVER (PARTITION BY product ORDER BY sale_date, sale_id) - qty AS lo,
         SUM(qty) OVER (PARTITION BY product ORDER BY sale_date, sale_id)       AS hi
  FROM sales
)
SELECT s.sale_id, s.product, s.qty,
       SUM((LEAST(s.hi, l.hi) - GREATEST(s.lo, l.lo)) * l.unit_cost_k) AS cogs_k,
       s.qty * s.unit_price_k AS revenue_k,
       s.qty * s.unit_price_k - SUM((LEAST(s.hi, l.hi) - GREATEST(s.lo, l.lo)) * l.unit_cost_k) AS gross_profit_k
FROM sale_ranges s
JOIN lot_ranges l ON l.product = s.product AND l.lo < s.hi AND s.lo < l.hi
GROUP BY s.sale_id, s.product, s.qty, s.unit_price_k
ORDER BY s.sale_id;
```

Trước khi `GROUP BY`, mỗi cặp (lần bán, lô) chồng nhau là một dòng:

| sale_id | sale (lo, hi] | lot_id | lot (lo, hi] | units | unit_cost_k |
| --- | --- | --- | --- | --- | --- |
| 1 | (0, 25] | 1 | (0, 40] | 25 | 10 |
| 2 | (25, 65] | 1 | (0, 40] | 15 | 10 |
| 2 | (25, 65] | 2 | (40, 70] | 25 | 12 |
| 3 | (0, 20] | 5 | (0, 20] | 20 | 50 |

| sale_id | product | qty | cogs_k | revenue_k | gross_profit_k |
| --- | --- | --- | --- | --- | --- |
| 1 | Green tea | 25 | 250 | 500 | 250 |
| 2 | Green tea | 40 | 450 | 840 | 390 |
| 3 | Honey | 20 | 1000 | 1400 | 400 |

Lần bán 2: 15 × 10 + 25 × 12 = 450.

### Chỗ dễ sai: dùng `<=` trong điều kiện chồng nhau

Lần bán 3 của Honey là đoạn (0, 20], lô 6 là đoạn (20, 40]. Hai đoạn chỉ **chạm nhau** ở điểm 20, không có đơn vị nào chung. Nếu viết điều kiện bằng `<=`, cặp (lần bán 3, lô 6) vẫn được nối, với số đơn vị bằng 0. Kết quả tiền vẫn đúng vì nhân với 0, nhưng nếu đề hỏi "mỗi lần bán lấy hàng từ mấy lô", lần bán 3 sẽ bị đếm là 2 lô thay vì 1. Dùng `<` chặt ở cả hai vế, giống điều kiện khoảng nửa mở.

> [!TIP]
> **Ghi nhớ:** khớp từng lần bán với từng lô thì biến cả hai phía thành đoạn bằng tổng cộng dồn, nối các đoạn chồng nhau (`l.lo < s.hi AND s.lo < l.hi`), và lấy độ dài phần giao làm số đơn vị.
