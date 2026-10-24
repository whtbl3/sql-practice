# Churn, growth accounting và NRR

> Bài liên quan: `churn/01`–`06`. Output đều chạy thật bằng `check.py`.

## Bài toán

Một app muốn biết mỗi tháng **mất bao nhiêu người dùng**, và lượng người mới hay người quay lại có bù được phần mất đó không.

Mỗi người dùng, ở mỗi tháng, rơi vào một trong bốn trạng thái:

| Tháng trước | Tháng này | Trạng thái |
| --- | --- | --- |
| (chưa từng xuất hiện) | có hoạt động | `new`: người mới |
| có hoạt động | có hoạt động | `retained`: ở lại |
| không hoạt động | có hoạt động | `resurrected`: quay lại |
| có hoạt động | không hoạt động | `churned`: rời đi |

Đếm số người ở mỗi trạng thái theo từng tháng gọi là **growth accounting**.

Chỗ khó nằm ở `churned`. Một người rời đi ở tháng 3 nghĩa là tháng 3 họ **không có dòng hoạt động nào**. Nếu chỉ nhìn vào các dòng có trong bảng `activity`, ta sẽ không bao giờ thấy được tháng 3 đó.

## Dữ liệu

Hai bảng, quan hệ **1 người dùng – nhiều dòng hoạt động** (`activity.user_id` → `users.user_id`).

`users`: mỗi dòng = 1 người dùng. George chỉ dùng ở V1.

| user_id | name |
| --- | --- |
| 1 | Alice |
| 2 | Ben |
| 3 | Chloe |
| 4 | David |
| 5 | Emma |
| 6 | Frank |
| 7 | George |

`activity`: mỗi dòng = 1 lần người dùng hoạt động (đăng nhập, học một bài...).

| user_id | activity_date |
| --- | --- |
| 1 | 2024-01-05 |
| 1 | 2024-01-25 |
| 6 | 2024-01-10 |
| 2 | 2024-01-15 |
| 3 | 2024-02-02 |
| 1 | 2024-02-10 |
| 6 | 2024-02-20 |
| 1 | 2024-03-03 |
| 4 | 2024-03-08 |
| 6 | 2024-03-15 |
| 4 | 2024-04-02 |
| 3 | 2024-04-18 |
| 5 | 2024-05-03 |
| 2 | 2024-05-05 |
| 1 | 2024-05-12 |
| 4 | 2024-05-20 |
| 5 | 2024-05-28 |

Theo từng người: Alice hoạt động tháng 1, 2, 3, 5 (vắng tháng 4). Ben tháng 1 rồi im tới tháng 5. Chloe tháng 2 và 4. David tháng 3, 4, 5. Emma chỉ tháng 5. Frank tháng 1, 2, 3 rồi thôi.

## Lộ trình

| Bước | Làm gì | Nằm ở đâu trong code | Mỗi dòng là |
| --- | --- | --- | --- |
| B1 | Gom về (người dùng, tháng có hoạt động) | CTE `active_months` | 1 người × 1 tháng có hoạt động |
| B2 | Dựng lưới người dùng × **mọi** tháng | CTE `months`, `firsts`, `grid` | 1 người × 1 tháng, kể cả tháng vắng |
| B3 | So với tháng trước để gắn trạng thái | CTE `labeled` | như trên, thêm trạng thái |
| B4 | Đếm trạng thái theo tháng, tính tỉ lệ | CTE `counts` + query cuối | **1 tháng** |

Mỗi bước là một CTE đọc từ bước trước. Ví dụ trong từng bước chỉ hiện vài dòng để minh họa; `...` là các dòng còn lại. Kết quả đầy đủ nằm ở phần Tổng kết.

---

# Phần 1: Mạch chính

## B1. Gom về (người dùng, tháng có hoạt động) (CTE `active_months`)

**Ý tưởng:** ta chỉ cần biết mỗi người **có hoạt động** trong một tháng hay không. Đổi mỗi ngày thành tháng của nó, rồi bỏ các dòng trùng.

**Ví dụ nhỏ:** Alice có 2 dòng trong tháng 1, sau bước này còn 1.

| user | activity_date | m | reason |
| --- | --- | --- | --- |
| Alice | 2024-01-05 | 2024-01-01 | kept |
| Alice | 2024-01-25 | 2024-01-01 | <span class="drop">same month, merged</span> |
| Alice | 2024-02-10 | 2024-02-01 | kept |
| ... | | | |

```sql
WITH active_months AS (
  SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m
  FROM activity
)
```

> [!CAUTION]
> ❌ **Quên `DISTINCT`**
>
> Alice có 2 dòng (Alice, tháng 1). Ở B2, lưới được `LEFT JOIN` với bảng này, nên ô (Alice, tháng 1) bị nhân thành 2 dòng. Khi đếm ở B4, Alice được tính 2 lần trong số người hoạt động tháng 1.
>
> → **Sửa:** giữ `DISTINCT`, để mỗi (người, tháng) chỉ có đúng một dòng.

