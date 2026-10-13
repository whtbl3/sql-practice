-- Problem window/01: ROW_NUMBER vs RANK vs DENSE_RANK  [Easy]
-- Pattern: Ranking functions side by side
-- Variant: ties and NULL ordering
--
-- Task: Rank players by score, highest first. Return player, score, row_num (ROW_NUMBER, ties broken
--   by player), rnk (RANK) and dense_rnk (DENSE_RANK). NULL scores rank last. Sort by score DESC
--   (NULLs last), then player.
-- Learn: grinding/sql-subquery-window.md, mục W1

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
-- write your query here
