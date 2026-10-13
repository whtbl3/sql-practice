-- HIDDEN TESTS for problem window/12. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
monthly_revenue
| month:date | revenue:int |
|------------|-------------|

-- EXPECTED
| month | revenue | previous_best |
|-------|---------|---------------|

-- CASE falling every month
-- INPUT
monthly_revenue
| month:date | revenue:int |
|------------|-------------|
| 2024-01-01 | 30          |
| 2024-02-01 | 20          |
| 2024-03-01 | 10          |

-- EXPECTED
| month      | revenue | previous_best |
|------------|---------|---------------|
| 2024-01-01 | 30      | NULL          |

-- CASE rising every month
-- INPUT
monthly_revenue
| month:date | revenue:int |
|------------|-------------|
| 2024-01-01 | 1           |
| 2024-02-01 | 2           |
| 2024-03-01 | 3           |

-- EXPECTED
| month      | revenue | previous_best |
|------------|---------|---------------|
| 2024-01-01 | 1       | NULL          |
| 2024-02-01 | 2       | 1             |
| 2024-03-01 | 3       | 2             |