## B2. Dựng lưới người dùng × mọi tháng (CTE `months`, `firsts`, `grid`)

**Ý tưởng:** để gắn được nhãn `churned`, tháng người dùng vắng mặt cũng phải **có một dòng**. Ta tự tạo ra các dòng đó. Đầu tiên lấy danh sách mọi tháng. Sau đó, với mỗi người, tạo một dòng cho mỗi tháng kể từ tháng đầu tiên họ xuất hiện. Cuối cùng đánh dấu dòng nào có hoạt động thật.

Vì sao không dùng `LAG` ngay trên `active_months`? Xem Chloe:

| user | m | `LAG(m)` |
| --- | --- | --- |
| Chloe | 2024-02 | NULL |
| Chloe | 2024-04 | 2024-02 |

Chloe rời đi ở tháng 3, nhưng không có dòng tháng 3 nào để gắn nhãn `churned`.

**Ví dụ nhỏ:** sau khi dựng lưới, Chloe có đủ các tháng từ tháng 2.

| user_id | m | active |
| --- | --- | --- |
| 3 (Chloe) | 2024-02 | true |
| 3 (Chloe) | 2024-03 | **false** |
| 3 (Chloe) | 2024-04 | true |
| 3 (Chloe) | 2024-05 | **false** |
| ... | | |

```sql
months AS (                                   -- mọi tháng, từ tháng nhỏ nhất đến lớn nhất
  SELECT generate_series(MIN(m), MAX(m), INTERVAL '1 month')::date AS m
  FROM active_months
),
firsts AS (                                   -- tháng đầu tiên của mỗi người
  SELECT user_id, MIN(m) AS first_m
  FROM active_months
  GROUP BY user_id
),
grid AS (
  SELECT f.user_id, mo.m, f.first_m, a.user_id IS NOT NULL AS active
  FROM firsts f
  JOIN months mo ON mo.m >= f.first_m
  LEFT JOIN active_months a ON a.user_id = f.user_id AND a.m = mo.m
)
```

Đọc `grid` từng phần:
- `generate_series(MIN(m), MAX(m), INTERVAL '1 month')` sinh ra mọi tháng từ 2024-01 đến 2024-05, kể cả tháng không ai hoạt động.
- `JOIN months mo ON mo.m >= f.first_m` cho mỗi người một dòng ở mỗi tháng, **bắt đầu từ tháng đầu tiên của họ**. Chloe bắt đầu tháng 2, nên không có dòng tháng 1.
- `LEFT JOIN active_months` tìm hoạt động thật. Tháng nào không có thì `a.user_id` là `NULL`, nên `active` là `false`.

> [!CAUTION]
> ❌ **`JOIN active_months` thay vì `LEFT JOIN`**
>
> `JOIN` chỉ giữ dòng tìm được hoạt động. Dòng (Chloe, tháng 3) không có hoạt động nên bị xóa, và lưới quay lại y hệt `active_months`: tháng vắng lại biến mất.
>
> → **Sửa:** dùng `LEFT JOIN`, rồi đánh dấu bằng `a.user_id IS NOT NULL`.

## B3. So với tháng trước để gắn trạng thái (CTE `labeled`)

**Ý tưởng:** với mỗi dòng của lưới, nhìn hai thứ: tháng này có hoạt động không (`active`), và tháng trước có không (`LAG(active)`). Ghép hai thông tin đó theo bảng trạng thái ở đầu doc.

**Ví dụ nhỏ:**

| user | m | active | prev_active | status |
| --- | --- | --- | --- | --- |
| Ben | 2024-01 | true | NULL (first month) | `new` |
| Ben | 2024-02 | false | true | `churned` |
| Ben | 2024-03 | false | false | NULL (no row) |
| Ben | 2024-04 | false | false | NULL (no row) |
| Ben | 2024-05 | true | false | `resurrected` |
| ... | | | | |

Tháng 3 và 4, Ben vắng cả tháng này lẫn tháng trước. Không có gì xảy ra ở hai tháng đó, nên không gắn nhãn.

```sql
labeled AS (
  SELECT user_id, m,
         CASE WHEN active AND m = first_m        THEN 'new'
              WHEN active AND LAG(active) OVER w THEN 'retained'
              WHEN active                        THEN 'resurrected'
              WHEN LAG(active) OVER w            THEN 'churned'
         END AS status
  FROM grid
  WINDOW w AS (PARTITION BY user_id ORDER BY m)
)
```

`WINDOW w AS (...)` đặt tên cho cửa sổ để dùng lại hai lần mà không phải viết lại. `LAG(active) OVER w` là giá trị `active` của dòng ngay trước, trong các dòng cùng người, xếp theo tháng.

