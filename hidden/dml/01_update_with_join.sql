-- HIDDEN TESTS for problem dml/01. No QUERY section: the problem's QUERY is used.

-- CASE no department in Hanoi
-- INPUT
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | Alice     | 1           | 5000       |

departments
| dept_id:int | dept_name:text | location:text |
|-------------|----------------|---------------|
| 1           | IT             | Saigon        |

-- EXPECTED
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | Alice     | 1           | 5000       |

-- CASE NULL salary in Hanoi stays NULL
-- INPUT
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | Alice     | 1           | NULL       |

departments
| dept_id:int | dept_name:text | location:text |
|-------------|----------------|---------------|
| 1           | IT             | Hanoi         |

-- EXPECTED
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | Alice     | 1           | NULL       |

-- CASE unknown dept_id, only Hanoi departments get the raise
-- INPUT
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | Alice     | 99          | 5000       |
| 2          | Bob       | 1           | 1000       |

departments
| dept_id:int | dept_name:text | location:text |
|-------------|----------------|---------------|
| 1           | IT             | Hanoi         |

-- EXPECTED
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | Alice     | 99          | 5000       |
| 2          | Bob       | 1           | 1100       |

-- CASE one department with several employees, another in a different city
-- INPUT
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | A         | 1           | 100        |
| 2          | B         | 1           | 200        |
| 3          | C         | 2           | 300        |

departments
| dept_id:int | dept_name:text | location:text |
|-------------|----------------|---------------|
| 1           | IT             | Hanoi         |
| 2           | HR             | Saigon        |

-- EXPECTED
employees
| emp_id:int | name:text | dept_id:int | salary:int |
|------------|-----------|-------------|------------|
| 1          | A         | 1           | 110        |
| 2          | B         | 1           | 220        |
| 3          | C         | 2           | 300        |
