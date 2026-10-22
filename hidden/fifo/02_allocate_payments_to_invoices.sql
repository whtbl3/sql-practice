-- HIDDEN TESTS for problem fifo/02. No QUERY section: the problem's QUERY is used.

-- CASE no payments
-- INPUT
invoices
| invoice_id | customer | invoice_date | amount_vnd |
|------------|----------|--------------|------------|
| 1          | A        | 2024-01-01   | 100        |

payments
| payment_id:int | customer:text | paid_date:date | amount_vnd:int |
|----------------|---------------|----------------|----------------|

-- EXPECTED
| invoice_id | customer | amount_vnd | paid_vnd | outstanding_vnd | status |
|------------|----------|------------|----------|-----------------|--------|
| 1          | A        | 100        | 0        | 100             | Unpaid |

-- CASE payment exactly clears the first invoice; same-day invoices ordered by id
-- INPUT
invoices
| invoice_id | customer | invoice_date | amount_vnd |
|------------|----------|--------------|------------|
| 7          | A        | 2024-01-01   | 300        |
| 5          | A        | 2024-01-01   | 200        |
| 9          | A        | 2024-01-02   | 100        |

payments
| payment_id | customer | paid_date  | amount_vnd |
|------------|----------|------------|------------|
| 1          | A        | 2024-01-03 | 150        |
| 2          | A        | 2024-01-04 | 50         |
| 3          | B        | 2024-01-04 | 999        |

-- EXPECTED
| invoice_id | customer | amount_vnd | paid_vnd | outstanding_vnd | status |
|------------|----------|------------|----------|-----------------|--------|
| 5          | A        | 200        | 200      | 0               | Paid   |
| 7          | A        | 300        | 0        | 300             | Unpaid |
| 9          | A        | 100        | 0        | 100             | Unpaid |