> [!CAUTION]
> ❌ **Đặt nhánh `resurrected` (`WHEN active`) lên trước nhánh `new`**
>
> Emma chỉ hoạt động tháng 5, đó là tháng đầu tiên của Emma. `CASE` xét `WHEN active` trước, thấy đúng, nên Emma thành `resurrected` thay vì `new`.
>
> → **Sửa:** `new` phải đứng đầu, vì nó là trường hợp cụ thể nhất (có hoạt động **và** là tháng đầu tiên). Nhánh `WHEN active` không kèm điều kiện gì thêm phải đứng sau `new` và `retained`.

## B4. Đếm trạng thái theo tháng, tính tỉ lệ (CTE `counts` + query cuối)

**Ý tưởng:** đếm mỗi trạng thái theo tháng. Từ đó tính thêm hai chỉ số:
- **Churn rate** = số người rời đi trong tháng ÷ số người hoạt động **tháng trước**. Mẫu số là những người "có thể rời đi", tức những người đang hoạt động ở tháng trước.
- **Quick ratio** = (người mới + người quay lại) ÷ người rời đi. Lớn hơn 1 nghĩa là phần thêm vào nhiều hơn phần mất đi.

**Ví dụ nhỏ:** tháng 4.

| April | who | count |
| --- | --- | --- |
| retained | David | 1 |
| resurrected | Chloe | 1 |
| churned | Alice, Frank | 2 |
| mau (active) | David, Chloe | 2 |

Tháng 3 có 3 người hoạt động (Alice, David, Frank), nên churn rate tháng 4 = 2 / 3 = 66.7%. Quick ratio = (0 + 1) / 2 = 0.50: mất nhiều hơn được.

```sql
counts AS (
  SELECT mo.m,
         COUNT(*) FILTER (WHERE l.status IN ('new', 'retained', 'resurrected')) AS mau,
         COUNT(*) FILTER (WHERE l.status = 'new')         AS new_users,
         COUNT(*) FILTER (WHERE l.status = 'retained')    AS retained,
         COUNT(*) FILTER (WHERE l.status = 'resurrected') AS resurrected,
         COUNT(*) FILTER (WHERE l.status = 'churned')     AS churned
  FROM months mo
  LEFT JOIN labeled l ON l.m = mo.m
  GROUP BY mo.m
)
SELECT TO_CHAR(m, 'YYYY-MM') AS month, mau, new_users, retained, resurrected, churned,
       ROUND(100.0 * churned / NULLIF(LAG(mau) OVER (ORDER BY m), 0), 1) AS churn_rate_pct,
       ROUND((new_users + resurrected)::numeric / NULLIF(churned, 0), 2) AS quick_ratio
FROM counts
ORDER BY m;
```

`counts` đi từ `months` rồi `LEFT JOIN labeled`, để tháng không có ai vẫn hiện ra với số 0. `NULLIF(x, 0)` đổi 0 thành `NULL` để tránh lỗi chia cho 0. Ở tháng đầu tiên chưa có tháng trước, nên churn rate là `NULL`.

**Tự kiểm tra:** số người hoạt động tháng này = tháng trước + người mới + người quay lại − người rời đi. Tháng 5: 2 + 1 + 2 − 1 = 4.

> [!CAUTION]
> ❌ **Lấy mẫu số churn rate là số người hoạt động tháng này: `churned / mau`**
>
> Tháng 4 có 2 người rời đi và 2 người hoạt động, nên ra 100%. Nhưng 2 người hoạt động tháng 4 (David, Chloe) không phải là những người có thể rời đi. Những người có thể rời đi là 3 người của tháng 3.
>
> → **Sửa:** chia cho số người hoạt động **tháng trước**: `LAG(mau) OVER (ORDER BY m)`.

## Tổng kết: query đầy đủ

```sql
WITH active_months AS (                            -- B1: (người, tháng có hoạt động)
  SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m
  FROM activity
),
months AS (                                        -- B2: mọi tháng
  SELECT generate_series(MIN(m), MAX(m), INTERVAL '1 month')::date AS m
  FROM active_months
),
firsts AS (                                        -- B2: tháng đầu tiên của mỗi người
  SELECT user_id, MIN(m) AS first_m
  FROM active_months
  GROUP BY user_id
),
grid AS (                                          -- B2: lưới người × tháng
  SELECT f.user_id, mo.m, f.first_m, a.user_id IS NOT NULL AS active
  FROM firsts f
  JOIN months mo ON mo.m >= f.first_m
  LEFT JOIN active_months a ON a.user_id = f.user_id AND a.m = mo.m
),
labeled AS (                                       -- B3: trạng thái so với tháng trước
  SELECT user_id, m,
         CASE WHEN active AND m = first_m        THEN 'new'
              WHEN active AND LAG(active) OVER w THEN 'retained'
              WHEN active                        THEN 'resurrected'
              WHEN LAG(active) OVER w            THEN 'churned'
         END AS status
  FROM grid
  WINDOW w AS (PARTITION BY user_id ORDER BY m)
),
counts AS (                                        -- B4: đếm theo tháng
  SELECT mo.m,
         COUNT(*) FILTER (WHERE l.status IN ('new', 'retained', 'resurrected')) AS mau,
         COUNT(*) FILTER (WHERE l.status = 'new')         AS new_users,
         COUNT(*) FILTER (WHERE l.status = 'retained')    AS retained,
         COUNT(*) FILTER (WHERE l.status = 'resurrected') AS resurrected,
         COUNT(*) FILTER (WHERE l.status = 'churned')     AS churned
  FROM months mo
  LEFT JOIN labeled l ON l.m = mo.m
  GROUP BY mo.m
)
SELECT TO_CHAR(m, 'YYYY-MM') AS month, mau, new_users, retained, resurrected, churned,   -- B4
       ROUND(100.0 * churned / NULLIF(LAG(mau) OVER (ORDER BY m), 0), 1) AS churn_rate_pct,
       ROUND((new_users + resurrected)::numeric / NULLIF(churned, 0), 2) AS quick_ratio
FROM counts
ORDER BY m;
```

