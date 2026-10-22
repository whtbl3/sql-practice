-- HIDDEN TESTS for problem func/09. No QUERY section: the problem's QUERY is used.

-- CASE all valid
-- INPUT
raw_imports
| row_id:int | qty_text:text |
|------------|---------------|
| 1          | 0             |
| 2          | +5            |
| 3          | 2147483647    |

-- EXPECTED
| row_id | qty        |
|--------|------------|
| 1      | 0          |
| 2      | 5          |
| 3      | 2147483647 |

-- CASE just outside the INT range
-- INPUT
raw_imports
| row_id:int | qty_text:text |
|------------|---------------|
| 1          | 2147483648    |
| 2          | -2147483649   |
| 3          | 1e3           |

-- EXPECTED
| row_id | qty:int |
|--------|---------|
| 1      | NULL    |
| 2      | NULL    |
| 3      | NULL    |
