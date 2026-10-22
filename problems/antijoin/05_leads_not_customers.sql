-- Problem antijoin/05: Newsletter leads that are not customers yet (NOT EXISTS vs EXCEPT)  [Medium]
-- Pattern: Anti-join that keeps whole rows, duplicates and NULL keys: NOT EXISTS, not EXCEPT
-- Variant: EXCEPT compares only the selected columns, removes duplicates and treats NULL = NULL
--
-- Task: A skincare shop wants to call people who signed up for its newsletter but never became
--   customers. A lead is converted when some customer has the same phone. A lead with a NULL
--   phone cannot be matched, so it is NOT converted. Every signup is a separate lead (the same
--   person may sign up twice). Return lead_id, full_name, phone of every lead that is not
--   converted. Sort by lead_id.
-- Learn: grinding/sql-common-pitfalls.md, mục G6

-- INPUT
leads
| lead_id | full_name | phone:text |
|---------|-----------|------------|
| 1       | Annie     | 0901000001 |
| 2       | Ben       | 0902000002 |
| 3       | Chloe     | NULL       |
| 4       | Annie     | 0901000001 |
| 5       | Dave      | 0905000005 |

customers
| customer_id | full_name | phone:text |
|-------------|-----------|------------|
| 1           | Ben       | 0902000002 |
| 2           | Emma      | NULL       |
| 3           | Grace     | 0907000007 |

-- EXPECTED
| lead_id | full_name | phone      |
|---------|-----------|------------|
| 1       | Annie     | 0901000001 |
| 3       | Chloe     | NULL       |
| 4       | Annie     | 0901000001 |
| 5       | Dave      | 0905000005 |

-- QUERY
-- write your query here
