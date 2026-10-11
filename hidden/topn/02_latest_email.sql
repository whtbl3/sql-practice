-- HIDDEN TESTS for problem topn/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
customer_updates
| update_id:int | customer_id:int | email:text | updated_at:date |
|---------------|-----------------|------------|-----------------|

-- EXPECTED
| customer_id | email |
|-------------|-------|

-- CASE one record per customer
-- INPUT
customer_updates
| update_id:int | customer_id:int | email:text | updated_at:date |
|---------------|-----------------|------------|-----------------|
| 1             | 1               | only@x.com | 2024-01-01      |

-- EXPECTED
| customer_id | email      |
|-------------|------------|
| 1           | only@x.com |

-- CASE latest record is out of order in the table
-- INPUT
customer_updates
| update_id:int | customer_id:int | email:text | updated_at:date |
|---------------|-----------------|------------|-----------------|
| 1             | 1               | new@x.com  | 2024-05-01      |
| 2             | 1               | old@x.com  | 2024-01-01      |
| 3             | 2               | m2@x.com   | 2024-03-01      |
| 4             | 2               | m3@x.com   | 2024-04-01      |
| 5             | 2               | m1@x.com   | 2024-02-01      |

-- EXPECTED
| customer_id | email     |
|-------------|-----------|
| 1           | new@x.com |
| 2           | m3@x.com  |

-- CASE non-contiguous customer_id, sorted numerically
-- INPUT
customer_updates
| update_id:int | customer_id:int | email:text | updated_at:date |
|---------------|-----------------|------------|-----------------|
| 1             | 10              | e10@x.com  | 2024-01-01      |
| 2             | 5               | e5@x.com   | 2024-01-01      |
| 3             | 7               | e7@x.com   | 2024-01-01      |

-- EXPECTED
| customer_id | email     |
|-------------|-----------|
| 5           | e5@x.com  |
| 7           | e7@x.com  |
| 10          | e10@x.com |
