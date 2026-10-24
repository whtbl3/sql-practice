-- Problem churn/06: Net and gross revenue retention (NRR / GRR)  [Hard]
-- Pattern: Churn: MRR per customer-month (sum line items first) + base LEFT JOIN target + split by CASE
-- Variant: retention measured in money, not customers; new customers are excluded
--
-- Task: A Vietnamese SaaS (accounting software) bills monthly. subscription_items has one row per
--   customer, billing_month and product; a customer's MRR in a month = sum of mrr_vnd of their
--   rows that month (0 if none). Base month = 2024-01, target month = 2024-07. Only customers
--   with MRR > 0 in the base month are measured (customers that start later are ignored).
--   For each of them compare target MRR t with base MRR b:
--     t > b        -> expansion   t - b
--     0 < t < b    -> contraction b - t
--     t = 0        -> churned     b
--   Return ONE row: starting_mrr (sum of b), expansion_mrr, contraction_mrr, churned_mrr,
--   ending_mrr (sum of t), nrr_pct = ending_mrr / starting_mrr * 100 and
--   grr_pct = (starting_mrr - contraction_mrr - churned_mrr) / starting_mrr * 100, both rounded
--   to 1 decimal (NULL when starting_mrr = 0). Money columns are 0 when there is nothing to add.
-- Learn: grinding/sql-churn.md, V5

-- INPUT
subscription_items
| customer_id | billing_month | product    | mrr_vnd |
|-------------|---------------|------------|---------|
| 1           | 2024-01-01    | Pro        | 500000  |
| 1           | 2024-01-01    | E-invoice  | 100000  |
| 1           | 2024-07-01    | Pro        | 500000  |
| 1           | 2024-07-01    | E-invoice  | 100000  |
| 1           | 2024-07-01    | Inventory  | 200000  |
| 2           | 2024-01-01    | Pro        | 400000  |
| 2           | 2024-07-01    | Basic      | 250000  |
| 3           | 2024-01-01    | Basic      | 300000  |
| 3           | 2024-02-01    | Basic      | 300000  |
| 4           | 2024-01-01    | Basic      | 200000  |
| 4           | 2024-07-01    | Basic      | 200000  |
| 5           | 2024-07-01    | Enterprise | 900000  |
| 6           | 2024-01-01    | Pro        | 500000  |
| 6           | 2024-02-01    | Pro        | 500000  |
| 6           | 2024-07-01    | Pro        | 500000  |
| 7           | 2024-02-01    | Basic      | 300000  |
| 7           | 2024-07-01    | Basic      | 300000  |

-- EXPECTED
| starting_mrr | expansion_mrr | contraction_mrr | churned_mrr | ending_mrr | nrr_pct | grr_pct |
|--------------|---------------|-----------------|-------------|------------|---------|---------|
| 2000000      | 200000        | 150000          | 300000      | 1750000    | 87.5    | 77.5    |

-- QUERY
-- write your query here
