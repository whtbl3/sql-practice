# Quy hoạch động (DP) trong SQL

> Bài liên quan: `dp/01`–`05`. Output đều chạy thật bằng `check.py`.

**Câu hỏi của chủ đề:** tìm phương án tốt nhất khi mỗi lựa chọn ảnh hưởng tới các lựa chọn sau. Ví dụ:
- Chọn những ngày khuyến mãi không liền nhau, sao cho doanh thu lớn nhất.
- Dùng ít voucher nhất để trả đúng một số tiền.
- Xếp đồ vào ba lô sao cho không quá tải.

**Vì sao tham lam (chọn cái lớn nhất trước) sai:**
- Ngày khuyến mãi 5, 6, 5: tham lam chọn 6 được 6, nhưng chọn 5 + 5 được 10.
- Voucher {1, 3, 4} trả 6: tham lam lấy 4 + 1 + 1 (3 voucher), nhưng 3 + 3 chỉ cần 2.

DP chia bài toán thành các **trạng thái**, trong đó mỗi trạng thái được tính từ các trạng thái trước nó.

Năm bước:

1. Định nghĩa trạng thái và công thức chuyển
2. Chọn cách viết trong SQL
3. Đánh chỉ số liên tục
4. Chạy vòng lặp, mang theo trạng thái
5. Lấy đáp án

Ví dụ chạy xuyên suốt: chọn ngày khuyến mãi, không được chọn hai ngày liền nhau (bài house robber). Bảng `promo_days`:

| day | extra_revenue_m |
| --- | --- |
| 2024-04-01 | 6 |
| 2024-04-02 | 7 |
| 2024-04-03 | 1 |
| 2024-04-04 | 30 |
| 2024-04-05 | 8 |
| 2024-04-06 | 2 |
| 2024-04-07 | 4 |

---

## B1. Định nghĩa trạng thái và công thức chuyển

- **Vấn đề:** ở ngày i, ta có hai lựa chọn.
  - **Chọn** ngày i: thì không được chọn ngày i−1, nên được `best(i−2) + v(i)`.
  - **Bỏ** ngày i: được `best(i−1)`.
- **Tại sao:** `best(i)` là kết quả tốt nhất khi chỉ xét các ngày từ 1 đến i. Mỗi bước chỉ cần **hai kết quả trước đó**, không cần nhớ đã chọn những ngày nào.

```
best(i) = GREATEST(best(i−1), best(i−2) + v(i))
```

## B2. Chọn cách viết trong SQL

- **Vấn đề:** SQL có ba cách để làm DP. Chọn sai thì hoặc không viết được, hoặc chạy rất chậm.
- **Tại sao:** câu hỏi để chọn là *"giá trị ở bước i có viết được thành `MAX/SUM/MIN(...) OVER (...)` trên **dữ liệu gốc** không?"*

| Trạng thái i cần | Cách | Ví dụ |
| --- | --- | --- |
| một phép tổng hợp đơn giản trên dữ liệu gốc | window function | nước mưa, đoạn có tổng lớn nhất |
| **kết quả DP** của i−1, i−2 | recursive CTE làm vòng lặp | house robber |
| không gian trạng thái nhỏ, cần thử mọi khả năng | recursive CTE liệt kê trạng thái, rồi `MIN`/`MAX` ở ngoài | đổi tiền, knapsack |

House robber cần `best(i−1)`, tức là **kết quả đã tính**, không phải dữ liệu gốc. `LAG(v)` chỉ lấy được `v(i−1)`, không lấy được `best(i−1)`:

| day | v | prev_v |
| --- | --- | --- |
| 2024-04-01 | 6 | NULL |
| 2024-04-02 | 7 | 6 |
| ... | ... | ... |

Vì vậy bài này phải dùng recursive CTE.

**Bài nước mưa thì dùng window được:**
- Mực nước tại i = `LEAST(cao nhất từ trái tới i, cao nhất từ i sang phải) − height`.
- Cả hai giá trị "cao nhất" đều là running `MAX` trên **dữ liệu gốc**, chỉ khác chiều.

```sql
LEAST(MAX(height) OVER (ORDER BY pos ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
      MAX(height) OVER (ORDER BY pos ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)) - height AS water
```

