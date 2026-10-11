-- HIDDEN TESTS for problem cohort/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|

-- EXPECTED
| cohort_month | month_offset | active_customers | retention_pct |
|--------------|--------------|------------------|---------------|

-- CASE one customer, one order
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-03-10      |

-- EXPECTED
| cohort_month | month_offset | active_customers | retention_pct |
|--------------|--------------|------------------|---------------|
| 2024-03      | 0            | 1                | 100.0         |

-- CASE cohort across new year, uneven returns
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2023-12-05      |
| 2            | 1               | 2024-01-05      |
| 3            | 1               | 2024-03-05      |
| 4            | 2               | 2023-12-20      |
| 5            | 3               | 2023-12-11      |
| 6            | 3               | 2024-02-11      |

-- EXPECTED
| cohort_month | month_offset | active_customers | retention_pct |
|--------------|--------------|------------------|---------------|
| 2023-12      | 0            | 3                | 100.0         |
| 2023-12      | 1            | 1                | 33.3          |
| 2023-12      | 2            | 1                | 33.3          |
| 2023-12      | 3            | 1                | 33.3          |

-- CASE several orders in the same month
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-01-02      |
| 2            | 1               | 2024-01-15      |
| 3            | 1               | 2024-01-30      |
| 4            | 1               | 2024-02-03      |
| 5            | 1               | 2024-02-20      |

-- EXPECTED
| cohort_month | month_offset | active_customers | retention_pct |
|--------------|--------------|------------------|---------------|
| 2024-01      | 0            | 1                | 100.0         |
| 2024-01      | 1            | 1                | 100.0         |
