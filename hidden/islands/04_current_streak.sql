-- HIDDEN TESTS for problem islands/04. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
activity
| user_id:int | activity_date:date |
|-------------|--------------------|

-- EXPECTED
| user_id | current_streak |
|---------|----------------|

-- CASE an older streak is longer than the current one
-- INPUT
activity
| user_id:int | activity_date:date |
|-------------|--------------------|
| 1           | 2024-01-01         |
| 1           | 2024-01-02         |
| 1           | 2024-01-03         |
| 1           | 2024-01-04         |
| 1           | 2024-01-05         |
| 1           | 2024-01-20         |
| 2           | 2024-03-01         |

-- EXPECTED
| user_id | current_streak |
|---------|----------------|
| 1       | 1              |
| 2       | 1              |

-- CASE the current streak crosses a month end
-- INPUT
activity
| user_id:int | activity_date:date |
|-------------|--------------------|
| 1           | 2024-01-10         |
| 1           | 2024-01-30         |
| 1           | 2024-01-31         |
| 1           | 2024-02-01         |

-- EXPECTED
| user_id | current_streak |
|---------|----------------|
| 1       | 3              |

-- CASE duplicates on the last day
-- INPUT
activity
| user_id:int | activity_date:date |
|-------------|--------------------|
| 1           | 2024-05-01         |
| 1           | 2024-05-02         |
| 1           | 2024-05-02         |
| 1           | 2024-05-02         |

-- EXPECTED
| user_id | current_streak |
|---------|----------------|
| 1       | 2              |
