-- Problem dp/04: Fewest vouchers to pay an exact amount (coin change)  [Hard]
-- Pattern: DP as BFS with a recursive CTE: states (amount reached, vouchers used), UNION dedupes, MIN at the end
-- Variant: odd voucher values where taking the biggest voucher first is NOT optimal
--
-- Task: A loyalty app pays with point vouchers; each voucher value can be used any number of
--   times. For every payment, find the smallest number of vouchers whose values add up to
--   EXACTLY amount (0 vouchers for amount 0). Return payment_id, amount and min_vouchers (NULL
--   when the amount cannot be made). Sort by payment_id.
-- Learn: grinding/sql-dp.md, B4–B5

-- INPUT
vouchers
| value |
|-------|
| 1     |
| 3     |
| 4     |

payments
| payment_id | amount |
|------------|--------|
| 1          | 6      |
| 2          | 7      |
| 3          | 2      |
| 4          | 0      |
| 5          | 12     |
| 6          | 13     |

-- EXPECTED
| payment_id | amount | min_vouchers |
|------------|--------|--------------|
| 1          | 6      | 2            |
| 2          | 7      | 2            |
| 3          | 2      | 2            |
| 4          | 0      | 0            |
| 5          | 12     | 3            |
| 6          | 13     | 4            |

-- QUERY
-- write your query here
