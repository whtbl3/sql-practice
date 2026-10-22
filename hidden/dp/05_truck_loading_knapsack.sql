-- HIDDEN TESTS for problem dp/05. No QUERY section: the problem's QUERY is used.

-- CASE nothing fits
-- INPUT
items
| item_id | name  | weight_kg | value |
|---------|-------|-----------|-------|
| 1       | Canoe | 30        | 500   |

-- EXPECTED
| best_value | total_weight | items |
|------------|--------------|-------|
| 0          | 0            | NULL  |

-- CASE taking the best value per kg first is not optimal
-- INPUT
items
| item_id | name | weight_kg | value |
|---------|------|-----------|-------|
| 1       | A    | 6         | 66    |
| 2       | B    | 5         | 50    |
| 3       | C    | 5         | 50    |

-- EXPECTED
| best_value | total_weight | items |
|------------|--------------|-------|
| 100        | 10           | B, C  |

-- CASE same best value: the lighter load wins
-- INPUT
items
| item_id | name | weight_kg | value |
|---------|------|-----------|-------|
| 1       | P    | 10        | 50    |
| 2       | Q    | 3         | 50    |
| 3       | R    | 9         | 10    |

-- EXPECTED
| best_value | total_weight | items |
|------------|--------------|-------|
| 50         | 3            | Q     |
