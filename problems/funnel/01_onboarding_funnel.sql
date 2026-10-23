-- Problem funnel/01: Strict 4-step onboarding funnel  [Hard]
-- Pattern: Per-user flags (BOOL_OR) then conditional counts
-- Variant: funnel conversion
--
-- Task: Steps are signup, verify, profile, purchase (events may repeat; ignore time). A user counts
--   for a step only if they also did every earlier step. Return one row: the number of users
--   reaching each step, and purchase_rate = purchase * 100 / signup rounded to 1 decimal (NULL if
--   nobody signed up).
-- Learn: grinding/sql-funnel.md, B1–B3

-- INPUT
events
| user_id | step     |
|---------|----------|
| 1       | signup   |
| 1       | verify   |
| 1       | profile  |
| 1       | purchase |
| 2       | signup   |
| 2       | verify   |
| 3       | signup   |
| 3       | profile  |
| 4       | signup   |
| 4       | verify   |
| 4       | profile  |
| 5       | verify   |

-- EXPECTED
| signup | verify | profile | purchase | purchase_rate |
|--------|--------|---------|----------|---------------|
| 4      | 3      | 2       | 1        | 25.0          |

-- QUERY
-- write your query here