| pos | height | left_max | right_max | water |
| --- | --- | --- | --- | --- |
| 1 | 0 | 0 | 3 | 0 |
| 2 | 1 | 1 | 3 | 0 |
| 3 | 0 | 1 | 3 | 1 |
| 4 | 2 | 2 | 3 | 0 |
| 5 | 1 | 2 | 3 | 1 |
| 6 | 0 | 2 | 3 | 2 |
| 7 | 1 | 2 | 3 | 1 |
| 8 | 3 | 3 | 3 | 0 |
| 9 | 2 | 3 | 2 | 0 |
| 10 | 1 | 3 | 2 | 1 |
| 11 | 2 | 3 | 2 | 0 |
| 12 | 1 | 3 | 1 | 0 |

**Bài đoạn liên tiếp có tổng lớn nhất (Kadane) cũng dùng window được:**
- Tổng của đoạn i..j bằng `prefix(j) − prefix(i−1)`, trong đó `prefix` là tổng dồn.
- Vì vậy, đoạn tốt nhất kết thúc tại j là `prefix(j) − MIN(prefix trước j)`. Đây là một running `MIN` trên tổng dồn.
- Phải thêm một dòng `prefix = 0` ở vị trí 0 (trước ngày đầu tiên). Nếu không, không có đoạn nào bắt đầu từ ngày 1.

```sql
prefix - MIN(prefix) OVER (ORDER BY i ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS best_ending_here
```

| i | day | profit_m | prefix | min_before | best_ending_here |
| --- | --- | --- | --- | --- | --- |
| 0 | | | 0 | NULL | NULL |
| 1 | 03-01 | -2 | -2 | 0 | -2 |
| 2 | 03-02 | 1 | -1 | -2 | 1 |
| 3 | 03-03 | -3 | -4 | -2 | -2 |
| 4 | 03-04 | 4 | 0 | -4 | 4 |
| 5 | 03-05 | -1 | -1 | -4 | 3 |
| 6 | 03-06 | 2 | 1 | -4 | 5 |
| 7 | 03-07 | 1 | 2 | -4 | **6** |
| 8 | 03-08 | -5 | -3 | -4 | 1 |
| 9 | 03-09 | 4 | 1 | -4 | 5 |

- Đáp án là 6: đoạn từ 03-04 (ngay sau chỗ `prefix` nhỏ nhất, −4 ở i = 3) đến 03-07.
- Muốn lấy được cả ngày bắt đầu và ngày kết thúc, ghép từng cặp `prefix` với nhau, sao cho vị trí đầu nhỏ hơn hẳn vị trí cuối. Như vậy mỗi đoạn có ít nhất một ngày.

## B3. Đánh chỉ số liên tục

- **Vấn đề:** vòng lặp cần "lấy phần tử kế tiếp", nhưng ngày tháng thì không phải lúc nào cũng liền nhau.
- **Tại sao:** `ROW_NUMBER()` biến các ngày thành chỉ số 1..n. Khi đó, phần tử kế tiếp là `i + 1`.

```sql
days AS (SELECT ROW_NUMBER() OVER (ORDER BY day) AS i, extra_revenue_m AS v FROM promo_days)
```

| i | day | v |
| --- | --- | --- |
| 1 | 2024-04-01 | 6 |
| 2 | 2024-04-02 | 7 |
| 3 | 2024-04-03 | 1 |
| 4 | 2024-04-04 | 30 |
| 5 | 2024-04-05 | 8 |
| 6 | 2024-04-06 | 2 |
| 7 | 2024-04-07 | 4 |

## B4. Chạy vòng lặp, mang theo trạng thái

- **Vấn đề:** mỗi vòng xử lý đúng một ngày, và cần biết `best(i−1)` và `best(i−2)`.
- **Tại sao:**
  - Mỗi dòng của CTE mang theo hai giá trị: `best` (tức `best(i)`) và `best_prev` (tức `best(i−1)`).
  - Dòng neo `(0, 0, 0)` là trạng thái "trước ngày 1". Nhờ dòng này, bảng rỗng vẫn cho kết quả 0.
  - `JOIN ... ON d.i = dp.i + 1`: khi hết ngày thì không còn dòng khớp, nên vòng lặp tự dừng.
  - Phải ép `0::bigint` ở neo để khớp kiểu với phần đệ quy.

```sql
WITH RECURSIVE dp(i, best, best_prev) AS (
  SELECT 0::bigint, 0::bigint, 0::bigint
  UNION ALL
  SELECT d.i, GREATEST(dp.best, dp.best_prev + d.v), dp.best
  FROM dp JOIN days d ON d.i = dp.i + 1
)
```