Trạng thái của từng người sau B3 (ô trống: không có gì xảy ra):

| user | 2024-01 | 2024-02 | 2024-03 | 2024-04 | 2024-05 |
| --- | --- | --- | --- | --- | --- |
| Alice | new | retained | retained | churned | resurrected |
| Ben | new | churned | | | resurrected |
| Chloe | | new | churned | resurrected | churned |
| David | | | new | retained | retained |
| Emma | | | | | new |
| Frank | new | retained | retained | churned | |

Kết quả cuối:

| month | mau | new_users | retained | resurrected | churned | churn_rate_pct | quick_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 3 | 3 | 0 | 0 | 0 | NULL | NULL |
| 2024-02 | 3 | 1 | 2 | 0 | 1 | 33.3 | 1.00 |
| 2024-03 | 3 | 1 | 2 | 0 | 1 | 33.3 | 1.00 |
| 2024-04 | 2 | 0 | 1 | 1 | 2 | 66.7 | 0.50 |
| 2024-05 | 4 | 1 | 1 | 2 | 1 | 50.0 | 3.00 |

---

# Phần 2: Biến thể

Đề thực tế thường đổi một chi tiết so với mạch chính. Có đề chỉ hỏi trạng thái tại một ngày, có đề dùng hợp đồng thuê bao thay vì dòng hoạt động, có đề đo bằng tiền thay vì đếm người... Mỗi mục dưới đây kể một tình huống như vậy. Ta thử cách làm quen thuộc, chạy trên dữ liệu ví dụ để xem nó sai ở đâu, rồi sửa.

## V1. Khi chỉ cần trạng thái tại một ngày

Không phải đề nào cũng hỏi trạng thái theo từng tháng. Một đề đơn giản hơn: **tại ngày 2024-04-30, mỗi người dùng đang ở tình trạng nào?** Đề đặt luật theo số ngày kể từ lần hoạt động cuối:

| Số ngày không hoạt động | Trạng thái |
| --- | --- |
| chưa từng hoạt động | `Never active` |
| ≤ 30 | `Active` |
| ≤ 90 | `At risk` |
| còn lại | `Lapsed` |

Chỉ có một mốc thời gian nên không cần lưới. Mỗi người chỉ cần một con số: ngày hoạt động cuối cùng, tính đến ngày chốt. Ta đi từ `users` rồi `LEFT JOIN activity` để giữ cả người chưa hoạt động:

```sql
SELECT u.user_id, u.name, MAX(a.activity_date) AS last_active,
       DATE '2024-04-30' - MAX(a.activity_date) AS days_inactive,
       CASE WHEN MAX(a.activity_date) IS NULL                  THEN 'Never active'
            WHEN DATE '2024-04-30' - MAX(a.activity_date) <= 30 THEN 'Active'
            WHEN DATE '2024-04-30' - MAX(a.activity_date) <= 90 THEN 'At risk'
            ELSE 'Lapsed' END AS status
FROM users u
LEFT JOIN activity a
       ON a.user_id = u.user_id
      AND a.activity_date <= DATE '2024-04-30'
GROUP BY u.user_id, u.name
ORDER BY u.user_id;
```

| name | last_active | days_inactive | status |
| --- | --- | --- | --- |
| Alice | 2024-03-03 | 58 | At risk |
| Ben | 2024-01-15 | 106 | Lapsed |
| Chloe | 2024-04-18 | 12 | Active |
| David | 2024-04-02 | 28 | Active |
| Emma | NULL | NULL | Never active |
| Frank | 2024-03-15 | 46 | At risk |
| George | NULL | NULL | Never active |

Để ý Emma: Emma có hoạt động, nhưng toàn bộ là trong tháng 5, sau ngày chốt. Tính tại 2024-04-30 thì Emma chưa từng hoạt động. Alice và Ben cũng vậy: hoạt động tháng 5 của họ không được tính.

Có hai chỗ dễ sai. Chỗ thứ nhất: viết điều kiện ngày ở `WHERE` thay vì trong `ON`. `WHERE` chạy sau `LEFT JOIN` và xóa mọi dòng không thỏa, kể cả dòng `NULL` của người không có hoạt động nào hợp lệ. Emma và George biến mất khỏi kết quả, chỉ còn 5 người.

