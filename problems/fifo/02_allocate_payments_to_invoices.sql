-- Problem fifo/02: Apply payments to the oldest invoices first  [Medium]
-- Pattern: FIFO: running SUM(amount) of invoices per customer vs total paid -> paid part of each invoice
-- Variant: money instead of stock; status label per invoice; overpayment becomes unused credit
--
-- Task: A distributor applies every customer's payments to their oldest unpaid invoices first
--   (by invoice_date, then invoice_id). Whatever is left after the last invoice stays as credit
--   and is ignored here. For every invoice return invoice_id, customer, amount_vnd, paid_vnd,
--   outstanding_vnd and status: 'Paid' (nothing outstanding), 'Unpaid'
--   (nothing paid) or 'Partial'. Sort by customer, invoice_date, invoice_id.
-- Learn: grinding/sql-fifo.md, V1

-- INPUT
invoices
| invoice_id | customer            | invoice_date | amount_vnd |
|------------|---------------------|--------------|------------|
| 101        | Sunrise Distributor | 2024-03-01   | 5000000    |
| 102        | Sunrise Distributor | 2024-03-15   | 3000000    |
| 103        | Sunrise Distributor | 2024-04-01   | 4000000    |
| 104        | Corner Grocery      | 2024-03-05   | 2000000    |
| 105        | Corner Grocery      | 2024-03-20   | 1000000    |
| 106        | Lucky Mart          | 2024-03-10   | 6000000    |

payments
| payment_id | customer            | paid_date  | amount_vnd |
|------------|---------------------|------------|------------|
| 1          | Sunrise Distributor | 2024-03-10 | 4000000    |
| 2          | Sunrise Distributor | 2024-04-05 | 2500000    |
| 3          | Corner Grocery      | 2024-03-25 | 3500000    |

-- EXPECTED
| invoice_id | customer            | amount_vnd | paid_vnd | outstanding_vnd | status  |
|------------|---------------------|------------|----------|-----------------|---------|
| 104        | Corner Grocery      | 2000000    | 2000000  | 0               | Paid    |
| 105        | Corner Grocery      | 1000000    | 1000000  | 0               | Paid    |
| 106        | Lucky Mart          | 6000000    | 0        | 6000000         | Unpaid  |
| 101        | Sunrise Distributor | 5000000    | 5000000  | 0               | Paid    |
| 102        | Sunrise Distributor | 3000000    | 1500000  | 1500000         | Partial |
| 103        | Sunrise Distributor | 4000000    | 0        | 4000000         | Unpaid  |

-- QUERY
-- write your query here
