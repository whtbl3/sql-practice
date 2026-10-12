-- HIDDEN TESTS for problem agg/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
deliveries
| delivery_id:int | supplier:text | expected_date:date | actual_date:date |
|-----------------|---------------|--------------------|------------------|

-- EXPECTED
| supplier | deliveries | avg_late_days | on_time_pct |
|----------|------------|---------------|-------------|

-- CASE exactly 3 deliveries qualifies
-- INPUT
deliveries
| delivery_id:int | supplier:text | expected_date:date | actual_date:date |
|-----------------|---------------|--------------------|------------------|
| 1               | X             | 2024-01-01         | 2024-01-02       |
| 2               | X             | 2024-01-01         | 2024-01-02       |
| 3               | X             | 2024-01-01         | 2024-01-02       |

-- EXPECTED
| supplier | deliveries | avg_late_days | on_time_pct |
|----------|------------|---------------|-------------|
| X        | 3          | 1.0           | 0.0         |

-- CASE early and late cancel out to an average of 0
-- INPUT
deliveries
| delivery_id:int | supplier:text | expected_date:date | actual_date:date |
|-----------------|---------------|--------------------|------------------|
| 1               | X             | 2024-01-05         | 2024-01-07       |
| 2               | X             | 2024-01-05         | 2024-01-03       |
| 3               | X             | 2024-01-05         | 2024-01-05       |

-- EXPECTED
| supplier | deliveries | avg_late_days | on_time_pct |
|----------|------------|---------------|-------------|

-- CASE tie on lateness is sorted by supplier
-- INPUT
deliveries
| delivery_id:int | supplier:text | expected_date:date | actual_date:date |
|-----------------|---------------|--------------------|------------------|
| 1               | B             | 2024-01-01         | 2024-01-02       |
| 1               | A             | 2024-01-01         | 2024-01-02       |
| 2               | B             | 2024-01-01         | 2024-01-02       |
| 2               | A             | 2024-01-01         | 2024-01-02       |
| 3               | B             | 2024-01-01         | 2024-01-02       |
| 3               | A             | 2024-01-01         | 2024-01-02       |

-- EXPECTED
| supplier | deliveries | avg_late_days | on_time_pct |
|----------|------------|---------------|-------------|
| A        | 3          | 1.0           | 0.0         |
| B        | 3          | 1.0           | 0.0         |
