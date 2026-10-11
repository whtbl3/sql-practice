-- HIDDEN TESTS for problem topn/05. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
balance_snapshots
| snapshot_id:int | account_id:int | snapshot_date:date | balance:int |
|-----------------|----------------|--------------------|-------------|

-- EXPECTED
| account_id | snapshot_id | balance |
|------------|-------------|---------|

-- CASE three-way tie on the date
-- INPUT
balance_snapshots
| snapshot_id:int | account_id:int | snapshot_date:date | balance:int |
|-----------------|----------------|--------------------|-------------|
| 7               | 10             | 2024-05-01         | 1           |
| 3               | 10             | 2024-05-01         | 2           |
| 9               | 10             | 2024-05-01         | 3           |

-- EXPECTED
| account_id | snapshot_id | balance |
|------------|-------------|---------|
| 10         | 9           | 3       |

-- CASE larger id has the lower balance
-- INPUT
balance_snapshots
| snapshot_id:int | account_id:int | snapshot_date:date | balance:int |
|-----------------|----------------|--------------------|-------------|
| 1               | 10             | 2024-05-01         | 500         |
| 2               | 10             | 2024-05-01         | 100         |

-- EXPECTED
| account_id | snapshot_id | balance |
|------------|-------------|---------|
| 10         | 2           | 100     |

-- CASE non-contiguous account ids sorted numerically
-- INPUT
balance_snapshots
| snapshot_id:int | account_id:int | snapshot_date:date | balance:int |
|-----------------|----------------|--------------------|-------------|
| 1               | 100            | 2024-01-01         | 1           |
| 2               | 20             | 2024-01-01         | 2           |
| 3               | 3              | 2024-01-01         | 3           |

-- EXPECTED
| account_id | snapshot_id | balance |
|------------|-------------|---------|
| 3          | 3           | 3       |
| 20         | 2           | 2       |
| 100        | 1           | 1       |
