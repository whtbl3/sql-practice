-- Problem dml/05: Create missing accounts  [Medium]
-- Pattern: INSERT ... SELECT with NOT EXISTS
-- Variant: INSERT only: existing rows must not be touched
--
-- Task: Every customer must have a row in accounts. Insert a row with balance 0 for each customer
--   that has no account yet. Do not change existing accounts. Check the accounts table
--   afterwards.

-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Alice     |
| 2               | Bob       |
| 3               | Carol     |

accounts
| customer_id:int | balance:int |
|-----------------|-------------|
| 1               | 250         |

-- EXPECTED
accounts
| customer_id | balance |
|-------------|---------|
| 1           | 250     |
| 2           | 0       |
| 3           | 0       |

-- QUERY
-- write your query here
