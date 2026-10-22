-- HIDDEN TESTS for problem cohort/07. No QUERY section: the problem's QUERY is used.

-- CASE everyone in one segment
-- INPUT
customer_rfm
| customer_id:int | r_score:int | f_score:int | m_score:int | monetary:int |
|-----------------|-------------|-------------|-------------|--------------|
| 1               | 1           | 1           | 1           | 30           |
| 2               | 2           | 1           | 1           | 70           |

-- EXPECTED
| segment   | customers | revenue | revenue_pct |
|-----------|-----------|---------|-------------|
| Champions | 0         | 0       | 0.0         |
| Loyal     | 0         | 0       | 0.0         |
| New       | 0         | 0       | 0.0         |
| At Risk   | 0         | 0       | 0.0         |
| Lost      | 2         | 100     | 100.0       |

-- CASE Champions must be checked before Loyal
-- INPUT
customer_rfm
| customer_id:int | r_score:int | f_score:int | m_score:int | monetary:int |
|-----------------|-------------|-------------|-------------|--------------|
| 1               | 3           | 3           | 1           | 200          |
| 2               | 3           | 2           | 3           | 300          |
| 3               | 1           | 3           | 3           | 500          |

-- EXPECTED
| segment   | customers | revenue | revenue_pct |
|-----------|-----------|---------|-------------|
| Champions | 1         | 200     | 20.0        |
| Loyal     | 1         | 300     | 30.0        |
| New       | 0         | 0       | 0.0         |
| At Risk   | 1         | 500     | 50.0        |
| Lost      | 0         | 0       | 0.0         |
