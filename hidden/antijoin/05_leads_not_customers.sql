-- HIDDEN TESTS for problem antijoin/05. No QUERY section: the problem's QUERY is used.

-- CASE no customers yet: every lead, duplicates included
-- INPUT
leads
| lead_id | full_name | phone:text |
|---------|-----------|------------|
| 1       | A         | 0901       |
| 2       | A         | 0901       |

customers
| customer_id:int | full_name:text | phone:text |
|-----------------|----------------|------------|

-- EXPECTED
| lead_id | full_name | phone |
|---------|-----------|-------|
| 1       | A         | 0901  |
| 2       | A         | 0901  |

-- CASE NULL phones on both sides
-- INPUT
leads
| lead_id | full_name | phone:text |
|---------|-----------|------------|
| 1       | A         | NULL       |
| 2       | B         | NULL       |

customers
| customer_id | full_name | phone:text |
|-------------|-----------|------------|
| 1           | C         | NULL       |

-- EXPECTED
| lead_id | full_name | phone |
|---------|-----------|-------|
| 1       | A         | NULL  |
| 2       | B         | NULL  |