Chỗ thứ hai là thứ tự các nhánh. Nếu không có nhánh `IS NULL`, hoặc đặt nó ở cuối, thì Emma và George có `days_inactive` là `NULL`. `NULL <= 30` và `NULL <= 90` đều không đúng, nên cả hai rơi xuống `ELSE` và thành `Lapsed`, như thể họ từng hoạt động rồi bỏ đi. Một người chưa từng dùng app thì không thể "rời bỏ" được, nên nhánh `IS NULL` phải đứng **đầu tiên**.

> [!TIP]
> **Ghi nhớ:** trạng thái tại một ngày thì không cần lưới. Dùng `MAX(ngày)` + `CASE`, đặt điều kiện ngày trong `ON`, và nhánh `IS NULL` lên đầu.

## V2. Khi dữ liệu là hợp đồng thuê bao

Ở mạch chính, "hoạt động" là có ít nhất một dòng trong `activity`. Với dịch vụ thuê bao (nhạc, phim, phần mềm), dữ liệu lại là **hợp đồng**: mỗi dòng có ngày bắt đầu và ngày kết thúc.

```text
subscriptions (sub_id, user_id, start_date, end_date)   -- mới; end_date NULL = vẫn đang chạy
```

| sub_id | start_date | end_date |
| --- | --- | --- |
| 1 | 2023-11-20 | NULL |
| 2 | 2023-12-05 | 2024-02-01 |
| 3 | 2024-01-10 | 2024-01-25 |
| 4 | 2024-01-15 | NULL |
| 5 | 2023-12-20 | 2024-03-15 |
| 6 | 2024-02-01 | 2024-04-10 |

Đề hỏi: với mỗi tháng từ 2024-01 đến 2024-04, có bao nhiêu thuê bao đang chạy **vào ngày 1** (`active_start`), và trong số đó bao nhiêu thuê bao **không còn chạy vào ngày 1 tháng sau** (`churned`)?

### "Đang chạy vào ngày d" nghĩa là gì

Một thuê bao đang chạy vào ngày d khi nó đã bắt đầu, và chưa kết thúc:

```sql
start_date <= d AND (end_date IS NULL OR d < end_date)
```

Để ý dấu `<` ở vế sau: thuê bao kết thúc đúng ngày d thì **không còn** chạy vào ngày d. Thuê bao 2 kết thúc 2024-02-01, nên vào ngày 1/2 nó đã dừng.

Áp điều kiện đó vào ngày 1 của mỗi tháng:

| sub_id | start → end | active on |
| --- | --- | --- |
| 1 | 2023-11-20 → NULL | 01-01, 02-01, 03-01, 04-01, 05-01 |
| 2 | 2023-12-05 → 2024-02-01 | 01-01 |
| 3 | 2024-01-10 → 2024-01-25 | (none) |
| 4 | 2024-01-15 → NULL | 02-01, 03-01, 04-01, 05-01 |
| 5 | 2023-12-20 → 2024-03-15 | 01-01, 02-01, 03-01 |
| 6 | 2024-02-01 → 2024-04-10 | 02-01, 03-01, 04-01 |

Bảng này cho ra luôn đáp án. Thuê bao 2 chạy ngày 1/1 nhưng không chạy ngày 1/2, nên nó churn ở tháng 1. Thuê bao 3 bắt đầu và kết thúc trong cùng tháng 1, không chạy vào ngày 1 nào, nên không được đếm ở đâu cả.

### Thử cách tự nhiên nhất

Cách nghĩ nhanh nhất là "thuê bao kết thúc trong tháng nào thì churn ở tháng đó", tức là nhóm theo `DATE_TRUNC('month', end_date)`:

| month | churned (by end month) | should be |
| --- | --- | --- |
| 2024-01 | 1 (sub 3) | 1 (sub 2) |
| 2024-02 | 1 (sub 2) | 0 |
| ... | | |

Sai ở cả hai tháng. Thuê bao 3 chưa từng chạy vào ngày 1 nào, nên không thuộc `active_start` của tháng nào. Đếm nó là churn thì tử số có một người không nằm trong mẫu số. Thuê bao 2 kết thúc ngày 1/2, nhưng thực chất nó đã dừng trước khi tháng 2 bắt đầu. Đó là churn của tháng 1, không phải tháng 2.

### Cách đúng: kiểm tra hai mốc

Với mỗi tháng và mỗi thuê bao, kiểm tra hai câu hỏi: có chạy vào ngày 1 tháng này không, và có chạy vào ngày 1 tháng sau không. `CROSS JOIN` danh sách tháng với danh sách thuê bao để có đủ mọi cặp:

