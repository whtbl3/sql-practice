-- HIDDEN TESTS for problem rfm/05. No QUERY section: the problem's QUERY is used.

-- CASE no customers
-- INPUT
customer_metrics
| customer_id:int | recency_days:int | frequency:int | monetary_vnd:int |
|-----------------|------------------|---------------|------------------|

-- EXPECTED
| customer_id:int | r_score:int | f_score:int | m_score:int |
|-----------------|-------------|-------------|-------------|

-- CASE one customer gets 5 everywhere
-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 40           | 1         | 100000       |

-- EXPECTED
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 5       | 5       | 5       |

-- CASE everybody tied: NTILE would give 1..4, the rule gives 5 to all
-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 10           | 2         | 500000       |
| 2           | 10           | 2         | 500000       |
| 3           | 10           | 2         | 500000       |
| 4           | 10           | 2         | 500000       |

-- EXPECTED
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 5       | 5       | 5       |
| 2           | 5       | 5       | 5       |
| 3           | 5       | 5       | 5       |
| 4           | 5       | 5       | 5       |

-- CASE three distinct values: scores 2, 4, 5 (ceiling, not rounding)
-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 3            | 1         | 100000       |
| 2           | 20           | 4         | 900000       |
| 3           | 100          | 9         | 5000000      |

-- EXPECTED
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 5       | 2       | 2       |
| 2           | 4       | 4       | 4       |
| 3           | 2       | 5       | 5       |

-- CASE a big tie at the bottom pushes the score of the whole tie up
-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 7            | 1         | 200000       |
| 2           | 7            | 1         | 200000       |
| 3           | 7            | 1         | 200000       |
| 4           | 7            | 1         | 200000       |
| 5           | 7            | 1         | 200000       |
| 6           | 7            | 1         | 200000       |
| 7           | 1            | 2         | 600000       |
| 8           | 1            | 3         | 900000       |

-- EXPECTED
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 4       | 4       | 4       |
| 2           | 4       | 4       | 4       |
| 3           | 4       | 4       | 4       |
| 4           | 4       | 4       | 4       |
| 5           | 4       | 4       | 4       |
| 6           | 4       | 4       | 4       |
| 7           | 5       | 5       | 5       |
| 8           | 5       | 5       | 5       |
