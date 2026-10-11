-- HIDDEN TESTS for problem antijoin/01. No QUERY section: the problem's QUERY is used.

-- CASE empty orders table
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Ben       |
| 2               | Anna      |

orders
| order_id:int | customer_id:int | status:text |
|--------------|-----------------|-------------|

-- EXPECTED
| name |
|------|
| Anna |
| Ben  |

-- CASE empty customers table
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|

orders
| order_id:int | customer_id:int | status:text |
|--------------|-----------------|-------------|
| 1            | 1               | Completed   |

-- EXPECTED
| name |
|------|

-- CASE every customer has a completed order
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |

orders
| order_id:int | customer_id:int | status:text |
|--------------|-----------------|-------------|
| 1            | 1               | Completed   |
| 2            | 2               | Completed   |

-- EXPECTED
| name |
|------|

-- CASE only Pending and Cancelled orders
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | Anna      |
| 2               | Ben       |

orders
| order_id:int | customer_id:int | status:text |
|--------------|-----------------|-------------|
| 1            | 1               | Pending     |
| 2            | 1               | Cancelled   |
| 3            | 2               | Completed   |

-- EXPECTED
| name |
|------|
| Anna |

-- CASE multiple NULL customer_id rows
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | X         |

orders
| order_id:int | customer_id:int | status:text |
|--------------|-----------------|-------------|
| 1            | NULL            | Completed   |
| 2            | NULL            | Completed   |

-- EXPECTED
| name |
|------|
| X    |
