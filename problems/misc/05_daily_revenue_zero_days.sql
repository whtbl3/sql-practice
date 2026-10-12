-- Problem misc/05: Daily revenue including empty days  [Medium]
-- Pattern: Calendar generation (generate_series) + LEFT JOIN
-- Variant: gap filling
--
-- Task: Return one row per calendar day from the first to the last sale_date with the day's total
--   revenue, 0 on days without sales. Sort by sale_date.

-- INPUT
sales
| sale_date  | amount |
|------------|--------|
| 2024-01-01 | 100    |
| 2024-01-01 | 50     |
| 2024-01-03 | 70     |
| 2024-01-06 | 20     |

-- EXPECTED
| sale_date  | revenue |
|------------|---------|
| 2024-01-01 | 150     |
| 2024-01-02 | 0       |
| 2024-01-03 | 70      |
| 2024-01-04 | 0       |
| 2024-01-05 | 0       |
| 2024-01-06 | 20      |

-- QUERY
-- write your query here