```sql
WITH months AS (
  SELECT generate_series(DATE '2024-01-01', DATE '2024-04-01', INTERVAL '1 month')::date AS month_start
),
checks AS (
  SELECT m.month_start, s.sub_id,
         s.start_date <= m.month_start
           AND (s.end_date IS NULL OR m.month_start < s.end_date) AS active_at_start,
         s.start_date <= (m.month_start + INTERVAL '1 month')::date
           AND (s.end_date IS NULL OR (m.month_start + INTERVAL '1 month')::date < s.end_date) AS active_next
  FROM months m
  CROSS JOIN subscriptions s
)
SELECT TO_CHAR(month_start, 'YYYY-MM') AS month,
       COUNT(*) FILTER (WHERE active_at_start) AS active_start,
       COUNT(*) FILTER (WHERE active_at_start AND NOT active_next) AS churned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE active_at_start AND NOT active_next)
             / NULLIF(COUNT(*) FILTER (WHERE active_at_start), 0), 1) AS churn_rate_pct
FROM checks
GROUP BY month_start
ORDER BY month_start;
```

| month | active_start | churned | churn_rate_pct |
| --- | --- | --- | --- |
| 2024-01 | 3 | 1 | 33.3 |
| 2024-02 | 4 | 0 | 0.0 |
| 2024-03 | 4 | 1 | 25.0 |
| 2024-04 | 3 | 1 | 33.3 |

Danh sách tháng được tạo bằng `generate_series` với mốc đề cho, nên tháng nào cũng có dòng, kể cả khi không có thuê bao nào.

> [!TIP]
> **Ghi nhớ:** với hợp đồng, "đang chạy vào ngày d" là `start_date <= d AND (end_date IS NULL OR d < end_date)`. Churn của tháng = chạy vào ngày 1 tháng này nhưng không chạy vào ngày 1 tháng sau.

## V3. Khi tìm người quay lại sau ít nhất 2 tháng im lặng

Đề hỏi: những ai đã **quay lại sau ít nhất 2 tháng không hoạt động**? Ví dụ Ben hoạt động tháng 1, im lặng tháng 2, 3, 4, rồi quay lại tháng 5: 3 tháng im lặng.

Đề này không cần lưới. Ta không cần dòng cho tháng vắng, chỉ cần biết giữa hai tháng hoạt động liên tiếp có bao nhiêu tháng trống. `LAG` trên `active_months` làm được việc đó.

### Thử cách tự nhiên nhất

Cách nghĩ nhanh là lấy hai ngày hoạt động liên tiếp, trừ ra số ngày, rồi chia 30 để đổi ra tháng:

| user | previous | current | days | ÷ 30 | actual silent months |
| --- | --- | --- | --- | --- | --- |
| Alice | 2024-03-03 | 2024-05-12 | 70 | **2** | 1 (April) |
| Ben | 2024-01-15 | 2024-05-05 | 111 | 3 | 3 |
| Chloe | 2024-02-02 | 2024-04-18 | 76 | **2** | 1 (March) |

Alice và Chloe bị tính là im lặng 2 tháng, trong khi mỗi người chỉ vắng đúng 1 tháng. Đề nói "tháng không hoạt động", tức là tháng theo lịch, không phải khoảng 30 ngày. Hai mốc cách nhau 70 ngày vẫn có thể chỉ có một tháng lịch trống ở giữa.

### Cách sửa: đếm theo tháng lịch

Đổi mỗi tháng hoạt động thành một con số đếm liên tục, `năm × 12 + tháng`, giống cách tính offset ở doc cohort. Hiệu của hai số trừ đi 1 chính là số tháng trống ở giữa. Tháng 3 và tháng 5 có hiệu là 2, trừ 1 còn 1 tháng trống (tháng 4).

```sql
WITH active_months AS (
  SELECT DISTINCT user_id, DATE_TRUNC('month', activity_date)::date AS m
  FROM activity
),
numbered AS (
  SELECT user_id, m,
         EXTRACT(YEAR FROM m)::int * 12 + EXTRACT(MONTH FROM m)::int AS month_no
  FROM active_months
),
gaps AS (
  SELECT user_id, m,
         LAG(m) OVER (PARTITION BY user_id ORDER BY m) AS prev_m,
         month_no - LAG(month_no) OVER (PARTITION BY user_id ORDER BY m) - 1 AS silent_months
  FROM numbered
)
SELECT user_id, TO_CHAR(prev_m, 'YYYY-MM') AS last_active_month,
       TO_CHAR(m, 'YYYY-MM') AS returned_month, silent_months
FROM gaps
WHERE silent_months >= 2
ORDER BY user_id, m;
```

`gaps` cho mỗi tháng hoạt động một dòng, kèm số tháng trống kể từ lần trước:

| user | prev_m | m | silent_months |
| --- | --- | --- | --- |
| Alice | 2024-03 | 2024-05 | 1 |
| Ben | 2024-01 | 2024-05 | **3** |
| Chloe | 2024-02 | 2024-04 | 1 |
| ... | | | 0 or NULL |

Lọc `silent_months >= 2` thì chỉ còn Ben. `WHERE` ở đây đặt ở `SELECT` ngoài cùng vì một lý do: `silent_months` được tính bằng `LAG`, mà hàm cửa sổ không dùng được trong `WHERE` của cùng tầng `SELECT`.

