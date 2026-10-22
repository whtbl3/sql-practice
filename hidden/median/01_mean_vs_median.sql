-- HIDDEN TESTS for problem median/01. No QUERY section: the problem's QUERY is used.

-- CASE only NULL prices
-- INPUT
products
| product_id:int | category:text | price_vnd:int |
|----------------|---------------|---------------|
| 1              | Cables        | NULL          |

-- EXPECTED
| category:text | products:int | avg_price:numeric | median_price:numeric | median_disc:int | shape:text |
|---------------|--------------|-------------------|----------------------|-----------------|------------|

-- CASE one product, and exactly 1.2 x median is still balanced
-- INPUT
products
| product_id | category | price_vnd |
|------------|----------|-----------|
| 1          | A        | 999       |
| 2          | B        | 100       |
| 3          | B        | 100       |
| 4          | B        | 160       |

-- EXPECTED
| category | products | avg_price | median_price | median_disc | shape    |
|----------|----------|-----------|--------------|-------------|----------|
| A        | 1        | 999       | 999          | 999         | balanced |
| B        | 3        | 120       | 100          | 100         | balanced |

-- CASE rows in random order, even count where CONT and DISC differ
-- INPUT
products
| product_id | category | price_vnd |
|------------|----------|-----------|
| 1          | Speakers | 900000    |
| 2          | Speakers | 100000    |
| 3          | Speakers | 500000    |
| 4          | Speakers | 200000    |
| 5          | Speakers | 150000    |
| 6          | Speakers | 950000    |

-- EXPECTED
| category | products | avg_price | median_price | median_disc | shape        |
|----------|----------|-----------|--------------|-------------|--------------|
| Speakers | 6        | 466667    | 350000       | 200000      | right-skewed |
