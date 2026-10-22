-- HIDDEN TESTS for problem agg/10. No QUERY section: the problem's QUERY is used.

-- CASE no order matches
-- INPUT
combo_items
| combo | item |
|-------|------|
| C1    | A    |
| C1    | B    |

order_items
| line_id | order_id | item | qty |
|---------|----------|------|-----|
| 1       | 1        | A    | 1   |
| 2       | 2        | A    | 1   |
| 3       | 2        | B    | 1   |
| 4       | 2        | C    | 1   |

-- EXPECTED
| order_id:int | combo:text |
|--------------|------------|

-- CASE an order repeating one item of a 2-item combo has 2 lines but only 1 distinct item
-- INPUT
combo_items
| combo | item |
|-------|------|
| C1    | A    |
| C1    | B    |
| C2    | A    |

order_items
| line_id | order_id | item | qty |
|---------|----------|------|-----|
| 1       | 1        | A    | 1   |
| 2       | 1        | A    | 1   |
| 3       | 2        | B    | 1   |
| 4       | 2        | A    | 3   |

-- EXPECTED
| order_id | combo |
|----------|-------|
| 1        | C2    |
| 2        | C1    |
