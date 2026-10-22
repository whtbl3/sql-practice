-- HIDDEN TESTS for problem churn/06. No QUERY section: the problem's QUERY is used.

-- CASE no base customers: one row of zeros
-- INPUT
subscription_items
| customer_id | billing_month | product | mrr_vnd |
|-------------|---------------|---------|---------|
| 1           | 2024-07-01    | Pro     | 500000  |

-- EXPECTED
| starting_mrr | expansion_mrr | contraction_mrr | churned_mrr | ending_mrr | nrr_pct | grr_pct |
|--------------|---------------|-----------------|-------------|------------|---------|---------|
| 0            | 0             | 0               | 0           | 0          | NULL    | NULL    |

-- CASE everybody expands: NRR above 100, GRR exactly 100
-- INPUT
subscription_items
| customer_id | billing_month | product   | mrr_vnd |
|-------------|---------------|-----------|---------|
| 1           | 2024-01-01    | Basic     | 200000  |
| 1           | 2024-07-01    | Pro       | 500000  |
| 2           | 2024-01-01    | Basic     | 200000  |
| 2           | 2024-07-01    | Basic     | 200000  |
| 2           | 2024-07-01    | Inventory | 100000  |

-- EXPECTED
| starting_mrr | expansion_mrr | contraction_mrr | churned_mrr | ending_mrr | nrr_pct | grr_pct |
|--------------|---------------|-----------------|-------------|------------|---------|---------|
| 400000       | 400000        | 0               | 0           | 800000     | 200.0   | 100.0   |

-- CASE several line items: compare monthly totals, not single rows
-- INPUT
subscription_items
| customer_id | billing_month | product   | mrr_vnd |
|-------------|---------------|-----------|---------|
| 1           | 2024-01-01    | Pro       | 300000  |
| 1           | 2024-01-01    | Inventory | 300000  |
| 1           | 2024-07-01    | Pro       | 300000  |
| 1           | 2024-07-01    | E-invoice | 200000  |
| 2           | 2024-01-01    | Basic     | 100000  |
| 2           | 2024-01-01    | Inventory | 100000  |

-- EXPECTED
| starting_mrr | expansion_mrr | contraction_mrr | churned_mrr | ending_mrr | nrr_pct | grr_pct |
|--------------|---------------|-----------------|-------------|------------|---------|---------|
| 800000       | 0             | 100000          | 200000      | 500000     | 62.5    | 62.5    |
