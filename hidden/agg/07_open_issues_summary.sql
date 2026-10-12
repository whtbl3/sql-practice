-- HIDDEN TESTS for problem agg/07. No QUERY section: the problem's QUERY is used.

-- CASE all tables empty
-- INPUT
complaints
| complaint_id:int | status:text |
|------------------|-------------|

orders
| order_id:int | status:text |
|--------------|-------------|

products
| product_id:int | status:text |
|----------------|-------------|

-- EXPECTED
| type                 | quantity | pct  |
|----------------------|----------|------|
| Cancelled Order      | 0        | NULL |
| Complaint            | 0        | NULL |
| Out of Stock Product | 0        | NULL |

-- CASE only one kind of issue
-- INPUT
complaints
| complaint_id:int | status:text |
|------------------|-------------|
| 1                | Pending     |

orders
| order_id:int | status:text |
|--------------|-------------|
| 1            | Shipped     |

products
| product_id:int | status:text |
|----------------|-------------|

-- EXPECTED
| type                 | quantity | pct   |
|----------------------|----------|-------|
| Complaint            | 1        | 100.0 |
| Cancelled Order      | 0        | 0.0   |
| Out of Stock Product | 0        | 0.0   |

-- CASE other statuses are ignored
-- INPUT
complaints
| complaint_id:int | status:text |
|------------------|-------------|
| 1                | Resolved    |

orders
| order_id:int | status:text |
|--------------|-------------|
| 1            | Cancelled   |
| 2            | Cancelled   |

products
| product_id:int | status:text  |
|----------------|--------------|
| 1              | Out of Stock |
| 2              | Out of Stock |

-- EXPECTED
| type                 | quantity | pct  |
|----------------------|----------|------|
| Cancelled Order      | 2        | 50.0 |
| Out of Stock Product | 2        | 50.0 |
| Complaint            | 0        | 0.0  |
