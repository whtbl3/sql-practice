-- HIDDEN TESTS for problem cohort/04. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|

-- EXPECTED
| cohort_month | customers | repeaters | repeat_rate_pct |
|--------------|-----------|-----------|-----------------|

-- CASE nobody orders twice
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-03-01      |
| 2            | 2               | 2024-03-02      |

-- EXPECTED
| cohort_month | customers | repeaters | repeat_rate_pct |
|--------------|-----------|-----------|-----------------|
| 2024-03      | 2         | 0         | 0.0             |

-- CASE same-day, exactly 30 days, and 31 days
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-04-01      |
| 2            | 1               | 2024-04-01      |
| 3            | 2               | 2024-04-01      |
| 4            | 2               | 2024-05-01      |
| 5            | 3               | 2024-04-01      |
| 6            | 3               | 2024-05-02      |

-- EXPECTED
| cohort_month | customers | repeaters | repeat_rate_pct |
|--------------|-----------|-----------|-----------------|
| 2024-04      | 3         | 2         | 66.7            |

-- CASE second order falls in the next month and next year
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2023-12-20      |
| 2            | 1               | 2024-01-10      |

-- EXPECTED
| cohort_month | customers | repeaters | repeat_rate_pct |
|--------------|-----------|-----------|-----------------|
| 2023-12      | 1         | 1         | 100.0           |

-- CASE only the second order matters, not later ones
-- INPUT
orders
| order_id:int | customer_id:int | order_date:date |
|--------------|-----------------|-----------------|
| 1            | 1               | 2024-01-01      |
| 2            | 1               | 2024-03-01      |
| 3            | 1               | 2024-03-05      |

-- EXPECTED
| cohort_month | customers | repeaters | repeat_rate_pct |
|--------------|-----------|-----------|-----------------|
| 2024-01      | 1         | 0         | 0.0             |
