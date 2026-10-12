-- HIDDEN TESTS for problem funnel/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
page_views
| user_id:int | seq:int | page:text |
|-------------|---------|-----------|

-- EXPECTED
| path | occurrences |
|------|-------------|

-- CASE users with fewer than 3 views are ignored
-- INPUT
page_views
| user_id:int | seq:int | page:text |
|-------------|---------|-----------|
| 1           | 1       | a         |
| 1           | 2       | b         |
| 2           | 1       | c         |

-- EXPECTED
| path | occurrences |
|------|-------------|

-- CASE tie goes to the smaller path
-- INPUT
page_views
| user_id:int | seq:int | page:text |
|-------------|---------|-----------|
| 1           | 1       | x         |
| 1           | 2       | y         |
| 1           | 3       | z         |
| 2           | 1       | x         |
| 2           | 2       | y         |
| 2           | 3       | w         |

-- EXPECTED
| path      | occurrences |
|-----------|-------------|
| x > y > w | 1           |

-- CASE seq order not insertion order
-- INPUT
page_views
| user_id:int | seq:int | page:text |
|-------------|---------|-----------|
| 1           | 3       | c         |
| 1           | 1       | a         |
| 1           | 2       | b         |

-- EXPECTED
| path      | occurrences |
|-----------|-------------|
| a > b > c | 1           |
