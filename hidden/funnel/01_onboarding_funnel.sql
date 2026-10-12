-- HIDDEN TESTS for problem funnel/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
events
| user_id:int | step:text |
|-------------|-----------|

-- EXPECTED
| signup | verify | profile | purchase | purchase_rate |
|--------|--------|---------|----------|---------------|
| 0      | 0      | 0       | 0        | NULL          |

-- CASE repeated events count a user once
-- INPUT
events
| user_id:int | step:text |
|-------------|-----------|
| 1           | signup    |
| 1           | signup    |
| 1           | verify    |
| 1           | verify    |
| 2           | signup    |

-- EXPECTED
| signup | verify | profile | purchase | purchase_rate |
|--------|--------|---------|----------|---------------|
| 2      | 1      | 0       | 0        | 0.0           |

-- CASE purchase without earlier steps does not count
-- INPUT
events
| user_id:int | step:text |
|-------------|-----------|
| 1           | signup    |
| 1           | purchase  |
| 2           | purchase  |

-- EXPECTED
| signup | verify | profile | purchase | purchase_rate |
|--------|--------|---------|----------|---------------|
| 1      | 0      | 0       | 0        | 0.0           |

-- CASE everyone converts
-- INPUT
events
| user_id:int | step:text |
|-------------|-----------|
| 1           | signup    |
| 1           | verify    |
| 1           | profile   |
| 1           | purchase  |
| 2           | signup    |
| 2           | verify    |
| 2           | profile   |
| 2           | purchase  |

-- EXPECTED
| signup | verify | profile | purchase | purchase_rate |
|--------|--------|---------|----------|---------------|
| 2      | 2      | 2       | 2        | 100.0         |
