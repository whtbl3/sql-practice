-- HIDDEN TESTS for problem antijoin/04. No QUERY section: the problem's QUERY is used.

-- CASE no sales at all: every store-month
-- INPUT
stores
| store_id | store_name |
|----------|------------|
| 5        | A          |

sales
| sale_id:int | store_id:int | sale_date:date | amount_vnd:int |
|-------------|--------------|----------------|----------------|

-- EXPECTED
| store_id | store_name | month   |
|----------|------------|---------|
| 5        | A          | 2024-01 |
| 5        | A          | 2024-02 |
| 5        | A          | 2024-03 |

-- CASE every month covered, last day of February in a leap year
-- INPUT
stores
| store_id | store_name |
|----------|------------|
| 1        | A          |

sales
| sale_id | store_id | sale_date  | amount_vnd |
|---------|----------|------------|------------|
| 1       | 1        | 2024-01-31 | 1          |
| 2       | 1        | 2024-02-29 | 1          |
| 3       | 1        | 2024-03-01 | 1          |

-- EXPECTED
| store_id:int | store_name:text | month:text |
|--------------|-----------------|------------|
