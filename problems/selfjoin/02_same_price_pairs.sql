-- Problem selfjoin/02: Product pairs with the same price  [Medium]
-- Pattern: Self join (pair each row once with a.id < b.id)
-- Variant: unordered pairs
--
-- Task: List every pair of products in the same category with the same price, each pair once.
--   Return product_1, product_2, category, price where product_1 has the smaller product_id.
--   Sort by product_1, product_2.

-- INPUT
products
| product_id | name    | category | price |
|------------|---------|----------|-------|
| 1          | Pen     | office   | 5     |
| 2          | Pencil  | office   | 5     |
| 3          | Stapler | office   | 12    |
| 4          | Mug     | kitchen  | 5     |
| 5          | Cup     | kitchen  | 5     |
| 6          | Bowl    | kitchen  | 5     |

-- EXPECTED
| product_1 | product_2 | category | price |
|-----------|-----------|----------|-------|
| Cup       | Bowl      | kitchen  | 5     |
| Mug       | Bowl      | kitchen  | 5     |
| Mug       | Cup       | kitchen  | 5     |
| Pen       | Pencil    | office   | 5     |

-- QUERY
-- write your query here
