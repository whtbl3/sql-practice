-- HIDDEN TESTS for problem recursive/01. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
units
| unit_id:int | name:text | parent_id:int | budget:int |
|-------------|-----------|---------------|------------|

-- EXPECTED
| name | total_budget |
|------|--------------|

-- CASE single unit
-- INPUT
units
| unit_id:int | name:text | parent_id:int | budget:int |
|-------------|-----------|---------------|------------|
| 1           | Solo      | NULL          | 7          |

-- EXPECTED
| name | total_budget |
|------|--------------|
| Solo | 7            |

-- CASE deep chain
-- INPUT
units
| unit_id:int | name:text | parent_id:int | budget:int |
|-------------|-----------|---------------|------------|
| 1           | A         | NULL          | 1          |
| 2           | B         | 1             | 2          |
| 3           | C         | 2             | 4          |
| 4           | D         | 3             | 8          |

-- EXPECTED
| name | total_budget |
|------|--------------|
| A    | 15           |
| B    | 14           |
| C    | 12           |
| D    | 8            |

-- CASE two separate trees
-- INPUT
units
| unit_id:int | name:text | parent_id:int | budget:int |
|-------------|-----------|---------------|------------|
| 1           | A         | NULL          | 5          |
| 2           | B         | 1             | 5          |
| 3           | C         | NULL          | 100        |

-- EXPECTED
| name | total_budget |
|------|--------------|
| A    | 10           |
| B    | 5            |
| C    | 100          |
