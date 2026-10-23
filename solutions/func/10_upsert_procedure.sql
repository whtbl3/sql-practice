-- Problem func/10: Upsert procedure with FOUND  [Medium]
-- Pattern: UPDATE, then IF NOT FOUND THEN INSERT (special variable FOUND)
-- Variant: no unique constraint, so ON CONFLICT is not available
--
-- Task: Create a procedure upsert_price(p_sku TEXT, p_price NUMERIC). A negative or NULL price raises
--   an error containing 'price must be non-negative'. If the sku exists in price_list, set its price
--   to p_price and add 1 to updated_count; otherwise insert (p_sku, p_price, 0). Check price_list
--   after the CALLs.
-- Learn: grinding/sql-procedure.md, upsert

-- INPUT
price_list
| sku:text | price:numeric | updated_count:int |
|----------|---------------|-------------------|
| A        | 10.00         | 0                 |
| B        | 5.00          | 2                 |

-- EXPECTED
price_list
| sku | price | updated_count |
|-----|-------|---------------|
| A   | 10.00 | 0             |
| B   | 6.00  | 3             |
| C   | 4.00  | 1             |

-- CALL
CALL upsert_price('B', 6.00);
CALL upsert_price('C', 3.50);
CALL upsert_price('C', 4.00);

-- QUERY
CREATE PROCEDURE upsert_price(p_sku TEXT, p_price NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_price IS NULL OR p_price < 0 THEN
    RAISE EXCEPTION 'price must be non-negative';
  END IF;

  UPDATE price_list
  SET price = p_price, updated_count = updated_count + 1
  WHERE sku = p_sku;

  IF NOT FOUND THEN
    INSERT INTO price_list (sku, price, updated_count) VALUES (p_sku, p_price, 0);
  END IF;
END;
$$;
