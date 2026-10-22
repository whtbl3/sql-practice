-- HIDDEN TESTS for problem graph/04. No QUERY section: the problem's QUERY is used.

-- CASE a chain without any way back
-- INPUT
transfers
| transfer_id | from_acc | to_acc | amount_vnd |
|-------------|----------|--------|------------|
| 1           | A        | B      | 1          |
| 2           | B        | C      | 1          |
| 3           | A        | C      | 1          |

-- EXPECTED
| account:text | cycle_len:int |
|--------------|---------------|

-- CASE a long cycle and a short cut back through the same account
-- INPUT
transfers
| transfer_id | from_acc | to_acc | amount_vnd |
|-------------|----------|--------|------------|
| 1           | A        | B      | 1          |
| 2           | B        | C      | 1          |
| 3           | C        | D      | 1          |
| 4           | D        | A      | 1          |
| 5           | C        | A      | 1          |

-- EXPECTED
| account | cycle_len |
|---------|-----------|
| A       | 3         |
| B       | 3         |
| C       | 3         |
| D       | 4         |
