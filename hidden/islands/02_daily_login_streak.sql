-- HIDDEN TESTS for problem islands/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
logins
| user_id:int | login_date:date |
|-------------|-----------------|

-- EXPECTED
| user_id | longest_streak |
|---------|----------------|

-- CASE year boundary, leap day present, and leap day missing
-- INPUT
logins
| user_id:int | login_date:date |
|-------------|-----------------|
| 1           | 2023-12-30      |
| 1           | 2023-12-31      |
| 1           | 2024-01-01      |
| 2           | 2024-02-28      |
| 2           | 2024-02-29      |
| 2           | 2024-03-01      |
| 3           | 2024-02-28      |
| 3           | 2024-03-01      |

-- EXPECTED
| user_id | longest_streak |
|---------|----------------|
| 1       | 3              |
| 2       | 3              |
| 3       | 1              |

-- CASE many logins on the same day
-- INPUT
logins
| user_id:int | login_date:date |
|-------------|-----------------|
| 1           | 2024-05-01      |
| 1           | 2024-05-01      |
| 1           | 2024-05-01      |
| 1           | 2024-05-01      |
| 1           | 2024-05-01      |
| 1           | 2024-05-02      |

-- EXPECTED
| user_id | longest_streak |
|---------|----------------|
| 1       | 2              |

-- CASE longest streak is neither the first nor the last
-- INPUT
logins
| user_id:int | login_date:date |
|-------------|-----------------|
| 1           | 2024-06-01      |
| 1           | 2024-06-02      |
| 1           | 2024-06-04      |
| 1           | 2024-06-05      |
| 1           | 2024-06-06      |
| 1           | 2024-06-07      |
| 1           | 2024-06-09      |
| 2           | 2024-06-01      |

-- EXPECTED
| user_id | longest_streak |
|---------|----------------|
| 1       | 4              |
| 2       | 1              |
