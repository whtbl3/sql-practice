-- HIDDEN TESTS for problem gaps/04. No QUERY section: the problem's QUERY is used.

-- CASE nobody has 3 gaps
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-02 |
| 3        | 1           | 2024-01-03 |
| 4        | 1           | 2024-01-03 |

-- EXPECTED
| customer_id:int | median_gap:numeric | days_since_last:int | ratio:numeric |
|-----------------|--------------------|---------------------|---------------|

-- CASE the mean would hide a late customer: gaps 60, 60, 1, 1, 1 have median 1 (mean 24.6)
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-07-31 |
| 2        | 1           | 2024-09-29 |
| 3        | 1           | 2024-11-28 |
| 4        | 1           | 2024-11-29 |
| 5        | 1           | 2024-11-30 |
| 6        | 1           | 2024-12-01 |

-- EXPECTED
| customer_id | median_gap | days_since_last | ratio |
|-------------|------------|-----------------|-------|
| 1           | 1.0        | 30              | 30.0  |

-- CASE even number of gaps with a .5 median, and a tie on ratio sorted by customer_id
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 8           | 2024-12-01 |
| 2        | 8           | 2024-12-03 |
| 3        | 8           | 2024-12-06 |
| 4        | 8           | 2024-12-08 |
| 5        | 8           | 2024-12-11 |
| 6        | 7           | 2024-12-01 |
| 7        | 7           | 2024-12-03 |
| 8        | 7           | 2024-12-06 |
| 9        | 7           | 2024-12-08 |
| 10       | 7           | 2024-12-11 |

-- EXPECTED
| customer_id | median_gap | days_since_last | ratio |
|-------------|------------|-----------------|-------|
| 7           | 2.5        | 20              | 8.0   |
| 8           | 2.5        | 20              | 8.0   |
