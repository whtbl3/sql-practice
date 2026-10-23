-- Problem func/09: Safe text-to-int cast (EXCEPTION block)  [Medium]
-- Pattern: BEGIN ... EXCEPTION WHEN <condition> THEN ... END
-- Variant: catch only the expected errors, not WHEN OTHERS
--
-- Task: Create to_int_or_null(p_text TEXT) RETURNS INT that returns p_text converted to an integer,
--   or NULL when it is NULL, not a valid integer (e.g. 'abc', '3.5'), or outside the INT range.
-- Learn: grinding/sql-function.md, B3

-- INPUT
raw_imports
| row_id:int | qty_text:text |
|------------|---------------|
| 1          | 12            |
| 2          | abc           |
| 3          | 3.5           |
| 4          | NULL          |
| 5          | 99999999999   |
| 6          | -4            |

-- EXPECTED
| row_id | qty  |
|--------|------|
| 1      | 12   |
| 2      | NULL |
| 3      | NULL |
| 4      | NULL |
| 5      | NULL |
| 6      | -4   |

-- CALL
SELECT row_id, to_int_or_null(qty_text) AS qty FROM raw_imports ORDER BY row_id;

-- QUERY
CREATE FUNCTION to_int_or_null(p_text TEXT)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN p_text::INT;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN NULL;
END;
$$;
