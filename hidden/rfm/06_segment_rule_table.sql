-- HIDDEN TESTS for problem rfm/06. No QUERY section: the problem's QUERY is used.

-- CASE empty rules table: everybody is unclassified
-- INPUT
customer_rfm
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 5       | 5       | 5       |
| 2           | 1       | 1       | 1       |

segment_rules
| priority:int | segment:text | pattern:text |
|--------------|--------------|--------------|

-- EXPECTED
| customer_id | rfm_code | segment      |
|-------------|----------|--------------|
| 1           | 555      | Unclassified |
| 2           | 111      | Unclassified |

-- CASE no customers
-- INPUT
customer_rfm
| customer_id:int | r_score:int | f_score:int | m_score:int |
|-----------------|-------------|-------------|-------------|

segment_rules
| priority | segment | pattern |
|----------|---------|---------|
| 1        | VIP     | ^555$   |

-- EXPECTED
| customer_id:int | rfm_code:text | segment:text |
|-----------------|---------------|--------------|

-- CASE priority decides, not row order or segment name
-- INPUT
customer_rfm
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 1           | 5       | 5       | 5       |
| 2           | 3       | 3       | 3       |
| 3           | 2       | 5       | 1       |

segment_rules
| priority | segment  | pattern |
|----------|----------|---------|
| 99       | A last   | ^...$   |
| 7        | Z first  | ^5..$   |
| 8        | B second | ^.5.$   |

-- EXPECTED
| customer_id | rfm_code | segment  |
|-------------|----------|----------|
| 1           | 555      | Z first  |
| 2           | 333      | A last   |
| 3           | 251      | B second |

-- CASE a catch-all rule with the highest priority number never beats a specific one
-- INPUT
customer_rfm
| customer_id | r_score | f_score | m_score |
|-------------|---------|---------|---------|
| 4           | 1       | 2       | 1       |
| 5           | 4       | 1       | 5       |

segment_rules
| priority | segment | pattern     |
|----------|---------|-------------|
| 1000     | Other   | ^.*$        |
| 30       | New     | ^[45]1.$    |
| 50       | Dormant | ^[12][12].$ |

-- EXPECTED
| customer_id | rfm_code | segment |
|-------------|----------|---------|
| 4           | 121      | Dormant |
| 5           | 415      | New     |
