-- HIDDEN TESTS for problem cohort/03. No QUERY section: the problem's QUERY is used.

-- CASE empty tables
-- INPUT
users
| user_id:int | signup_date:date |
|-------------|------------------|

events
| user_id:int | event_date:date |
|-------------|-----------------|

-- EXPECTED
| cohort_month | month_offset | active_users | retention_pct |
|--------------|--------------|--------------|---------------|

-- CASE users who never had an event
-- INPUT
users
| user_id:int | signup_date:date |
|-------------|------------------|
| 1           | 2024-01-01       |
| 2           | 2024-01-02       |
| 3           | 2024-01-03       |

events
| user_id:int | event_date:date |
|-------------|-----------------|

-- EXPECTED
| cohort_month | month_offset | active_users | retention_pct |
|--------------|--------------|--------------|---------------|

-- CASE several events in the signup month count once
-- INPUT
users
| user_id:int | signup_date:date |
|-------------|------------------|
| 1           | 2024-03-01       |

events
| user_id:int | event_date:date |
|-------------|-----------------|
| 1           | 2024-03-02      |
| 1           | 2024-03-09      |
| 1           | 2024-03-20      |

-- EXPECTED
| cohort_month | month_offset | active_users | retention_pct |
|--------------|--------------|--------------|---------------|
| 2024-03      | 0            | 1            | 100.0         |

-- CASE events before signup ignored, inactive user in cohort size
-- INPUT
users
| user_id:int | signup_date:date |
|-------------|------------------|
| 1           | 2024-05-01       |
| 2           | 2024-05-02       |

events
| user_id:int | event_date:date |
|-------------|-----------------|
| 1           | 2024-05-03      |
| 1           | 2024-06-01      |
| 2           | 2024-04-30      |

-- EXPECTED
| cohort_month | month_offset | active_users | retention_pct |
|--------------|--------------|--------------|---------------|
| 2024-05      | 0            | 1            | 50.0          |
| 2024-05      | 1            | 1            | 50.0          |

-- CASE cohort across the year boundary
-- INPUT
users
| user_id:int | signup_date:date |
|-------------|------------------|
| 1           | 2023-12-15       |

events
| user_id:int | event_date:date |
|-------------|-----------------|
| 1           | 2024-01-10      |
| 1           | 2024-02-10      |

-- EXPECTED
| cohort_month | month_offset | active_users | retention_pct |
|--------------|--------------|--------------|---------------|
| 2023-12      | 1            | 1            | 100.0         |
| 2023-12      | 2            | 1            | 100.0         |
