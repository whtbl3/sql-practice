-- HIDDEN TESTS for problem window/11. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
product_sales
| product:text | revenue:int |
|--------------|-------------|

-- EXPECTED
| product | revenue | cumulative_pct |
|---------|---------|----------------|

-- CASE one product dominates
-- INPUT
product_sales
| product:text | revenue:int |
|--------------|-------------|
| A            | 900         |
| B            | 100         |

-- EXPECTED
| product | revenue | cumulative_pct |
|---------|---------|----------------|
| A       | 900     | 90.0           |

-- CASE tied revenue keeps one row per product
-- INPUT
product_sales
| product:text | revenue:int |
|--------------|-------------|
| B            | 50          |
| A            | 50          |

-- EXPECTED
| product | revenue | cumulative_pct |
|---------|---------|----------------|
| A       | 50      | 50.0           |
| B       | 50      | 100.0          |
