-- HIDDEN TESTS for problem window/09. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
price_history
| product:text | changed_on:date | price:int |
|--------------|-----------------|-----------|

-- EXPECTED
| product | changed_on | old_price | new_price |
|---------|------------|-----------|-----------|

-- CASE price never changes
-- INPUT
price_history
| product:text | changed_on:date | price:int |
|--------------|-----------------|-----------|
| A            | 2024-01-01      | 7         |
| A            | 2024-01-02      | 7         |
| A            | 2024-01-03      | 7         |

-- EXPECTED
| product | changed_on | old_price | new_price |
|---------|------------|-----------|-----------|
| A       | 2024-01-01 | NULL      | 7         |

-- CASE a NULL price in the middle is a change both ways
-- INPUT
price_history
| product:text | changed_on:date | price:int |
|--------------|-----------------|-----------|
| A            | 2024-01-01      | 10        |
| A            | 2024-01-02      | NULL      |
| A            | 2024-01-03      | 10        |

-- EXPECTED
| product | changed_on | old_price | new_price |
|---------|------------|-----------|-----------|
| A       | 2024-01-01 | NULL      | 10        |
| A       | 2024-01-02 | 10        | NULL      |
| A       | 2024-01-03 | NULL      | 10        |
