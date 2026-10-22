-- HIDDEN TESTS for problem rfm/03. No QUERY section: the problem's QUERY is used.

-- CASE no customers
-- INPUT
customer_metrics
| customer_id:int | recency_days:int | frequency:int | monetary_vnd:int |
|-----------------|------------------|---------------|------------------|

rfm_thresholds
| metric:text | score:int | min_value:int | max_value:int |
|-------------|-----------|---------------|---------------|
| R           | 1         | 0             | NULL          |

-- EXPECTED
| customer_id:int | r_score:int | f_score:int | m_score:int | rfm_code:text |
|-----------------|-------------|-------------|-------------|---------------|

-- CASE every boundary value of a 3-level table
-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 0            | 1         | 0            |
| 2           | 14           | 2         | 999999       |
| 3           | 15           | 3         | 1000000      |
| 4           | 90           | 5         | 4999999      |
| 5           | 91           | 6         | 5000000      |

rfm_thresholds
| metric | score | min_value | max_value |
|--------|-------|-----------|-----------|
| R      | 3     | 0         | 14        |
| R      | 2     | 15        | 90        |
| R      | 1     | 91        | NULL      |
| F      | 1     | 1         | 2         |
| F      | 2     | 3         | 5         |
| F      | 3     | 6         | NULL      |
| M      | 1     | 0         | 999999    |
| M      | 2     | 1000000   | 4999999   |
| M      | 3     | 5000000   | NULL      |

-- EXPECTED
| customer_id | r_score | f_score | m_score | rfm_code |
|-------------|---------|---------|---------|----------|
| 1           | 3       | 1       | 1       | 311      |
| 2           | 3       | 1       | 1       | 311      |
| 3           | 2       | 2       | 2       | 222      |
| 4           | 2       | 2       | 2       | 222      |
| 5           | 1       | 3       | 3       | 133      |

-- CASE a metric with no rows in the thresholds table scores 0 for everybody
-- INPUT
customer_metrics
| customer_id | recency_days | frequency | monetary_vnd |
|-------------|--------------|-----------|--------------|
| 1           | 5            | 3         | 300000       |
| 2           | NULL         | 0         | 0            |

rfm_thresholds
| metric | score | min_value | max_value |
|--------|-------|-----------|-----------|
| R      | 2     | 0         | 10        |
| R      | 1     | 11        | NULL      |
| M      | 1     | 0         | NULL      |

-- EXPECTED
| customer_id | r_score | f_score | m_score | rfm_code |
|-------------|---------|---------|---------|----------|
| 1           | 2       | 0       | 1       | 201      |
| 2           | 0       | 0       | 1       | 001      |
