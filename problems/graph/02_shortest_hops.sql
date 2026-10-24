-- Problem graph/02: Fewest stops from Ben Thanh (BFS)  [Medium]
-- Pattern: Graph: recursive CTE walking edges + path array to stop cycles + MIN(hops) per node
-- Variant: undirected network with a cycle and a part that cannot be reached
--
-- Task: A city bus network stores each direct link between two stops once in links (buses run
--   both ways). Starting from 'Ben Thanh', return every stop that can be reached with the fewest
--   number of links needed (hops; Ben Thanh itself has 0). Stops that cannot be reached are not
--   returned. Sort by hops, stop.
-- Learn: grinding/sql-recursive-cte.md, B1–B4

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
-- write your query here
