-- HIDDEN TESTS for problem gaps/03. No QUERY section: the problem's QUERY is used.

-- CASE no gaps at all: four buckets with 0 and NULL
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-01 |
| 3        | 2           | 2024-02-01 |

-- EXPECTED
| bucket     | gaps | pct_of_gaps |
|------------|------|-------------|
| 1-7 days   | 0    | NULL        |
| 8-30 days  | 0    | NULL        |
| 31-90 days | 0    | NULL        |
| 91+ days   | 0    | NULL        |

-- CASE every bucket boundary once: 7/8, 30/31, 90/91
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-08 |
| 3        | 2           | 2024-01-01 |
| 4        | 2           | 2024-01-09 |
| 5        | 3           | 2024-01-01 |
| 6        | 3           | 2024-01-31 |
| 7        | 4           | 2024-01-01 |
| 8        | 4           | 2024-02-01 |
| 9        | 5           | 2024-01-01 |
| 10       | 5           | 2024-03-31 |
| 11       | 6           | 2024-01-01 |
| 12       | 6           | 2024-04-01 |

-- EXPECTED
| bucket     | gaps | pct_of_gaps |
|------------|------|-------------|
| 1-7 days   | 1    | 16.7        |
| 8-30 days  | 2    | 33.3        |
| 31-90 days | 2    | 33.3        |
| 91+ days   | 1    | 16.7        |

-- CASE gaps only in one bucket
-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-02 |
| 3        | 1           | 2024-01-03 |

-- EXPECTED
| bucket     | gaps | pct_of_gaps |
|------------|------|-------------|
| 1-7 days   | 2    | 100.0       |
| 8-30 days  | 0    | 0.0         |
| 31-90 days | 0    | 0.0         |
| 91+ days   | 0    | 0.0         |
