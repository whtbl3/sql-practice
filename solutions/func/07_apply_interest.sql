-- Problem func/07: Apply interest and write a log (loop in a procedure)  [Hard]
-- Pattern: PROCEDURE with FOR rec IN SELECT ... LOOP, UPDATE + INSERT per row
-- Variant: skip rows whose rounded interest is 0; can also be written set-based (CTE + RETURNING)
--
-- Task: Create a procedure apply_interest(p_rate NUMERIC). For every account of type 'savings':
--   interest = ROUND(balance * p_rate, 2). If the interest is greater than 0, add it to the balance
--   and insert (account_id, interest) into interest_log. A NULL or negative p_rate must raise an
--   error containing 'rate must be non-negative'. The CALL then shows balances with their log rows.
-- Learn: grinding/sql-procedure.md, V2

-- INPUT
accounts
| account_id:int | type:text | balance:numeric |
|----------------|-----------|-----------------|
| 1              | savings   | 1000.00         |
| 2              | checking  | 500.00          |
| 3              | savings   | 0.00            |
| 4              | savings   | 0.40            |
| 5              | savings   | 250.50          |

interest_log
| account_id:int | interest:numeric |
|----------------|------------------|

-- EXPECTED
| account_id | balance | interest |
|------------|---------|----------|
| 1          | 1010.00 | 10.00    |
| 2          | 500.00  | NULL     |
| 3          | 0.00    | NULL     |
| 4          | 0.40    | NULL     |
| 5          | 253.01  | 2.51     |

-- CALL
CALL apply_interest(0.01);
SELECT a.account_id, a.balance, l.interest
FROM accounts a LEFT JOIN interest_log l ON l.account_id = a.account_id
ORDER BY a.account_id;

-- QUERY
CREATE PROCEDURE apply_interest(p_rate NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
  rec RECORD;
  v_interest NUMERIC;
BEGIN
  IF p_rate IS NULL OR p_rate < 0 THEN
    RAISE EXCEPTION 'rate must be non-negative';
  END IF;

  FOR rec IN SELECT account_id, balance FROM accounts WHERE type = 'savings' LOOP
    v_interest := ROUND(rec.balance * p_rate, 2);
    CONTINUE WHEN v_interest <= 0;
    UPDATE accounts SET balance = balance + v_interest WHERE account_id = rec.account_id;
    INSERT INTO interest_log (account_id, interest) VALUES (rec.account_id, v_interest);
  END LOOP;
END;
$$;
