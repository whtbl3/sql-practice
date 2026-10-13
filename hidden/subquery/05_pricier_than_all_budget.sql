-- HIDDEN TESTS for problem subquery/05. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
products
| name:text | category:text | price:int |
|-----------|---------------|-----------|

-- EXPECTED
| name | price |
|------|-------|

-- CASE a Budget product with a NULL price
-- INPUT
products
| name:text | category:text | price:int |
|-----------|---------------|-----------|
| B1        | Budget        | NULL      |
| B2        | Budget        | 10        |
| P1        | Pro           | 20        |
| P2        | Pro           | 5         |

-- EXPECTED
| name | price |
|------|-------|
| P1   | 20    |

-- CASE no Budget products at all
-- INPUT
products
| name:text | category:text | price:int |
|-----------|---------------|-----------|
| P1        | Pro           | 5         |
| P2        | Pro           | NULL      |

-- EXPECTED
| name | price |
|------|-------|
| P1   | 5     |
