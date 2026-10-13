-- Problem agg/02: Suppliers that deliver late frequently  [Medium]
-- Pattern: GROUP BY + HAVING on two aggregates
-- Variant: HAVING
--
-- Task: Return suppliers with at least 3 deliveries AND an average lateness (actual_date -
--   expected_date, in days) above 0. Show deliveries, avg_late_days (1 decimal) and on_time_pct, the
--   % of deliveries with actual_date <= expected_date (1 decimal). Sort by avg_late_days DESC, supplier.

-- INPUT
deliveries
| delivery_id | supplier | expected_date | actual_date |
|-------------|----------|---------------|-------------|
| 1           | Acme     | 2024-03-01    | 2024-03-03  |
| 2           | Acme     | 2024-03-05    | 2024-03-05  |
| 3           | Acme     | 2024-03-10    | 2024-03-14  |
| 4           | Beta     | 2024-03-01    | 2024-02-29  |
| 5           | Beta     | 2024-03-02    | 2024-03-02  |
| 6           | Beta     | 2024-03-03    | 2024-03-04  |
| 7           | Cora     | 2024-03-01    | 2024-03-05  |
| 8           | Cora     | 2024-03-02    | 2024-03-06  |
| 9           | Dune     | 2024-03-01    | 2024-03-04  |
| 10          | Dune     | 2024-03-02    | 2024-03-05  |
| 11          | Dune     | 2024-03-03    | 2024-03-03  |
| 12          | Dune     | 2024-03-04    | 2024-03-04  |

-- EXPECTED
| supplier | deliveries | avg_late_days | on_time_pct |
|----------|------------|---------------|-------------|
| Acme     | 3          | 2.0           | 33.3        |
| Dune     | 4          | 1.5           | 50.0        |

-- QUERY
-- write your query here
WITH deliver_stats AS (
  SELECT
    supplier,
    COUNT(*) AS deliveries,
    ROUND(AVG(actual_date - expected_date),1) AS avg_late_days,
    ROUND(AVG(CASE WHEN actual_date <= expected_date THEN 1.0 ELSE 0.0 END) * 100.0,1) AS on_time_pct
  FROM deliveries
  GROUP BY supplier
)
SELECT * FROM deliver_stats
WHERE deliveries >= 3 AND avg_late_days > 0
ORDER BY avg_late_days DESC, supplier ASC
