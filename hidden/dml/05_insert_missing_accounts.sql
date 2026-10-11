-- HIDDEN TESTS for problem dml/05. No QUERY section: the problem's QUERY is used.

-- CASE accounts table is empty
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |

accounts
| customer_id:int | balance:int |
|-----------------|-------------|

-- EXPECTED
accounts
| customer_id | balance |
|-------------|---------|
| 1           | 0       |
| 2           | 0       |

-- CASE everyone already has an account
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |

accounts
| customer_id:int | balance:int |
|-----------------|-------------|
| 1               | 10          |
| 2               | 20          |

-- EXPECTED
accounts
| customer_id | balance |
|-------------|---------|
| 1           | 10      |
| 2           | 20      |

-- CASE customers table is empty
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|

accounts
| customer_id:int | balance:int |
|-----------------|-------------|
| 1               | 50          |

-- EXPECTED
accounts
| customer_id | balance |
|-------------|---------|
| 1           | 50      |

-- CASE an existing NULL balance is left alone
-- INPUT
customers
| customer_id:int | name:text |
|-----------------|-----------|
| 1               | A         |
| 2               | B         |

accounts
| customer_id:int | balance:int |
|-----------------|-------------|
| 1               | NULL        |

-- EXPECTED
accounts
| customer_id | balance |
|-------------|---------|
| 1           | NULL    |
| 2           | 0       |
