-- Problem gaps/03: Distribution of gaps by bucket  [Medium]
-- Pattern: Gaps: LAG gaps + bucket table (VALUES) range LEFT JOIN + share of total
-- Variant: a histogram: every bucket listed, business order, share of all gaps
--
-- Task: Using distinct purchase days per customer, compute every gap (days between two
--   consecutive purchase days of the same customer). Put each gap in a bucket:
--     '1-7 days'    1 to 7 days
--     '8-30 days'   8 to 30 days
--     '31-90 days'  31 to 90 days
--     '91+ days'    91 days or more
--   Return bucket, gaps (number of gaps in it) and pct_of_gaps = gaps / all gaps * 100 rounded
--   to 1 decimal (NULL when there are no gaps at all). List all four buckets, even empty ones,
--   in the order above.
-- Learn: grinding/sql-purchase-gaps.md, V2

-- INPUT
orders
| order_id | customer_id | order_date |
|----------|-------------|------------|
| 1        | 1           | 2024-01-01 |
| 2        | 1           | 2024-01-04 |
| 3        | 1           | 2024-01-04 |
| 4        | 1           | 2024-01-11 |
| 5        | 1           | 2024-01-19 |
| 6        | 1           | 2024-02-18 |
| 7        | 2           | 2024-01-01 |
| 8        | 2           | 2024-02-01 |
| 9        | 2           | 2024-05-01 |
| 10       | 2           | 2024-07-31 |
| 11       | 3           | 2024-01-01 |
| 12       | 3           | 2024-01-16 |
| 13       | 3           | 2024-03-01 |
| 14       | 3           | 2024-09-17 |
| 15       | 4           | 2024-06-06 |

-- EXPECTED
| bucket     | gaps | pct_of_gaps |
|------------|------|-------------|
| 1-7 days   | 2    | 20.0        |
| 8-30 days  | 3    | 30.0        |
| 31-90 days | 3    | 30.0        |
| 91+ days   | 2    | 20.0        |

-- QUERY
-- write your query here
