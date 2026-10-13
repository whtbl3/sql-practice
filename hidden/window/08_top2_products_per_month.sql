-- HIDDEN TESTS for problem window/08. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
sales
| sale_date:date | product:text | qty:int |
|----------------|--------------|---------|

-- EXPECTED
| month | product | total_qty | rank_in_month |
|-------|---------|-----------|---------------|

-- CASE one product in a month
-- INPUT
sales
| sale_date:date | product:text | qty:int |
|----------------|--------------|---------|
| 2024-03-01     | X            | 1       |

-- EXPECTED
| month   | product | total_qty | rank_in_month |
|---------|---------|-----------|---------------|
| 2024-03 | X       | 1         | 1             |

-- CASE everything tied
-- INPUT
sales
| sale_date:date | product:text | qty:int |
|----------------|--------------|---------|
| 2024-05-01     | C            | 2       |
| 2024-05-02     | A            | 2       |
| 2024-05-03     | B            | 2       |

-- EXPECTED
| month   | product | total_qty | rank_in_month |
|---------|---------|-----------|---------------|
| 2024-05 | A       | 2         | 1             |
| 2024-05 | B       | 2         | 1             |
| 2024-05 | C       | 2         | 1             |
