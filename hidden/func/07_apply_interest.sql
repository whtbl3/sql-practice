-- HIDDEN TESTS for problem func/07. No QUERY section: the problem's QUERY is used.

-- CASE rate 0 changes nothing
-- INPUT
accounts
| account_id:int | type:text | balance:numeric |
|----------------|-----------|-----------------|
| 1              | savings   | 100.00          |

interest_log
| account_id:int | interest:numeric |
|----------------|------------------|

-- EXPECTED
| account_id | balance | interest:numeric |
|------------|---------|------------------|
| 1          | 100.00  | NULL             |

-- CALL
CALL apply_interest(0);
SELECT a.account_id, a.balance, l.interest
FROM accounts a LEFT JOIN interest_log l ON l.account_id = a.account_id
ORDER BY a.account_id;

-- CASE negative rate is rejected
-- INPUT
accounts
| account_id:int | type:text | balance:numeric |
|----------------|-----------|-----------------|
| 1              | savings   | 100.00          |

interest_log
| account_id:int | interest:numeric |
|----------------|------------------|

-- EXPECTED
ERROR: rate must be non-negative

-- CALL
CALL apply_interest(-0.01);

-- CASE existing log rows are kept, applied twice
-- INPUT
accounts
| account_id:int | type:text | balance:numeric |
|----------------|-----------|-----------------|
| 1              | savings   | 200.00          |
| 2              | checking  | 300.00          |

interest_log
| account_id:int | interest:numeric |
|----------------|------------------|
| 2              | 1.00             |

-- EXPECTED
| account_id | balance | interest |
|------------|---------|----------|
| 1          | 220.50  | 10.00    |
| 1          | 220.50  | 10.50    |
| 2          | 300.00  | 1.00     |

-- CALL
CALL apply_interest(0.05);
CALL apply_interest(0.05);
SELECT a.account_id, a.balance, l.interest
FROM accounts a LEFT JOIN interest_log l ON l.account_id = a.account_id
ORDER BY a.account_id, l.interest;
