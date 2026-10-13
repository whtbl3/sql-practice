-- HIDDEN TESTS for problem subquery/03. No QUERY section: the problem's QUERY is used.

-- CASE empty tables
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|

orders
| order_id:int | customer_id:int | product_id:int |
|--------------|-----------------|----------------|

products
| product_id:int | category:text |
|----------------|---------------|

-- EXPECTED
| name |
|------|

-- CASE only books were bought
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |

orders
| order_id:int | customer_id:int | product_id:int |
|--------------|-----------------|----------------|
| 1            | 1               | 12             |

products
| product_id:int | category:text |
|----------------|---------------|
| 12             | Books         |

-- EXPECTED
| name |
|------|

-- CASE many electronics orders from one customer
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |

orders
| order_id:int | customer_id:int | product_id:int |
|--------------|-----------------|----------------|
| 1            | 1               | 10             |
| 2            | 1               | 10             |
| 3            | 1               | 10             |
| 4            | 1               | 10             |
| 5            | 1               | 10             |

products
| product_id:int | category:text |
|----------------|---------------|
| 10             | Electronics   |

-- EXPECTED
| name |
|------|
| A    |
