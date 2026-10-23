-- Problem graph/02: Fewest stops from Ben Thanh (BFS)  [Medium]
-- Pattern: Graph: recursive CTE walking edges + path array to stop cycles + MIN(hops) per node
-- Variant: undirected network with a cycle and a part that cannot be reached
--
-- Task: A city bus network stores each direct link between two stops once in links (buses run
--   both ways). Starting from 'Ben Thanh', return every stop that can be reached with the fewest
--   number of links needed (hops; Ben Thanh itself has 0). Stops that cannot be reached are not
--   returned. Sort by hops, stop.
-- Learn: grinding/sql-recursive-cte.md, B3–B4

-- INPUT
links
| stop_a     | stop_b     |
|------------|------------|
| Ben Thanh  | Cho Lon    |
| Saigon Zoo | Ben Thanh  |
| Cho Lon    | Dam Sen    |
| Dam Sen    | Saigon Zoo |
| Dam Sen    | Binh Tan   |
| Binh Tan   | Suoi Tien  |
| Can Gio    | Vung Tau   |

-- EXPECTED
| stop       | hops |
|------------|------|
| Ben Thanh  | 0    |
| Cho Lon    | 1    |
| Saigon Zoo | 1    |
| Dam Sen    | 2    |
| Binh Tan   | 3    |
| Suoi Tien  | 4    |

-- QUERY
WITH RECURSIVE edges AS (
  SELECT stop_a AS u, stop_b AS v FROM links
  UNION
  SELECT stop_b, stop_a FROM links
),
walk(stop, hops, path) AS (
  SELECT 'Ben Thanh'::text, 0, ARRAY['Ben Thanh'::text]
  UNION ALL
  SELECT e.v, w.hops + 1, w.path || e.v
  FROM walk w
  JOIN edges e ON e.u = w.stop
  WHERE e.v <> ALL (w.path)                         -- never revisit a stop on this path: no infinite loop
)
SELECT stop, MIN(hops) AS hops                      -- the shortest of all simple paths
FROM walk
GROUP BY stop
ORDER BY hops, stop;
