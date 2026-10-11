-- Problem dml/06: Apply shipments to inventory (upsert)  [Hard]
-- Pattern: Upsert without ON CONFLICT: UPDATE existing rows, then INSERT missing ones
-- Variant: two statements whose ORDER matters
--
-- Task: Apply the shipments to the inventory: for a sku that already exists in inventory add the
--   shipment qty to its qty; for a new sku insert a new row. Each sku appears at most once in
--   shipments. Use two statements (UPDATE, then INSERT) in an order that does not double-count
--   new rows. Check the inventory table afterwards.

-- INPUT
inventory
| sku:text | qty:int |
|----------|---------|
| A        | 10      |
| B        | 5       |

shipments
| sku:text | qty:int |
|----------|---------|
| B        | 3       |
| C        | 7       |

-- EXPECTED
inventory
| sku | qty |
|-----|-----|
| A   | 10  |
| B   | 8   |
| C   | 7   |

-- QUERY
UPDATE inventory i
SET qty = i.qty + s.qty
FROM shipments s
WHERE i.sku = s.sku;

INSERT INTO inventory (sku, qty)
SELECT s.sku, s.qty
FROM shipments s
WHERE NOT EXISTS (SELECT 1 FROM inventory i WHERE i.sku = s.sku);
