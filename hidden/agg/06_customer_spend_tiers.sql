-- HIDDEN TESTS for problem agg/06. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer:text | amount:int |
|--------------|---------------|------------|

-- EXPECTED
| customer | orders | total_spent | tier |
|----------|--------|-------------|------|

-- CASE just below the boundaries
-- INPUT
orders
| order_id:int | customer:text | amount:int |
|--------------|---------------|------------|
| 1            | A             | 999        |
| 2            | B             | 499        |

-- EXPECTED
| customer | orders | total_spent | tier   |
|----------|--------|-------------|--------|
| A        | 1      | 999         | Silver |
| B        | 1      | 499         | Bronze |

-- CASE tie on spend is sorted by customer
-- INPUT
orders
| order_id:int | customer:text | amount:int |
|--------------|---------------|------------|
| 1            | Z             | 5          |
| 2            | M             | 5          |

-- EXPECTED
| customer | orders | total_spent | tier   |
|----------|--------|-------------|--------|
| M        | 1      | 5           | Bronze |
| Z        | 1      | 5           | Bronze |
