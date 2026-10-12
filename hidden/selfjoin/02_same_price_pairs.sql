-- HIDDEN TESTS for problem selfjoin/02. No QUERY section: the problem's QUERY is used.

-- CASE no pairs
-- INPUT
products
| product_id:int | name:text | category:text | price:int |
|----------------|-----------|---------------|-----------|
| 1              | A         | x             | 1         |
| 2              | B         | x             | 2         |

-- EXPECTED
| product_1 | product_2 | category | price |
|-----------|-----------|----------|-------|

-- CASE same price in different categories is not a pair
-- INPUT
products
| product_id:int | name:text | category:text | price:int |
|----------------|-----------|---------------|-----------|
| 1              | A         | x             | 5         |
| 2              | B         | y             | 5         |

-- EXPECTED
| product_1 | product_2 | category | price |
|-----------|-----------|----------|-------|

-- CASE NULL prices never match
-- INPUT
products
| product_id:int | name:text | category:text | price:int |
|----------------|-----------|---------------|-----------|
| 1              | A         | x             | NULL      |
| 2              | B         | x             | NULL      |
| 3              | C         | x             | 7         |
| 4              | D         | x             | 7         |

-- EXPECTED
| product_1 | product_2 | category | price |
|-----------|-----------|----------|-------|
| C         | D         | x        | 7     |
