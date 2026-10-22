-- HIDDEN TESTS for problem graph/01. No QUERY section: the problem's QUERY is used.

-- CASE user 1 has no friends
-- INPUT
users
| user_id | name |
|---------|------|
| 1       | A    |
| 2       | B    |
| 3       | C    |

friendships
| user_a | user_b |
|--------|--------|
| 2      | 3      |

-- EXPECTED
| user_id:int | name:text | mutual_friends:int |
|-------------|-----------|--------------------|

-- CASE the same friendship stored in both directions must not double the mutual count
-- INPUT
users
| user_id | name |
|---------|------|
| 1       | A    |
| 2       | B    |
| 3       | C    |
| 4       | D    |

friendships
| user_a | user_b |
|--------|--------|
| 1      | 2      |
| 2      | 1      |
| 2      | 4      |
| 4      | 2      |
| 1      | 3      |
| 3      | 4      |

-- EXPECTED
| user_id | name | mutual_friends |
|---------|------|----------------|
| 4       | D    | 2              |
