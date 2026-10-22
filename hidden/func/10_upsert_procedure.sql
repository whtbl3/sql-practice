-- HIDDEN TESTS for problem func/10. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
price_list
| sku:text | price:numeric | updated_count:int |
|----------|---------------|-------------------|

-- EXPECTED
price_list
| sku | price | updated_count |
|-----|-------|---------------|
| X   | 1.00  | 0             |

-- CALL
CALL upsert_price('X', 1.00);

-- CASE sku is case-sensitive, price 0 is allowed
-- INPUT
price_list
| sku:text | price:numeric | updated_count:int |
|----------|---------------|-------------------|
| A        | 10.00         | 0                 |

-- EXPECTED
price_list
| sku | price | updated_count |
|-----|-------|---------------|
| A   | 0.00  | 1             |
| a   | 2.00  | 0             |

-- CALL
CALL upsert_price('a', 2.00);
CALL upsert_price('A', 0.00);

-- CASE negative price is rejected
-- INPUT
price_list
| sku:text | price:numeric | updated_count:int |
|----------|---------------|-------------------|
| A        | 10.00         | 0                 |

-- EXPECTED
ERROR: price must be non-negative

-- CALL
CALL upsert_price('A', -1);
