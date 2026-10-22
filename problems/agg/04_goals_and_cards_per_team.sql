-- Problem agg/04: Goals and cards per team  [Medium]
-- Pattern: Aggregating across two one-to-many joins (fan-out trap)
-- Variant: join fan-out
--
-- Task: Return each team with its number of goals and number of cards (0 if none). Beware: joining
--   both child tables at once multiplies the rows. Sort by team.

-- INPUT
teams
| team_id | name   |
|---------|--------|
| 1       | Lions  |
| 2       | Tigers |
| 3       | Bears  |

goals
| goal_id | team_id |
|---------|---------|
| 1       | 1       |
| 2       | 1       |
| 3       | 1       |
| 4       | 2       |

cards
| card_id | team_id |
|---------|---------|
| 1       | 1       |
| 2       | 1       |
| 3       | 3       |

-- EXPECTED
| team   | goals | cards |
|--------|-------|-------|
| Bears  | 0     | 1     |
| Lions  | 3     | 2     |
| Tigers | 1     | 0     |

-- QUERY
-- write your query here
WITH card_stat AS (
  SELECT team_id, COUNT(*) AS cards
  FROM cards
  GROUP BY team_id
),
goal_stat AS (
  SELECT team_id, COUNT(*) AS goals
  FROM goals
  GROUP BY team_id
)
SELECT t.name AS team, COALESCE(gs.goals, 0) AS goals, COALESCE(cs.cards, 0) AS cards
FROM teams t 
  LEFT JOIN card_stat cs ON t.team_id = cs.team_id
  LEFT JOIN goal_stat gs ON t.team_id = gs.team_id      
ORDER BY t.name     