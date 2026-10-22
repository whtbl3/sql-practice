-- Problem agg/10: Orders that match a combo exactly  [Hard]
-- Pattern: Exact relational division: JOIN on item, then HAVING matches = size of the order set = size of the combo set
-- Variant: antijoin/02 asks "has at least all"; here extra items or missing items both disqualify
--
-- Task: A breakfast chain gives a combo price only when an order contains EXACTLY the items of a
--   combo: all of them and nothing else (quantities and how many lines an item uses do not
--   matter). For every order that matches a combo return order_id and combo.
--   Sort by order_id.
-- Learn: grinding/sql-common-pitfalls.md, mục E2

-- INPUT
combo_items
| combo           | item        |
|-----------------|-------------|
| Breakfast combo | Bread roll  |
| Breakfast combo | Milk coffee |
| Lunch combo     | Broken rice |
| Lunch combo     | Iced tea    |

order_items
| line_id | order_id | item        | qty |
|---------|----------|-------------|-----|
| 1       | 1        | Bread roll  | 1   |
| 2       | 1        | Milk coffee | 1   |
| 3       | 2        | Bread roll  | 1   |
| 4       | 2        | Milk coffee | 1   |
| 5       | 2        | Iced tea    | 1   |
| 6       | 3        | Bread roll  | 2   |
| 7       | 4        | Broken rice | 1   |
| 8       | 4        | Broken rice | 1   |
| 9       | 4        | Iced tea    | 2   |
| 10      | 5        | Broken rice | 1   |
| 11      | 5        | Iced tea    | 1   |
| 12      | 5        | Bread roll  | 1   |
| 13      | 5        | Milk coffee | 1   |

-- EXPECTED
| order_id | combo           |
|----------|-----------------|
| 1        | Breakfast combo |
| 4        | Lunch combo     |

-- QUERY
-- write your query here
