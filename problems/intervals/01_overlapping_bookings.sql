-- Problem intervals/01: Double-booked hotel rooms  [Easy]
-- Pattern: Intervals: self-join with the overlap test a.start < b.end AND b.start < a.end, a.id < b.id
-- Variant: half-open stays [check_in, check_out): the check-out day is free for the next guest
--
-- Task: A homestay in Da Lat finds bookings of the same room that overlap. A stay occupies the
--   nights from check_in up to the day before check_out, so a booking that starts on another's
--   check_out day does NOT overlap it. For every overlapping pair in the same room return room,
--   booking_a (smaller id), booking_b (larger id), overlap_start, overlap_end (the later
--   check_in and the earlier check_out) and overlap_nights. Sort by room, booking_a, booking_b.
-- Learn: grinding/sql-analytics-patterns.md, mục 12.2

-- INPUT
bookings
| booking_id | room | guest   | check_in   | check_out  |
|------------|------|---------|------------|------------|
| 1          | 101  | Lana    | 2024-06-01 | 2024-06-05 |
| 2          | 101  | Mike    | 2024-06-05 | 2024-06-08 |
| 3          | 101  | Helen   | 2024-06-04 | 2024-06-06 |
| 4          | 102  | Tom     | 2024-06-01 | 2024-06-10 |
| 5          | 102  | Quentin | 2024-06-03 | 2024-06-04 |
| 6          | 102  | Nina    | 2024-06-09 | 2024-06-12 |
| 7          | 201  | Brian   | 2024-06-01 | 2024-06-03 |
| 8          | 202  | Amy     | 2024-06-01 | 2024-06-03 |

-- EXPECTED
| room | booking_a | booking_b | overlap_start | overlap_end | overlap_nights |
|------|-----------|-----------|---------------|-------------|----------------|
| 101  | 1         | 3         | 2024-06-04    | 2024-06-05  | 1              |
| 101  | 2         | 3         | 2024-06-05    | 2024-06-06  | 1              |
| 102  | 4         | 5         | 2024-06-03    | 2024-06-04  | 1              |
| 102  | 4         | 6         | 2024-06-09    | 2024-06-10  | 1              |

-- QUERY
-- write your query here
