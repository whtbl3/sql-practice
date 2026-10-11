-- HIDDEN TESTS for problem dml/04. No QUERY section: the problem's QUERY is used.

-- CASE no orphan orders
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Alice     |
| 2               | Bob       |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 1            | 1               | 100        |
| 2            | 2               | 200        |

-- EXPECTED
orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 1            | 1               | 100        |
| 2            | 2               | 200        |

-- CASE empty customers table, all orders deleted
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 1            | 1               | 100        |
| 2            | 2               | 200        |

-- EXPECTED
orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|

-- CASE several orders of the same orphan customer
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Alice     |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 1            | 9               | 10         |
| 2            | 9               | 20         |
| 3            | 1               | 30         |

-- EXPECTED
orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 3            | 1               | 30         |

-- CASE empty orders table
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Alice     |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|

-- EXPECTED
orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
