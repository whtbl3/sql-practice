-- Problem dml/02: Remove duplicate contacts  [Medium]
-- Pattern: Delete duplicates (DELETE + MIN(id) / ROW_NUMBER)
-- Variant: DELETE instead of UPDATE
--
-- Task: The contacts table has duplicate emails. Delete the duplicates, keeping only the row with
--   the smallest id for each email. Check the contacts table afterwards.

-- INPUT
contacts
| id | email   |
|----|---------|
| 1  | a@x.com |
| 2  | b@x.com |
| 3  | a@x.com |
| 4  | a@x.com |
| 5  | c@x.com |
| 6  | b@x.com |

-- EXPECTED
contacts
| id | email   |
|----|---------|
| 1  | a@x.com |
| 2  | b@x.com |
| 5  | c@x.com |

-- QUERY
-- write your query here
