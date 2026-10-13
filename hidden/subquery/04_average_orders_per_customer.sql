-- HIDDEN TESTS for problem subquery/04. No QUERY section: the problem's QUERY is used.

-- CASE no customers at all
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|

orders
| order_id:int | customer_id:int |
|--------------|-----------------|

-- EXPECTED
| customers | avg_orders | max_orders |
|-----------|------------|------------|
| 0         | NULL       | NULL       |

-- CASE customers but no orders
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |
| 3               | C         |

orders
| order_id:int | customer_id:int |
|--------------|-----------------|

-- EXPECTED
| customers | avg_orders | max_orders |
|-----------|------------|------------|
| 3         | 0.00       | 0          |

-- CASE orders of an unknown customer are ignored
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |

orders
| order_id:int | customer_id:int |
|--------------|-----------------|
| 1            | 1               |
| 2            | 99              |

-- EXPECTED
| customers | avg_orders | max_orders |
|-----------|------------|------------|
| 2         | 0.50       | 1          |
