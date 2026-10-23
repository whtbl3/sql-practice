-- Problem dp/01: Rain water trapped between terraces  [Medium]
-- Pattern: DP with windows: water(i) = LEAST(max height to the left, max height to the right) - height(i)
-- Variant: the classic "trapping rain water" without recursion: two running MAX windows
--
-- Task: A cross-section of rice terraces is given as one height per position (unit width).
--   After heavy rain, the water above position i rises to the lower of the highest point on its
--   left (including itself) and the highest point on its right (including itself). For every
--   position return pos, height, left_max, right_max and water = that level - height.
--   Sort by pos.
-- Learn: grinding/sql-dp.md, B2

-- INPUT
terrain
| pos | height |
|-----|--------|
| 1   | 0      |
| 2   | 1      |
| 3   | 0      |
| 4   | 2      |
| 5   | 1      |
| 6   | 0      |
| 7   | 1      |
| 8   | 3      |
| 9   | 2      |
| 10  | 1      |
| 11  | 2      |
| 12  | 1      |

-- EXPECTED
| pos | height | left_max | right_max | water |
|-----|--------|----------|-----------|-------|
| 1   | 0      | 0        | 3         | 0     |
| 2   | 1      | 1        | 3         | 0     |
| 3   | 0      | 1        | 3         | 1     |
| 4   | 2      | 2        | 3         | 0     |
| 5   | 1      | 2        | 3         | 1     |
| 6   | 0      | 2        | 3         | 2     |
| 7   | 1      | 2        | 3         | 1     |
| 8   | 3      | 3        | 3         | 0     |
| 9   | 2      | 3        | 2         | 0     |
| 10  | 1      | 3        | 2         | 1     |
| 11  | 2      | 3        | 2         | 0     |
| 12  | 1      | 3        | 1         | 0     |

-- QUERY
WITH walls AS (
  SELECT pos, height,
         MAX(height) OVER (ORDER BY pos ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS left_max,
         MAX(height) OVER (ORDER BY pos ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS right_max
  FROM terrain
)
SELECT pos, height, left_max, right_max,
       LEAST(left_max, right_max) - height AS water     -- never negative: both maxima include the position
FROM walls
ORDER BY pos;
