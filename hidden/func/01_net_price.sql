-- HIDDEN TESTS for problem func/01. No QUERY section: the problem's QUERY is used.

-- CASE NULL price gives NULL
-- INPUT
products
| product_id:int | price:numeric | discount_pct:int |
|----------------|---------------|------------------|
| 1              | NULL          | 10               |
| 2              | NULL          | NULL             |

-- EXPECTED
| product_id | net:numeric |
|------------|-------------|
| 1          | NULL        |
| 2          | NULL        |

-- CASE 0 and 100 percent
-- INPUT
products
| product_id:int | price:numeric | discount_pct:int |
|----------------|---------------|------------------|
| 1              | 80.00         | 0                |
| 2              | 80.00         | 100              |

-- EXPECTED
| product_id | net   |
|------------|-------|
| 1          | 80.00 |
| 2          | 0.00  |

-- CASE rounding half up
-- INPUT
products
| product_id:int | price:numeric | discount_pct:int |
|----------------|---------------|------------------|
| 1              | 0.05          | 10               |
| 2              | 10.01         | 50               |

-- EXPECTED
| product_id | net  |
|------------|------|
| 1          | 0.05 |
| 2          | 5.01 |
