-- HIDDEN TESTS for problem dp/04. No QUERY section: the problem's QUERY is used.

-- CASE amounts that cannot be made
-- INPUT
vouchers
| value |
|-------|
| 5     |
| 10    |

payments
| payment_id | amount |
|------------|--------|
| 1          | 3      |
| 2          | 15     |
| 3          | 20     |

-- EXPECTED
| payment_id | amount | min_vouchers |
|------------|--------|--------------|
| 1          | 3      | NULL         |
| 2          | 15     | 2            |
| 3          | 20     | 2            |

-- CASE greedy 9 + 1 + 1 + 1 loses to 4 + 4 + 4
-- INPUT
vouchers
| value |
|-------|
| 1     |
| 4     |
| 9     |

payments
| payment_id | amount |
|------------|--------|
| 1          | 12     |
| 2          | 9      |

-- EXPECTED
| payment_id | amount | min_vouchers |
|------------|--------|--------------|
| 1          | 12     | 3            |
| 2          | 9      | 1            |
