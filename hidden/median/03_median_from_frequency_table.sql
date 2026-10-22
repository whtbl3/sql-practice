-- HIDDEN TESTS for problem median/03. No QUERY section: the problem's QUERY is used.

-- CASE every count is 0
-- INPUT
basket_sizes
| store | items | orders |
|-------|-------|--------|
| A     | 1     | 0      |
| A     | 2     | 0      |

-- EXPECTED
| store:text | total_orders:int | median_items:numeric |
|------------|------------------|----------------------|

-- CASE the two middle positions fall on both sides of a zero-count value
-- INPUT
basket_sizes
| store | items | orders |
|-------|-------|--------|
| A     | 1     | 3      |
| A     | 2     | 0      |
| A     | 7     | 3      |

-- EXPECTED
| store | total_orders | median_items |
|-------|--------------|--------------|
| A     | 6            | 4.0          |

-- CASE a single order, and big counts where expanding would be wasteful
-- INPUT
basket_sizes
| store | items | orders  |
|-------|-------|---------|
| A     | 9     | 1       |
| B     | 1     | 1000000 |
| B     | 2     | 999999  |
| B     | 3     | 2       |

-- EXPECTED
| store | total_orders | median_items |
|-------|--------------|--------------|
| A     | 1            | 9.0          |
| B     | 2000001      | 2.0          |
