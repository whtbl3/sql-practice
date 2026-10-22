-- HIDDEN TESTS for problem intervals/03. No QUERY section: the problem's QUERY is used.

-- CASE no incidents
-- INPUT
incidents
| incident_id:int | server:text | start_date:date | end_date:date |
|-----------------|-------------|-----------------|---------------|

-- EXPECTED
| server:text | outage_start:date | outage_end:date | days:int | incidents:int |
|-------------|-------------------|-----------------|----------|---------------|

-- CASE a one-day hole keeps outages apart; same start date twice
-- INPUT
incidents
| incident_id | server | start_date | end_date   |
|-------------|--------|------------|------------|
| 1           | s      | 2024-03-01 | 2024-03-02 |
| 2           | s      | 2024-03-04 | 2024-03-04 |
| 3           | s      | 2024-03-04 | 2024-03-09 |
| 4           | s      | 2024-03-10 | 2024-03-10 |

-- EXPECTED
| server | outage_start | outage_end | days | incidents |
|--------|--------------|------------|------|-----------|
| s      | 2024-03-01   | 2024-03-02 | 2    | 1         |
| s      | 2024-03-04   | 2024-03-10 | 7    | 3         |

-- CASE a long incident hides two short ones that do not touch each other
-- INPUT
incidents
| incident_id | server | start_date | end_date   |
|-------------|--------|------------|------------|
| 1           | s      | 2024-05-01 | 2024-05-30 |
| 2           | s      | 2024-05-02 | 2024-05-03 |
| 3           | s      | 2024-05-20 | 2024-05-21 |
| 4           | s      | 2024-05-31 | 2024-06-01 |

-- EXPECTED
| server | outage_start | outage_end | days | incidents |
|--------|--------------|------------|------|-----------|
| s      | 2024-05-01   | 2024-06-01 | 32   | 4         |
