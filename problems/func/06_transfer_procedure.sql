-- Problem func/06: Money transfer procedure  [Medium]
-- Pattern: PROCEDURE + validation with RAISE EXCEPTION, CALL
-- Variant: every rule is checked before any balance changes
--
-- Task: Create a procedure transfer(p_from INT, p_to INT, p_amount NUMERIC) that moves p_amount from
--   account p_from to account p_to. Raise an error (message contains the text in quotes) when:
--   p_amount <= 0 or NULL -> 'amount must be positive'; p_from = p_to -> 'same account';
--   either account does not exist -> 'account not found';
--   the balance of p_from is less than p_amount -> 'insufficient funds'.
--   Check the accounts table after the CALLs.
-- Learn: grinding/sql-procedure.md, B1–B5

-- INPUT
accounts
| account_id:int | owner:text | balance:numeric |
|----------------|------------|-----------------|
| 1              | An         | 100.00          |
| 2              | Binh       | 50.00           |
| 3              | Chi        | 0.00            |

-- EXPECTED
accounts
| account_id | owner | balance |
|------------|-------|---------|
| 1          | An    | 70.00   |
| 2          | Binh  | 0.00    |
| 3          | Chi   | 80.00   |

-- CALL
CALL transfer(1, 2, 30.00);
CALL transfer(2, 3, 80.00);

-- QUERY
-- write your query here
