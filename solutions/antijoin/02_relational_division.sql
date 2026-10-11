-- Problem antijoin/02: Customers who bought every Electronics product  [Hard]
-- Pattern: Relational division (HAVING COUNT DISTINCT = total)
-- Variant: "for ALL" instead of "for NONE"
--
-- Task: Find customers who bought EVERY product in the 'Electronics' category (a customer may buy
--   the same product several times). Return customer_id; sort by customer_id.

-- INPUT
products
| product_id | product_name | category    |
|------------|--------------|-------------|
| 1          | Laptop       | Electronics |
| 2          | Phone        | Electronics |
| 3          | Tablet       | Electronics |
| 4          | Desk         | Furniture   |

purchases
| customer_id | product_id |
|-------------|------------|
| 1           | 1          |
| 1           | 2          |
| 1           | 3          |
| 1           | 1          |
| 2           | 1          |
| 2           | 2          |
| 3           | 1          |
| 3           | 2          |
| 3           | 3          |
| 3           | 4          |
| 4           | 4          |

-- EXPECTED
| customer_id |
|-------------|
| 1           |
| 3           |

-- QUERY
SELECT p.customer_id
FROM purchases p
JOIN products pr ON pr.product_id = p.product_id
WHERE pr.category = 'Electronics'
GROUP BY p.customer_id
HAVING COUNT(DISTINCT p.product_id) = (SELECT COUNT(*) FROM products WHERE category = 'Electronics')
ORDER BY p.customer_id;
