-- Problem funnel/02: Most common 3-page path  [Hard]
-- Pattern: LEAD for n-grams over ordered events
-- Variant: path analysis
--
-- Task: For each user, take every run of 3 consecutive page views (ordered by seq). Return the most
--   common path as 'a > b > c' with its count. Tie: smallest path alphabetically. Users with fewer
--   than 3 views contribute nothing.

-- INPUT
page_views
| user_id | seq | page    |
|---------|-----|---------|
| 1       | 1   | home    |
| 1       | 2   | search  |
| 1       | 3   | product |
| 1       | 4   | cart    |
| 2       | 1   | home    |
| 2       | 2   | search  |
| 2       | 3   | product |
| 2       | 4   | home    |
| 3       | 1   | home    |
| 3       | 2   | search  |
| 3       | 3   | cart    |

-- EXPECTED
| path                    | occurrences |
|-------------------------|-------------|
| home > search > product | 2           |

-- QUERY
WITH t AS (
    SELECT page || ' > ' || LEAD(page, 1) OVER w || ' > ' || LEAD(page, 2) OVER w AS path
    FROM page_views
    WINDOW w AS (PARTITION BY user_id ORDER BY seq)
)
SELECT path, COUNT(*) AS occurrences
FROM t
WHERE path IS NOT NULL
GROUP BY path
ORDER BY occurrences DESC, path
LIMIT 1;
