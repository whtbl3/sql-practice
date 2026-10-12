-- HIDDEN TESTS for problem antijoin/03. No QUERY section: the problem's QUERY is used.

-- CASE empty tables
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|

orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|

-- EXPECTED
| name |
|------|

-- CASE cut-off day itself counts as active
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Ann       |

orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-01-01      |
| 2            | 1               | 2024-06-01      |

-- EXPECTED
| name |
|------|

-- CASE day before the cut-off is lapsed
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Ann       |
| 2               | Bob       |

orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-05-31      |
| 2            | 2               | 2024-06-02      |

-- EXPECTED
| name |
|------|
| Ann  |
