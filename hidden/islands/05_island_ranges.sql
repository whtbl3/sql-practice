-- HIDDEN TESTS for problem islands/05. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
shifts
| employee:text | work_date:date |
|---------------|----------------|

-- EXPECTED
| employee | start_date | end_date | days |
|----------|------------|----------|------|

-- CASE one block across a leap day
-- INPUT
shifts
| employee:text | work_date:date |
|---------------|----------------|
| Ann           | 2024-02-28     |
| Ann           | 2024-02-29     |
| Ann           | 2024-03-01     |

-- EXPECTED
| employee | start_date | end_date   | days |
|----------|------------|------------|------|
| Ann      | 2024-02-28 | 2024-03-01 | 3    |

-- CASE unsorted insert order, several blocks
-- INPUT
shifts
| employee:text | work_date:date |
|---------------|----------------|
| Ann           | 2024-05-10     |
| Ann           | 2024-05-01     |
| Ann           | 2024-05-02     |
| Ann           | 2024-05-12     |
| Ann           | 2024-05-11     |

-- EXPECTED
| employee | start_date | end_date   | days |
|----------|------------|------------|------|
| Ann      | 2024-05-01 | 2024-05-02 | 2    |
| Ann      | 2024-05-10 | 2024-05-12 | 3    |

-- CASE blocks are never merged across employees
-- INPUT
shifts
| employee:text | work_date:date |
|---------------|----------------|
| Ann           | 2024-05-01     |
| Bob           | 2024-05-02     |

-- EXPECTED
| employee | start_date | end_date   | days |
|----------|------------|------------|------|
| Ann      | 2024-05-01 | 2024-05-01 | 1    |
| Bob      | 2024-05-02 | 2024-05-02 | 1    |
