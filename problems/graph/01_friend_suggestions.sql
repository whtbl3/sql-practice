-- Problem graph/01: "People you may know" (friends of friends)  [Easy]
-- Pattern: Graph: undirected edges -> both directions with UNION -> 2-hop self-join -> exclude self and direct friends
-- Variant: a fixed 2 steps needs no recursion; count mutual friends with COUNT(DISTINCT)
--
-- Task: A Vietnamese social app stores each friendship once in friendships (either direction; the
--   same pair may be stored twice by mistake). Suggest friends for user 1: every user at distance
--   exactly 2 (a friend of one of user 1's friends, not user 1, not already a friend). Return
--   user_id, name and mutual_friends (how many of user 1's friends they are friends with).
--   Sort by mutual_friends DESC, user_id.
-- Learn: grinding/sql-recursive-cte.md, V6

-- INPUT
users
| user_id | name |
|---------|------|
| 1       | Mark |
| 2       | Lucy |
| 3       | Hope |
| 4       | Tony |
| 5       | Vera |
| 6       | Ken  |
| 7       | Nora |

friendships
| user_a | user_b |
|--------|--------|
| 1      | 2      |
| 3      | 1      |
| 1      | 4      |
| 2      | 5      |
| 3      | 5      |
| 4      | 5      |
| 2      | 3      |
| 4      | 6      |
| 6      | 7      |

-- EXPECTED
| user_id | name | mutual_friends |
|---------|------|----------------|
| 5       | Vera | 3              |
| 6       | Ken  | 1              |

-- QUERY
-- write your query here