> [!TIP]
> **Ghi nhớ:** "N tháng im lặng" đếm theo tháng lịch. Đổi tháng thành `năm × 12 + tháng`, rồi lấy `số này − LAG(số này) − 1`.

## V4. Khi kỳ báo cáo ngắn hơn lịch sử

Đề muốn bảng growth accounting chỉ cho **tháng 3 đến tháng 5**. Dữ liệu tháng 1 và 2 vẫn còn, nhưng không cần hiện trong báo cáo.

### Thử cách tự nhiên nhất

Cách nghĩ nhanh nhất là lọc dữ liệu ngay từ đầu, thêm `WHERE activity_date >= '2024-03-01'` vào CTE `active_months`, rồi chạy mạch chính như cũ:

| month | new_users | retained | resurrected | churned | should be |
| --- | --- | --- | --- | --- | --- |
| 2024-03 | **3** | 0 | 0 | 0 | new 1, retained 2, churned 1 |
| 2024-04 | **1** | 1 | 0 | 2 | new 0, resurrected 1 |
| 2024-05 | **2** | 1 | 1 | 1 | new 1, resurrected 2 |

Tháng 3 báo có 3 người mới: Alice, David, Frank. Nhưng Alice và Frank đã hoạt động từ tháng 1. Khi xóa tháng 1 và 2 khỏi dữ liệu, tháng 3 trở thành tháng đầu tiên mà query thấy được của hai người này, nên họ bị gắn `new`. Tương tự, Chloe ở tháng 4 và Ben ở tháng 5 thành `new` thay vì `resurrected`. Chloe ở tháng 3 lẽ ra là `churned`, nhưng cũng mất luôn, vì không còn dòng tháng 2 để so.

Gốc của vấn đề: trạng thái của một tháng phụ thuộc vào **lịch sử trước đó**. Xóa lịch sử thì trạng thái sai.

### Cách sửa: tính trên toàn bộ lịch sử, cắt ở bước cuối

Giữ nguyên `active_months`, `grid` và `labeled` trên toàn bộ dữ liệu, để mỗi người có lưới bắt đầu từ tháng đầu tiên thật của họ. Chỉ cắt về kỳ báo cáo ở bước đếm cuối cùng:

```sql
-- active_months, months, firsts, grid, labeled, counts: giữ nguyên như Phần 1
SELECT TO_CHAR(m, 'YYYY-MM') AS month, mau, new_users, retained, resurrected, churned
FROM counts
WHERE m BETWEEN DATE '2024-03-01' AND DATE '2024-05-01'        -- mới: cắt ở bước cuối
ORDER BY m;
```

| month | mau | new_users | retained | resurrected | churned |
| --- | --- | --- | --- | --- | --- |
| 2024-03 | 3 | 1 | 2 | 0 | 1 |
| 2024-04 | 2 | 0 | 1 | 1 | 2 |
| 2024-05 | 4 | 1 | 1 | 2 | 1 |

Khớp với các dòng tương ứng của Phần 1. Nếu cần tính churn rate, phải tính `LAG(mau)` **trước** khi cắt. Nếu cắt trước, tháng 3 không còn tháng 2 đứng trước để lấy mẫu số.

Nếu đề có thêm dữ liệu **sau** kỳ báo cáo thì làm ngược lại: dữ liệu tương lai không ảnh hưởng tới trạng thái quá khứ, nên lọc bỏ ngay trong `active_months` là được.

> [!TIP]
> **Ghi nhớ:** dữ liệu trước kỳ báo cáo là lịch sử quyết định trạng thái, nên giữ nó lại và chỉ cắt ở bước cuối.

## V5. Khi đo bằng tiền: NRR và GRR

Với phần mềm thu phí hằng tháng, đề thường không đếm người mà đo bằng **tiền thu định kỳ mỗi tháng** (MRR). Câu hỏi: những khách đang trả tiền ở tháng 1, đến tháng 5 còn mang lại bao nhiêu tiền so với lúc đầu?

```text
subscription_items (user_id, billing_month, product, mrr)   -- mới
```

| user_id | billing_month | product | mrr |
| --- | --- | --- | --- |
| 1 (Alice) | 2024-01 | Pro | 500 |
| 1 (Alice) | 2024-01 | Addon | 100 |
| 2 (Ben) | 2024-01 | Pro | 400 |
| 3 (Chloe) | 2024-01 | Basic | 300 |
| 4 (David) | 2024-01 | Basic | 200 |
| 1 (Alice) | 2024-05 | Pro | 500 |
| 1 (Alice) | 2024-05 | Addon | 100 |
| 1 (Alice) | 2024-05 | Extra | 150 |
| 2 (Ben) | 2024-05 | Basic | 250 |
| 4 (David) | 2024-05 | Basic | 200 |
| 5 (Emma) | 2024-05 | Enterprise | 900 |

