-- HIDDEN TESTS for problem cohort/08. No QUERY section: the problem's QUERY is used.

-- CASE nobody changes
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | An        |
| 2               | Binh      |

orders
| order_id:int | customer_id:int | order_date:date | status:text |
|--------------|-----------------|-----------------|-------------|
| 1            | 1               | 2023-12-01      | Completed   |

-- EXPECTED
| customer_id:int | segment_q1:text | segment_q2:text |
|-----------------|-----------------|-----------------|

-- CASE order on the snapshot date counts only for the later snapshot; unchanged Champion excluded
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | An        |
| 2               | Binh      |

orders
| order_id:int | customer_id:int | order_date:date | status:text |
|--------------|-----------------|-----------------|-------------|
| 1            | 1               | 2024-04-01      | Completed   |
| 2            | 1               | 2024-06-05      | Completed   |
| 3            | 1               | 2024-06-10      | Completed   |
| 4            | 2               | 2024-03-02      | Completed   |
| 5            | 2               | 2024-03-03      | Completed   |
| 6            | 2               | 2024-03-04      | Completed   |
| 7            | 2               | 2024-06-30      | Completed   |

-- EXPECTED
| customer_id | segment_q1  | segment_q2 |
|-------------|-------------|------------|
| 1           | Not Started | Champion   |
