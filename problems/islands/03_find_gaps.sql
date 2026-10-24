-- Problem islands/03: Find missing invoice numbers  [Medium]
-- Pattern: Gaps & Islands (LEAD)
-- Variant: report the GAPS between islands instead of the islands
--
-- Task: Invoice numbers should be continuous. Return every range of missing numbers strictly
--   between the smallest and the largest invoice_no as gap_start and gap_end (both inclusive).
--   Sort by gap_start.
-- Learn: grinding/sql-gaps-islands.md, V3

-- INPUT
invoices
| invoice_no:int |
|----------------|
| 1              |
| 2              |
| 3              |
| 7              |
| 8              |
| 10             |
| 15             |

-- EXPECTED
| gap_start | gap_end |
|-----------|---------|
| 4         | 6       |
| 9         | 9       |
| 11        | 14      |

-- QUERY
-- write your query here
WITH gaps AS (
  SELECT
    invoice_no,
    LEAD(invoice_no) OVER () AS next_invoice_no
  FROM invoices
)
SELECT
  invoice_no + 1 AS gap_start,
  next_invoice_no - 1 AS gap_end
FROM
  gaps
WHERE next_invoice_no - invoice_no > 1