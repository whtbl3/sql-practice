-- HIDDEN TESTS for problem subquery/08. No QUERY section: the problem's QUERY is used.

-- CASE empty tables
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|

-- EXPECTED
| name | order_id | amount |
|------|----------|--------|

-- CASE three-way tie keeps the two smallest ids
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 7            | 1               | 5          |
| 3            | 1               | 5          |
| 9            | 1               | 5          |

-- EXPECTED
| name | order_id | amount |
|------|----------|--------|
| A    | 3        | 5      |
| A    | 7        | 5      |

-- CASE one order and no orders
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 1            | 1               | 9          |

-- EXPECTED
| name | order_id | amount |
|------|----------|--------|
| A    | 1        | 9      |
| B    | NULL     | NULL   |
