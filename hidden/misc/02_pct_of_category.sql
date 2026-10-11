-- HIDDEN TESTS for problem misc/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|

transactions
| transaction_id:int | product_id:int | amount:int |
|--------------------|----------------|------------|

-- EXPECTED
| category | product_name | total_sold | pct_of_category |
|----------|--------------|------------|-----------------|

-- CASE category with a single product
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | Chips             | Snack         |

transactions
| transaction_id:int | product_id:int | amount:int |
|--------------------|----------------|------------|
| 1                  | 1              | 40         |

-- EXPECTED
| category | product_name | total_sold | pct_of_category |
|----------|--------------|------------|-----------------|
| Snack    | Chips        | 40         | 100.00          |

-- CASE uneven split, rounding
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | Milk              | Beverage      |
| 2              | Water             | Beverage      |

transactions
| transaction_id:int | product_id:int | amount:int |
|--------------------|----------------|------------|
| 1                  | 1              | 1          |
| 2                  | 2              | 2          |

-- EXPECTED
| category | product_name | total_sold | pct_of_category |
|----------|--------------|------------|-----------------|
| Beverage | Milk         | 1          | 33.33           |
| Beverage | Water        | 2          | 66.67           |

-- CASE two products with equal totals
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | Milk              | Beverage      |
| 2              | Water             | Beverage      |

transactions
| transaction_id:int | product_id:int | amount:int |
|--------------------|----------------|------------|
| 1                  | 1              | 50         |
| 2                  | 2              | 50         |

-- EXPECTED
| category | product_name | total_sold | pct_of_category |
|----------|--------------|------------|-----------------|
| Beverage | Milk         | 50         | 50.00           |
| Beverage | Water        | 50         | 50.00           |