| i | v | best | best_prev |
| --- | --- | --- | --- |
| 0 | 0 | 0 | 0 |
| 1 | 6 | 6 | 0 |
| 2 | 7 | 7 | 6 |
| 3 | 1 | 7 | 7 |
| 4 | 30 | 37 | 7 |
| 5 | 8 | 37 | 37 |
| 6 | 2 | 39 | 37 |
| 7 | 4 | 41 | 39 |

Ví dụ ở ngày 4: chọn ngày 4 thì được `best(2) + 30 = 7 + 30 = 37`, bỏ ngày 4 thì giữ `best(3) = 7`. Lấy cái lớn hơn là 37.

**Khi phải liệt kê mọi trạng thái** (ví dụ đổi tiền):
- Trạng thái là (số tiền đã đạt, số voucher đã dùng). Từ mỗi trạng thái, thêm một voucher bất kỳ.
- Dùng `UNION` để mỗi trạng thái chỉ xuất hiện một lần.
- Chặn bằng `<= số tiền lớn nhất cần trả`. Thiếu điều kiện này thì đệ quy chạy mãi.

```sql
WITH RECURSIVE reach(amount, n) AS (
  SELECT 0::bigint, 0::bigint
  UNION
  SELECT r.amount + v.value, r.n + 1
  FROM reach r CROSS JOIN vouchers v
  WHERE r.amount + v.value <= 7
)
```

**Khi mỗi món có hai nhánh lấy hoặc bỏ** (knapsack):
- Phần đệ quy chỉ được nhắc tên CTE một lần, nên không viết hai nhánh bằng `UNION` được.
- Thay vào đó, nhân mỗi dòng thành hai bằng `CROSS JOIN (VALUES (TRUE), (FALSE)) AS t(take)`.
- Cắt nhánh quá tải ngay khi sinh ra, bằng `WHERE` trên trọng lượng.

## B5. Lấy đáp án

- **Vấn đề:** CTE đã sinh ra nhiều dòng. Đáp án nằm ở đâu?
- **Tại sao:**
  - **Vòng lặp tuần tự**: đáp án là dòng cuối cùng, `ORDER BY i DESC LIMIT 1`. Ở đây ra **41**.
  - **Liệt kê trạng thái**: hàm tổng hợp không được dùng trong phần đệ quy, nên `MIN`/`MAX` phải đặt ở truy vấn ngoài.

```sql
SELECT best AS max_extra_revenue FROM dp ORDER BY i DESC LIMIT 1;           -- 41
SELECT amount, MIN(n) AS min_vouchers FROM reach GROUP BY amount;           -- đổi tiền
```

Kết quả đổi tiền với voucher {1, 3, 4}:

| amount | min_vouchers | số trạng thái |
| --- | --- | --- |
| 0 | 0 | 1 |
| 1 | 1 | 1 |
| 2 | 2 | 1 |
| 3 | 1 | 2 |
| 4 | 1 | 3 |
| 5 | 2 | 3 |
| 6 | 2 | 4 |
| 7 | 2 | 5 |

Số tiền 6 có 4 cách đạt được với số voucher khác nhau. `MIN` chọn cách dùng 2 voucher (3 + 3).

Số tiền không đạt được thì không có dòng nào. Dùng `LEFT JOIN` từ bảng `payments` ở truy vấn ngoài để số tiền đó vẫn hiện ra, với giá trị `NULL`.

---

## Tổng kết: query đầy đủ

Ghép B1 → B5 thành một câu:

```sql
WITH RECURSIVE days AS (                           -- B3: chỉ số liên tục
  SELECT ROW_NUMBER() OVER (ORDER BY day) AS i, extra_revenue_m AS v FROM promo_days
),
dp(i, best, best_prev) AS (                        -- B4: mỗi vòng một ngày
  SELECT 0::bigint, 0::bigint, 0::bigint
  UNION ALL
  SELECT d.i, GREATEST(dp.best, dp.best_prev + d.v), dp.best    -- B1: công thức chuyển
  FROM dp JOIN days d ON d.i = dp.i + 1
)
SELECT best AS max_extra_revenue                   -- B5: dòng cuối
FROM dp
ORDER BY i DESC
LIMIT 1;
```

| max_extra_revenue |
| --- |
| 41 |
