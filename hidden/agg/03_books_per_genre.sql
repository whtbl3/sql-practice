-- HIDDEN TESTS for problem agg/03. No QUERY section: the problem's QUERY is used.

-- CASE empty tables
-- INPUT
genres
| genre_id:int | name:text |
|--------------|-----------|

books
| book_id:int | genre_id:int | price:int |
|-------------|--------------|-----------|

-- EXPECTED
| genre | book_count | avg_price | price_range |
|-------|------------|-----------|-------------|

-- CASE genre with no books
-- INPUT
genres
| genre_id:int | name:text |
|--------------|-----------|
| 1            | Solo      |

books
| book_id:int | genre_id:int | price:int |
|-------------|--------------|-----------|

-- EXPECTED
| genre | book_count | avg_price | price_range |
|-------|------------|-----------|-------------|
| Solo  | 0          | 0.0       | 0           |

-- CASE NULL price counts as a book but not in the average
-- INPUT
genres
| genre_id:int | name:text |
|--------------|-----------|
| 1            | G         |

books
| book_id:int | genre_id:int | price:int |
|-------------|--------------|-----------|
| 1           | 1            | NULL      |
| 2           | 1            | 10        |

-- EXPECTED
| genre | book_count | avg_price | price_range |
|-------|------------|-----------|-------------|
| G     | 2          | 10.0      | 0           |
