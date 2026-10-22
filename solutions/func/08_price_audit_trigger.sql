-- Problem func/08: Price audit trigger  [Medium]
-- Pattern: Trigger function (RETURNS TRIGGER) + CREATE TRIGGER ... FOR EACH ROW
-- Variant: log only real changes (IS DISTINCT FROM, NULL-safe)
--
-- Task: Make every UPDATE of products write a row (product_id, old_price, new_price) into
--   price_audit, but only when the price actually changes (NULL -> value and value -> NULL count as
--   changes; an UPDATE that touches only the name or sets the same price does not). Write a trigger
--   function and the trigger. The CALL runs some UPDATEs; price_audit is checked afterwards.
-- Learn: grinding/sql-functions-procedures.md, mục 6

-- INPUT
products
| product_id:int | name:text | price:numeric |
|----------------|-----------|---------------|
| 1              | Pen       | 1.50          |
| 2              | Book      | 12.00         |
| 3              | Bag       | NULL          |

price_audit
| product_id:int | old_price:numeric | new_price:numeric |
|----------------|-------------------|-------------------|

-- EXPECTED
price_audit
| product_id | old_price | new_price |
|------------|-----------|-----------|
| 1          | 1.50      | 2.00      |
| 3          | NULL      | 30.00     |

-- CALL
UPDATE products SET price = 2.00 WHERE product_id = 1;
UPDATE products SET price = price WHERE product_id = 2;
UPDATE products SET price = 30.00 WHERE product_id = 3;
UPDATE products SET name = 'Blue Pen' WHERE product_id = 1;

-- QUERY
CREATE FUNCTION log_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.price IS DISTINCT FROM OLD.price THEN
    INSERT INTO price_audit (product_id, old_price, new_price)
    VALUES (NEW.product_id, OLD.price, NEW.price);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_price_audit
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_price_change();
