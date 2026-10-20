-- Problem misc/02: Product share within its category  [Medium]
-- Pattern: GROUP BY + two-level window: SUM(SUM()) OVER
-- Variant: function drill
--
-- Task: For each product compute total_sold and pct_of_category (percentage of the total of its
--   category, rounded to 2 decimals). Sort by category, then product_name.
-- Learn: grinding/sql-analytics-patterns.md, mục 5.1

-- INPUT
products
| product_id | product_name | category |
|------------|--------------|----------|
| 1          | Milk         | Beverage |
| 2          | Water        | Beverage |
| 3          | Chips        | Snack    |

transactions
| transaction_id | product_id | amount |
|----------------|------------|--------|
| 101            | 1          | 60     |
| 102            | 1          | 55     |
| 103            | 2          | 110    |
| 104            | 3          | 40     |

-- EXPECTED
| category | product_name | total_sold | pct_of_category |
|----------|--------------|------------|-----------------|
| Beverage | Milk         | 115        | 51.11           |
| Beverage | Water        | 110        | 48.89           |
| Snack    | Chips        | 40         | 100.00          |

-- QUERY
-- write your query here