Mỗi khách đang trả tiền ở tháng 1 (tiền `b`) được so với tháng 5 (tiền `t`), và rơi vào một loại:
- `t > b`: **expansion**, khách chi thêm `t − b`.
- `0 < t < b`: **contraction**, khách chi bớt `b − t`.
- `t = 0`: **churned**, mất cả `b`.

Từ đó tính hai chỉ số:
- **NRR** (net revenue retention) = tổng `t` ÷ tổng `b`. Có tính phần chi thêm, nên có thể vượt 100%.
- **GRR** (gross revenue retention) = (tổng `b` − contraction − churned) ÷ tổng `b`. Chỉ tính phần mất, không cộng phần chi thêm, nên tối đa là 100%.

Emma chỉ bắt đầu từ tháng 5, nên không tính. Câu hỏi là khách **cũ** giữ được bao nhiêu tiền.

### Thử cách tự nhiên nhất

Mỗi khách có thể có nhiều dòng sản phẩm. Cách nghĩ nhanh là so từng dòng sản phẩm của tháng 1 với cùng sản phẩm đó ở tháng 5:

| user | product | b | t | treated as |
| --- | --- | --- | --- | --- |
| Alice | Pro | 500 | 500 | unchanged |
| Alice | Addon | 100 | 100 | unchanged |
| Ben | Pro | 400 | **0** | **churned 400** |
| ... | | | | |

Ben chỉ đổi từ gói Pro (400) sang gói Basic (250). Khách vẫn ở lại, chỉ chi bớt 150. Nhưng so theo sản phẩm thì gói Pro của Ben biến mất, nên bị tính là mất trọn 400. Gói Basic mới của Ben thì không có ở tháng 1, nên không được tính. Gói Extra của Alice cũng vậy, mất luôn phần chi thêm 150.

### Cách sửa: gộp tiền theo khách trước, rồi so từ tháng gốc

Gộp tất cả dòng sản phẩm thành **tiền mỗi khách mỗi tháng** trước, rồi mới so. Ben giờ là 400 → 250, đúng là contraction 150.

Khi so, đi **từ tháng gốc** bằng `LEFT JOIN` sang tháng đích, điều kiện tháng đích đặt trong `ON`. Như vậy Chloe, người không còn ở tháng 5, vẫn có một dòng với `t` là `NULL`, và `COALESCE(t, 0)` biến nó thành 0, tức churned. Nếu đi bằng `JOIN` thường, Chloe biến mất và khoản mất 300 cũng biến mất theo.

```sql
WITH mrr AS (                                         -- tiền mỗi khách mỗi tháng
  SELECT user_id, billing_month, SUM(mrr) AS mrr
  FROM subscription_items
  GROUP BY user_id, billing_month
),
compared AS (                                         -- mỗi khách của tháng gốc: b và t
  SELECT b.user_id, b.mrr AS b, COALESCE(t.mrr, 0) AS t
  FROM mrr b
  LEFT JOIN mrr t
         ON t.user_id = b.user_id
        AND t.billing_month = DATE '2024-05-01'
  WHERE b.billing_month = DATE '2024-01-01'
)
SELECT SUM(b) AS starting_mrr,
       SUM(t - b) FILTER (WHERE t > b)           AS expansion_mrr,
       SUM(b - t) FILTER (WHERE t > 0 AND t < b) AS contraction_mrr,
       SUM(b)     FILTER (WHERE t = 0)           AS churned_mrr,
       SUM(t) AS ending_mrr,
       ROUND(100.0 * SUM(t) / NULLIF(SUM(b), 0), 1) AS nrr_pct,
       ROUND(100.0 * (SUM(b) - COALESCE(SUM(b - t) FILTER (WHERE t > 0 AND t < b), 0)
                     - COALESCE(SUM(b) FILTER (WHERE t = 0), 0)) / NULLIF(SUM(b), 0), 1) AS grr_pct
FROM compared;
```

`compared`, mỗi khách của tháng gốc một dòng:

| user | b | t | kind |
| --- | --- | --- | --- |
| Alice | 600 | 750 | expansion 150 |
| Ben | 400 | 250 | contraction 150 |
| Chloe | 300 | 0 | churned 300 |
| David | 200 | 200 | unchanged |

| starting_mrr | expansion_mrr | contraction_mrr | churned_mrr | ending_mrr | nrr_pct | grr_pct |
| --- | --- | --- | --- | --- | --- | --- |
| 1500 | 150 | 150 | 300 | 1200 | 80.0 | 70.0 |

NRR = 1200 / 1500 = 80%. GRR = (1500 − 150 − 300) / 1500 = 70%. Nếu không có khách nào ở một loại, `SUM(...) FILTER` ra `NULL` chứ không ra 0. Đề muốn 0 thì bọc `COALESCE(..., 0)`.

> [!TIP]
> **Ghi nhớ:** gộp tiền về (khách, tháng) trước khi so, và luôn đi `LEFT JOIN` từ tháng gốc, để khách đã rời đi vẫn có một dòng với tiền 0.
