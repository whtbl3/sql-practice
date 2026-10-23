# How to use

## Xem danh sách đề

```bash
q                  # liệt kê mọi nhóm kèm mức độ và dạng đề
q topn             # liệt kê một nhóm (gõ tắt được: q to, q is, q dm)
q func             # bài Function / Procedure / Trigger (tài liệu: grinding/sql-function.md, sql-procedure.md, sql-trigger.md)
```

## Làm bài SQL

```bash
q topn 3           # theo dõi file đề, in output mỗi khi lưu (không so sánh)
q topn 3 c         # chạy một lần, so với EXPECTED (test hiện)
q topn 3 h         # submit: test hiện + test ẩn (chỉ tên case và pass/fail)
q topn 3 hv        # như h; nếu pass hết thì in chi tiết mọi case ẩn
q topn 3 s         # xem đáp án mẫu và kết quả của nó
```

## Làm bài bằng pandas

```bash
q topn 3 py                  # cùng đề, giải bằng pandas (lần đầu tự tạo problems/topn/03_*.py), theo dõi khi lưu
q topn 3 py c | h | hv | s   # như bản SQL; test ẩn dùng chung với bản SQL
```

## Khác

```bash
q verify           # kiểm tra toàn bộ đáp án mẫu qua mọi test
q quiz             # mở quiz trắc nghiệm phỏng vấn SQL trên trình duyệt (http://localhost:8501)
q quiz stop        # tắt quiz server
```

## Xem query plan (EXPLAIN / EXPLAIN ANALYZE)

Không có Postgres chạy sẵn: `check.py` bật một Postgres tạm (pgserver), tạo bảng từ `-- INPUT` rồi chạy nguyên khối `-- QUERY`. Muốn xem plan thì thêm `EXPLAIN` vào đầu query và chạy ở chế độ theo dõi:

```sql
-- QUERY
ANALYZE transactions;    -- (tuỳ chọn) cập nhật thống kê để ước lượng rows sát hơn
EXPLAIN ANALYZE
SELECT ...;
```

```bash
q agg 1                                  # chế độ theo dõi, in bảng QUERY PLAN mỗi khi lưu
uv run check.py problems/agg/01_*.sql -r # hoặc chạy một lần
```

Không dùng `c` / `h` khi đang có `EXPLAIN` (output không khớp EXPECTED). Xoá `EXPLAIN` trước khi submit.

| Lệnh | Chạy query thật? | In ra |
|---|---|---|
| `EXPLAIN` | Không | plan + ước lượng (`cost`, `rows`) |
| `EXPLAIN ANALYZE` | **Có** | thêm `actual time`, `rows` thực tế, `loops`, Planning/Execution Time |
| `EXPLAIN (ANALYZE, BUFFERS)` | Có | thêm số page đọc từ cache / disk |
| `EXPLAIN (FORMAT JSON)` | Không | JSON, dán vào explain.dalibo.com để xem trực quan |

Đọc một dòng plan:

```
Seq Scan on transactions  (cost=0.00..26.95 rows=1130 width=72) (actual time=0.063..0.066 rows=6 loops=1)
```

- `cost=a..b`: chi phí ước lượng (đơn vị tương đối, không phải ms); `a` = đến dòng đầu, `b` = tổng.
- `rows=1130` (ngoặc đầu) là số dòng planner **đoán**; `rows=6` (ngoặc sau) là **thực tế**. Lệch nhiều → thiếu thống kê, chạy `ANALYZE <bảng>`.
- `actual time=x..y`: ms thật cho dòng đầu..dòng cuối, **tính cho mỗi loop**; thời gian thật của node ≈ `y × loops`.
- Đọc plan từ trong ra ngoài, dưới lên trên: node thụt sâu nhất chạy trước.

Lưu ý:

- Data mẫu chỉ vài dòng nên planner gần như luôn chọn Seq Scan kể cả khi có index. Muốn thấy Index Scan thì sinh thêm data ngay trong QUERY (`INSERT ... SELECT ... FROM generate_series(1, 100000)`) hoặc tạm `SET enable_seqscan = off;`.
- `EXPLAIN ANALYZE` chạy thật, nên với `UPDATE` / `DELETE` sẽ sửa dữ liệu. Ở đây không sao vì mỗi lần chạy schema được tạo lại; trên DB thật thì bọc trong `BEGIN; ... ROLLBACK;`.
