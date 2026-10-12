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
SELECT t.name AS team,
       COUNT(DISTINCT g.goal_id) AS goals,
       COUNT(DISTINCT c.card_id) AS cards
FROM teams t
LEFT JOIN goals g ON g.team_id = t.team_id
LEFT JOIN cards c ON c.team_id = t.team_id
GROUP BY t.team_id, t.name
ORDER BY t.name;
