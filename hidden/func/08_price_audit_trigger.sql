-- HIDDEN TESTS for problem func/08. No QUERY section: the problem's QUERY is used.

-- CASE one UPDATE touching many rows logs each row
-- INPUT
products
| product_id:int | name:text | price:numeric |
|----------------|-----------|---------------|
| 1              | A         | 1.00          |
| 2              | B         | 2.00          |
| 3              | C         | 3.00          |

price_audit
| product_id:int | old_price:numeric | new_price:numeric |
|----------------|-------------------|-------------------|

-- EXPECTED
price_audit
| product_id | old_price | new_price |
|------------|-----------|-----------|
| 1          | 1.00      | 2.00      |
| 2          | 2.00      | 4.00      |
| 3          | 3.00      | 6.00      |

-- CALL
UPDATE products SET price = price * 2;

-- CASE value to NULL is a change, NULL to NULL is not
-- INPUT
products
| product_id:int | name:text | price:numeric |
|----------------|-----------|---------------|
| 1              | A         | 5.00          |
| 2              | B         | NULL          |

price_audit
| product_id:int | old_price:numeric | new_price:numeric |
|----------------|-------------------|-------------------|

-- EXPECTED
price_audit
| product_id | old_price | new_price:numeric |
|------------|-----------|-------------------|
| 1          | 5.00      | NULL              |

-- CALL
UPDATE products SET price = NULL;

-- CASE INSERT does not write to the audit
-- INPUT
products
| product_id:int | name:text | price:numeric |
|----------------|-----------|---------------|
| 1              | A         | 5.00          |

price_audit
| product_id:int | old_price:numeric | new_price:numeric |
|----------------|-------------------|-------------------|

-- EXPECTED
price_audit
| product_id:int | old_price:numeric | new_price:numeric |
|----------------|-------------------|-------------------|

-- CALL
INSERT INTO products VALUES (2, 'B', 9.00);
