-- Problem window/01: ROW_NUMBER vs RANK vs DENSE_RANK  [Easy]
-- Pattern: Ranking functions side by side
-- Variant: ties and NULL ordering
--
-- Task: Rank players by score, highest first. Return player, score, row_num (ROW_NUMBER, ties broken
--   by player), rnk (RANK) and dense_rnk (DENSE_RANK). NULL scores rank last. Sort by score DESC
--   (NULLs last), then player.
-- Learn: grinding/sql-window.md, B4

-- INPUT
scores
| player | score |
|--------|-------|
| Ann    | 90    |
| Bob    | 85    |
| Cy     | 90    |
| Dee    | 70    |
| Eli    | 85    |
| Fay    | 60    |

-- EXPECTED
| player | score | row_num | rnk | dense_rnk |
|--------|-------|---------|-----|-----------|
| Ann    | 90    | 1       | 1   | 1         |
| Cy     | 90    | 2       | 1   | 1         |
| Bob    | 85    | 3       | 3   | 2         |
| Eli    | 85    | 4       | 3   | 2         |
| Dee    | 70    | 5       | 5   | 3         |
| Fay    | 60    | 6       | 6   | 4         |

-- QUERY
SELECT player, score,
       ROW_NUMBER() OVER (ORDER BY score DESC NULLS LAST, player) AS row_num,
       RANK()       OVER (ORDER BY score DESC NULLS LAST)         AS rnk,
       DENSE_RANK() OVER (ORDER BY score DESC NULLS LAST)         AS dense_rnk
FROM scores
ORDER BY score DESC NULLS LAST, player;

-- ===== Giải thích =====
-- Ý tưởng: ba hàm chỉ khác nhau khi có dòng HÒA (cùng giá trị ORDER BY).
--   ROW_NUMBER: luôn 1,2,3,... không bao giờ trùng (hòa thì thứ tự tùy ý, nên thêm cột phá hòa).
--   RANK:       hòa thì cùng hạng, hạng kế tiếp NHẢY CÓC (1,1,3).
--   DENSE_RANK: hòa thì cùng hạng, hạng kế tiếp KHÔNG nhảy (1,1,2).
-- Khi nào dùng: "lấy đúng 1 dòng mỗi nhóm" dùng ROW_NUMBER, "top N kể cả hòa" dùng RANK,
--   "giá trị lớn thứ N" dùng DENSE_RANK.
-- Lỗi hay gặp: PostgreSQL coi NULL là LỚN NHẤT, nên ORDER BY ... DESC đưa NULL lên ĐẦU.
--   Muốn NULL xuống cuối phải viết NULLS LAST, cả trong OVER(...) lẫn ORDER BY cuối câu.
