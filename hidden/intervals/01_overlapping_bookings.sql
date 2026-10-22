-- HIDDEN TESTS for problem intervals/01. No QUERY section: the problem's QUERY is used.

-- CASE back-to-back stays only
-- INPUT
bookings
| booking_id | room | guest | check_in   | check_out  |
|------------|------|-------|------------|------------|
| 1          | 101  | A     | 2024-06-01 | 2024-06-03 |
| 2          | 101  | B     | 2024-06-03 | 2024-06-05 |

-- EXPECTED
| room:int | booking_a:int | booking_b:int | overlap_start:date | overlap_end:date | overlap_nights:int |
|----------|---------------|---------------|--------------------|------------------|--------------------|

-- CASE identical stays and one stay covering two others
-- INPUT
bookings
| booking_id | room | guest | check_in   | check_out  |
|------------|------|-------|------------|------------|
| 5          | 7    | A     | 2024-07-01 | 2024-07-04 |
| 3          | 7    | B     | 2024-07-01 | 2024-07-04 |
| 9          | 7    | C     | 2024-06-25 | 2024-07-10 |

-- EXPECTED
| room | booking_a | booking_b | overlap_start | overlap_end | overlap_nights |
|------|-----------|-----------|---------------|-------------|----------------|
| 7    | 3         | 5         | 2024-07-01    | 2024-07-04  | 3              |
| 7    | 3         | 9         | 2024-07-01    | 2024-07-04  | 3              |
| 7    | 5         | 9         | 2024-07-01    | 2024-07-04  | 3              |
