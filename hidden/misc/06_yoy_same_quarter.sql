-- HIDDEN TESTS for problem misc/06. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
quarterly_sales
| yr:int | qtr:int | revenue:int |
|--------|---------|-------------|

-- EXPECTED
| yr | qtr | revenue | yoy_pct |
|----|-----|---------|---------|

-- CASE a missing year is not skipped
-- INPUT
quarterly_sales
| yr:int | qtr:int | revenue:int |
|--------|---------|-------------|
| 2021   | 1       | 100         |
| 2023   | 1       | 150         |

-- EXPECTED
| yr   | qtr | revenue | yoy_pct |
|------|-----|---------|---------|
| 2021 | 1   | 100     | NULL    |
| 2023 | 1   | 150     | NULL    |

-- CASE previous quarter exists only for some quarters
-- INPUT
quarterly_sales
| yr:int | qtr:int | revenue:int |
|--------|---------|-------------|
| 2023   | 1       | 50          |
| 2024   | 1       | 100         |
| 2024   | 2       | 10          |

-- EXPECTED
| yr   | qtr | revenue | yoy_pct |
|------|-----|---------|---------|
| 2023 | 1   | 50      | NULL    |
| 2024 | 1   | 100     | 100.0   |
| 2024 | 2   | 10      | NULL    |
