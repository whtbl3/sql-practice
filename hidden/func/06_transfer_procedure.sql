-- HIDDEN TESTS for problem func/06. No QUERY section: the problem's QUERY is used.

-- CASE transfer the whole balance
-- INPUT
accounts
| account_id:int | owner:text | balance:numeric |
|----------------|------------|-----------------|
| 1              | A          | 25.50           |
| 2              | B          | 0.00            |

-- EXPECTED
accounts
| account_id | owner | balance |
|------------|-------|---------|
| 1          | A     | 0.00    |
| 2          | B     | 25.50   |

-- CALL
CALL transfer(1, 2, 25.50);

-- CASE insufficient funds
-- INPUT
accounts
| account_id:int | owner:text | balance:numeric |
|----------------|------------|-----------------|
| 1              | A          | 10.00           |
| 2              | B          | 0.00            |

-- EXPECTED
ERROR: insufficient funds

-- CALL
CALL transfer(1, 2, 10.01);

-- CASE negative amount
-- INPUT
accounts
| account_id:int | owner:text | balance:numeric |
|----------------|------------|-----------------|
| 1              | A          | 10.00           |
| 2              | B          | 0.00            |

-- EXPECTED
ERROR: amount must be positive

-- CALL
CALL transfer(2, 1, -5);

-- CASE destination does not exist
-- INPUT
accounts
| account_id:int | owner:text | balance:numeric |
|----------------|------------|-----------------|
| 1              | A          | 10.00           |

-- EXPECTED
ERROR: account not found

-- CALL
CALL transfer(1, 99, 5);

-- CASE source does not exist
-- INPUT
accounts
| account_id:int | owner:text | balance:numeric |
|----------------|------------|-----------------|
| 1              | A          | 10.00           |

-- EXPECTED
ERROR: account not found

-- CALL
CALL transfer(99, 1, 5);

-- CASE same account
-- INPUT
accounts
| account_id:int | owner:text | balance:numeric |
|----------------|------------|-----------------|
| 1              | A          | 10.00           |

-- EXPECTED
ERROR: same account

-- CALL
CALL transfer(1, 1, 5);
