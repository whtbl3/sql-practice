# FIFO (nhập trước, xuất trước)

> Bài liên quan: `fifo/01`–`03`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** khi một lượng (hàng bán ra, tiền khách trả) được trừ vào **các lô theo thứ tự cũ nhất trước**, thì mỗi lô còn lại bao nhiêu, và mỗi lần bán lấy hàng từ lô nào?

**Vì sao khó:** cách nghĩ tự nhiên là mô phỏng từng bước: lấy lô 1 cho đến hết, rồi sang lô 2... Đó là một vòng lặp, và SQL không có vòng lặp. Mẹo là đặt mọi lô nối tiếp nhau trên **một trục số** bằng tổng lũy kế, rồi xem lượng đã dùng phủ tới đâu trên trục đó:

```
lô 1 (100) → (0, 100]    lô 2 (50) → (100, 150]    lô 3 (80) → (150, 230]
đã bán 130 → (0, 130]  ⇒  lô 1 hết, lô 2 còn 20, lô 3 còn nguyên 80
```

Bốn bước:

1. Gộp phía "dùng" về một con số
2. Biến lô thành khoảng vị trí
3. Tính phần còn lại của từng lô
4. Gộp theo sản phẩm

Ví dụ chạy xuyên suốt:

`purchases` (các dòng không theo thứ tự):

| lot_id | product | purchase_date | qty | unit_cost_vnd |
| --- | --- | --- | --- | --- |
| 1 | ST25 rice | 2024-01-05 | 100 | 20000 |
| 3 | ST25 rice | 2024-02-10 | 80 | 21000 |
| 2 | ST25 rice | 2024-01-20 | 50 | 22000 |
| 4 | Fish sauce | 2024-01-03 | 50 | 35000 |
| 5 | Fish sauce | 2024-01-04 | 50 | 36000 |
| 6 | Coffee | 2024-01-08 | 30 | 120000 |

`sales`:

| sale_id | product | sale_date | qty |
| --- | --- | --- | --- |
| 1 | ST25 rice | 2024-01-25 | 60 |
| 2 | ST25 rice | 2024-02-15 | 70 |
| 3 | Fish sauce | 2024-01-30 | 100 |

---

## B1. Gộp phía "dùng" về một con số

- **Vấn đề:** cần biết tổng lượng đã bán của mỗi sản phẩm.
- **Tại sao:** nếu `JOIN` thẳng `purchases` với `sales`, mỗi lô bị nhân lên theo số lần bán. Ví dụ ST25 có 3 lô và 2 lần bán, nên ra 6 dòng, và tổng nhập bị tính thành 460 thay vì 230.

```sql
sold AS (SELECT product, SUM(qty) AS sold_qty FROM sales GROUP BY product)
```

| product | sold_qty |
| --- | --- |
| Fish sauce | 100 |
| ST25 rice | 130 |

## B2. Biến lô thành khoảng vị trí

- **Vấn đề:** mỗi lô cần biết nó nằm ở đoạn nào trên trục số.
- **Tại sao:**
  - Tổng lũy kế theo thứ tự nhập là **điểm cuối** `hi` của lô. Điểm đầu là `lo = hi - qty`.
  - `ORDER BY` trong `OVER` phải có cột tách hòa (`lot_id`). Nếu không, hai lô cùng ngày sẽ bị frame `RANGE` mặc định gộp làm một và có cùng `hi`.
  - Phải sắp theo `ORDER BY` trong `OVER`, không dựa vào thứ tự dòng trong bảng. Trong bảng, lô 3 đứng trước lô 2.
  - Dùng `LEFT JOIN` với `sold` để sản phẩm chưa bán vẫn còn, với `sold_qty = 0`.

```sql
lots AS (
  SELECT p.*,
         SUM(p.qty) OVER (PARTITION BY p.product ORDER BY p.purchase_date, p.lot_id) AS cum_qty,
         COALESCE(s.sold_qty, 0) AS sold_qty
  FROM purchases p LEFT JOIN sold s ON s.product = p.product
)
```

| product | lot_id | purchase_date | qty | lo | hi (cum_qty) | sold_qty |
| --- | --- | --- | --- | --- | --- | --- |
| ST25 rice | 1 | 2024-01-05 | 100 | 0 | 100 | 130 |
| ST25 rice | 2 | 2024-01-20 | 50 | 100 | 150 | 130 |
| ST25 rice | 3 | 2024-02-10 | 80 | 150 | 230 | 130 |
| Fish sauce | 4 | 2024-01-03 | 50 | 0 | 50 | 100 |
| Fish sauce | 5 | 2024-01-04 | 50 | 50 | 100 | 100 |
| Coffee | 6 | 2024-01-08 | 30 | 0 | 30 | 0 |

## B3. Tính phần còn lại của từng lô

- **Vấn đề:** lượng đã bán phủ trục số từ 0 đến `sold`. Mỗi lô còn lại phần nằm **sau** điểm `sold`.
- **Tại sao:** `cum - sold` là phần của trục số tính đến cuối lô mà chưa bị bán. Kẹp giá trị này vào khoảng từ 0 đến `qty`:
  - `cum - sold <= 0`: lô đã bán hết, còn 0.
  - `0 < cum - sold < qty`: lô đang bán dở, còn `cum - sold`.
  - `cum - sold >= qty`: lô chưa bị đụng tới, còn nguyên `qty`.

  Nếu dùng `qty - sold` thì chỉ đúng với lô đầu tiên. Nếu quên `GREATEST(0, ...)` thì lô đã bán hết ra số âm.

