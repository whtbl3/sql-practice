-- HIDDEN TESTS for problem subquery/02. No QUERY section: the problem's QUERY is used.

-- CASE empty tables
-- INPUT
products
| product_id:int | name:text |
|----------------|-----------|

order_items
| order_id:int | product_id:int | qty:int |
|--------------|----------------|---------|

-- EXPECTED
| name | units_sold | pct_of_units |
|------|------------|--------------|

-- CASE nothing sold yet
-- INPUT
products
| product_id:int | name:text |
|----------------|-----------|
| 1              | B         |
| 2              | A         |

order_items
| order_id:int | product_id:int | qty:int |
|--------------|----------------|---------|

-- EXPECTED
| name | units_sold | pct_of_units |
|------|------------|--------------|
| A    | 0          | NULL         |
| B    | 0          | NULL         |

-- CASE one product sells everything
-- INPUT
products
| product_id:int | name:text |
|----------------|-----------|
| 1              | A         |
| 2              | B         |

order_items
| order_id:int | product_id:int | qty:int |
|--------------|----------------|---------|
| 1            | 2              | 7       |
| 2            | 2              | 3       |

-- EXPECTED
| name | units_sold | pct_of_units |
|------|------------|--------------|
| B    | 10         | 100.0        |
| A    | 0          | 0.0          |
