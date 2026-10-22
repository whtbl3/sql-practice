-- HIDDEN TESTS for problem dp/03. No QUERY section: the problem's QUERY is used.

-- CASE no days
-- INPUT
promo_days
| day:date | extra_revenue_m:int |
|----------|---------------------|

-- EXPECTED
| max_extra_revenue |
|-------------------|
| 0                 |

-- CASE greedy on the biggest day is not optimal
-- INPUT
promo_days
| day        | extra_revenue_m |
|------------|-----------------|
| 2024-04-01 | 5               |
| 2024-04-02 | 6               |
| 2024-04-03 | 5               |

-- EXPECTED
| max_extra_revenue |
|-------------------|
| 10                |

-- CASE rows out of order, a single day
-- INPUT
promo_days
| day        | extra_revenue_m |
|------------|-----------------|
| 2024-04-09 | 3               |

-- EXPECTED
| max_extra_revenue |
|-------------------|
| 3                 |
