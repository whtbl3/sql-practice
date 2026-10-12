-- HIDDEN TESTS for problem agg/05. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
products
| name:text | category:text | price:int |
|-----------|---------------|-----------|

-- EXPECTED
| name | category | price | category_avg |
|------|----------|-------|--------------|

-- CASE all prices equal
-- INPUT
products
| name:text | category:text | price:int |
|-----------|---------------|-----------|
| A         | x             | 5         |
| B         | x             | 5         |

-- EXPECTED
| name | category | price | category_avg |
|------|----------|-------|--------------|

-- CASE single product in a category
-- INPUT
products
| name:text | category:text | price:int |
|-----------|---------------|-----------|
| A         | x             | 5         |
| B         | y             | 1         |
| C         | y             | 9         |

-- EXPECTED
| name | category | price | category_avg |
|------|----------|-------|--------------|
| C    | y        | 9     | 5.0          |

-- CASE NULL prices are ignored
-- INPUT
products
| name:text | category:text | price:int |
|-----------|---------------|-----------|
| A         | x             | NULL      |
| B         | x             | 10        |
| C         | x             | 20        |

-- EXPECTED
| name | category | price | category_avg |
|------|----------|-------|--------------|
| C    | x        | 20    | 15.0         |
