-- HIDDEN TESTS for problem dml/03. No QUERY section: the problem's QUERY is used.

-- CASE empty orders table, every customer becomes Bronze
-- INPUT
customers
| customer_id:int | name:text | tier:text |
|-----------------|-----------|-----------|
| 1               | Alice     | New       |
| 2               | Bob       | New       |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|

-- EXPECTED
customers
| customer_id:int | name:text | tier:text |
|-----------------|-----------|-----------|
| 1               | Alice     | Bronze    |
| 2               | Bob       | Bronze    |

-- CASE right at the 1000 / 500 thresholds
-- INPUT
customers
| customer_id:int | name:text | tier:text |
|-----------------|-----------|-----------|
| 1               | Alice     | New       |
| 2               | Bob       | New       |
| 3               | Carol     | New       |
| 4               | Dan       | New       |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 1            | 1               | 600        |
| 2            | 1               | 400        |
| 3            | 2               | 999        |
| 4            | 3               | 500        |
| 5            | 4               | 499        |

-- EXPECTED
customers
| customer_id:int | name:text | tier:text |
|-----------------|-----------|-----------|
| 1               | Alice     | Gold      |
| 2               | Bob       | Silver    |
| 3               | Carol     | Silver    |
| 4               | Dan       | Bronze    |

-- CASE many small orders add up, orders of unknown customers ignored
-- INPUT
customers
| customer_id:int | name:text | tier:text |
|-----------------|-----------|-----------|
| 1               | Alice     | New       |

orders
| order_id:int | customer_id:int | amount:int |
|--------------|-----------------|------------|
| 1            | 1               | 400        |
| 2            | 1               | 400        |
| 3            | 1               | 400        |
| 4            | 99              | 5000       |

-- EXPECTED
customers
| customer_id:int | name:text | tier:text |
|-----------------|-----------|-----------|
| 1               | Alice     | Gold      |
