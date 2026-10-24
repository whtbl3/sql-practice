-- Problem topn/02: Latest email per customer  [Medium]
-- Pattern: Latest row per group (ROW_NUMBER)
-- Variant: one row per group instead of the nth
--
-- Task: The table keeps the history of email changes. For each customer return the email from the
--   LATEST update. Return customer_id, email; sort by customer_id.
-- Learn: grinding/sql-top-n.md, V2

-- INPUT
customer_updates
| update_id | customer_id | email     | updated_at |
|-----------|-------------|-----------|------------|
| 1         | 1           | a@old.com | 2024-01-01 |
| 2         | 1           | a@new.com | 2024-03-01 |
| 3         | 2           | b@x.com   | 2024-02-01 |
| 4         | 3           | c@old.com | 2024-01-05 |
| 5         | 3           | c@new.com | 2024-01-06 |

-- EXPECTED
| customer_id | email     |
|-------------|-----------|
| 1           | a@new.com |
| 2           | b@x.com   |
| 3           | c@new.com |

-- QUERY
SELECT customer_id, email
FROM (
  SELECT customer_id, email,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) AS rn
  FROM customer_updates
) t
WHERE rn = 1
ORDER BY customer_id;
