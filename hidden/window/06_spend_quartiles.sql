-- HIDDEN TESTS for problem window/06. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
customer_spend
| customer:text | total_spent:int |
|---------------|-----------------|

-- EXPECTED
| customer | total_spent | quartile | pct_rank |
|----------|-------------|----------|----------|

-- CASE single customer
-- INPUT
customer_spend
| customer:text | total_spent:int |
|---------------|-----------------|
| X             | 10              |

-- EXPECTED
| customer | total_spent | quartile | pct_rank |
|----------|-------------|----------|----------|
| X        | 10          | 1        | 0.00     |

-- CASE fewer rows than buckets
-- INPUT
customer_spend
| customer:text | total_spent:int |
|---------------|-----------------|
| a             | 3               |
| b             | 2               |
| c             | 1               |

-- EXPECTED
| customer | total_spent | quartile | pct_rank |
|----------|-------------|----------|----------|
| a        | 3           | 1        | 0.00     |
| b        | 2           | 2        | 0.50     |
| c        | 1           | 3        | 1.00     |
