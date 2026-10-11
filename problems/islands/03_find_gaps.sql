-- Problem islands/03: Find missing invoice numbers  [Medium]
-- Pattern: Gaps & Islands (LEAD)
-- Variant: report the GAPS between islands instead of the islands
--
-- Task: Invoice numbers should be continuous. Return every range of missing numbers strictly
--   between the smallest and the largest invoice_no as gap_start and gap_end (both inclusive).
--   Sort by gap_start.

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