```sql
GREATEST(0, LEAST(qty, cum_qty - sold_qty)) AS remaining
```

| product | lot_id | qty | cum_qty | sold_qty | cum − sold | remaining |
| --- | --- | --- | --- | --- | --- | --- |
| ST25 rice | 1 | 100 | 100 | 130 | -30 | 0 |
| ST25 rice | 2 | 50 | 150 | 130 | 20 | 20 |
| ST25 rice | 3 | 80 | 230 | 130 | 100 | 80 |
| Fish sauce | 4 | 50 | 50 | 100 | -50 | 0 |
| Fish sauce | 5 | 50 | 100 | 100 | 0 | 0 |
| Coffee | 6 | 30 | 30 | 0 | 30 | 30 |

**Khi trả tiền vào hóa đơn cũ nhất:** dùng y hệt công thức này, chỉ đổi tên:
- lô hàng thành hóa đơn, đã bán thành đã trả.
- Ta có `paid = GREATEST(0, LEAST(amount, total_paid - owed_before))`, trong đó `owed_before = cum - amount`.
- Khách chưa trả đồng nào: `LEFT JOIN` rồi `COALESCE(total_paid, 0)`.

## B4. Gộp theo sản phẩm

- **Vấn đề:** cần tổng lượng tồn và giá trị tồn kho của mỗi sản phẩm.
- **Tại sao:** mỗi lô còn lại `remaining` đơn vị với giá vốn riêng của lô đó, nên giá trị tồn kho là `SUM(remaining * unit_cost)`.

```sql
SELECT product,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)))                 AS remaining_qty,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)) * unit_cost_vnd) AS inventory_value_vnd
FROM lots GROUP BY product;
```

| product | remaining_qty | inventory_value_vnd |
| --- | --- | --- |
| Coffee | 30 | 3600000 |
| Fish sauce | 0 | 0 |
| ST25 rice | 100 | 2120000 |

ST25: 20 × 22.000 + 80 × 21.000 = 2.120.000.

## Tổng kết: query đầy đủ

Ghép B1 → B4 thành một câu:

```sql
WITH sold AS (                                     -- B1: tổng đã bán mỗi sản phẩm
  SELECT product, SUM(qty) AS sold_qty FROM sales GROUP BY product
),
lots AS (                                          -- B2: mỗi lô thành khoảng (cum - qty, cum]
  SELECT p.product, p.qty, p.unit_cost_vnd,
         SUM(p.qty) OVER (PARTITION BY p.product ORDER BY p.purchase_date, p.lot_id) AS cum_qty,
         COALESCE(s.sold_qty, 0) AS sold_qty
  FROM purchases p LEFT JOIN sold s ON s.product = p.product
)
SELECT product,                                    -- B3 + B4: phần còn lại của từng lô, gộp theo sản phẩm
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)))                 AS remaining_qty,
       SUM(GREATEST(0, LEAST(qty, cum_qty - sold_qty)) * unit_cost_vnd) AS inventory_value_vnd
FROM lots
GROUP BY product
ORDER BY product;
```

| product | remaining_qty | inventory_value_vnd |
| --- | --- | --- |
| Coffee | 30 | 3600000 |
| Fish sauce | 0 | 0 |
| ST25 rice | 100 | 2120000 |


---

## Khi cần biết từng lần bán lấy từ lô nào (giá vốn từng lần bán)

- **Vấn đề:** một con số tổng ở B1 không còn đủ. Mỗi lần bán có thể lấy hàng từ nhiều lô với giá vốn khác nhau.
- **Tại sao:**
  - Biến **cả hai phía** (lô và lần bán) thành khoảng `(lo, hi]` như B2, rồi nối các khoảng chồng nhau, giống bài so hai khoảng thời gian.
  - Phần giao `LEAST(hi) - GREATEST(lo)` là số đơn vị lần bán đó lấy từ lô đó.
  - Điều kiện chồng nhau phải dùng `<` chặt. Hai khoảng chỉ chạm nhau ở đầu mút thì không có đơn vị nào chung.

```sql
JOIN lots l ON l.product = s.product AND l.lo < s.hi AND s.lo < l.hi
-- units = LEAST(s.hi, l.hi) - GREATEST(s.lo, l.lo)
-- cogs  = SUM(units * l.unit_cost_vnd) GROUP BY sale
```

| sale_id | sale (lo, hi] | lot_id | lot (lo, hi] | units | unit_cost_vnd |
| --- | --- | --- | --- | --- | --- |
| 1 | (0, 60] | 1 | (0, 100] | 60 | 20000 |
| 2 | (60, 130] | 1 | (0, 100] | 40 | 20000 |
| 2 | (60, 130] | 2 | (100, 150] | 30 | 22000 |
| 3 | (130, 170] | 2 | (100, 150] | 20 | 22000 |
| 3 | (130, 170] | 3 | (150, 230] | 20 | 21000 |

Lần bán 2 lấy 40 đơn vị từ lô 1 và 30 đơn vị từ lô 2: 40 × 20.000 + 30 × 22.000 = 1.460.000.
