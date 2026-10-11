-- HIDDEN TESTS for problem antijoin/02. No QUERY section: the problem's QUERY is used.

-- CASE empty purchases table
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | Laptop            | Electronics   |

purchases
| customer_id:int | product_id:int |
|-----------------|----------------|

-- EXPECTED
| customer_id |
|-------------|

-- CASE category with only one product
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | Laptop            | Electronics   |
| 2              | Desk              | Furniture     |

purchases
| customer_id:int | product_id:int |
|-----------------|----------------|
| 1               | 1              |
| 2               | 2              |
| 3               | 1              |
| 3               | 2              |

-- EXPECTED
| customer_id |
|-------------|
| 1           |
| 3           |

-- CASE nobody bought the full set
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | A                 | Electronics   |
| 2              | B                 | Electronics   |
| 3              | C                 | Electronics   |

purchases
| customer_id:int | product_id:int |
|-----------------|----------------|
| 1               | 1              |
| 1               | 2              |
| 2               | 3              |

-- EXPECTED
| customer_id |
|-------------|

-- CASE bought one product many times, not the full set
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | A                 | Electronics   |
| 2              | B                 | Electronics   |

purchases
| customer_id:int | product_id:int |
|-----------------|----------------|
| 1               | 1              |
| 1               | 1              |
| 1               | 1              |
| 1               | 1              |
| 1               | 1              |
| 2               | 1              |
| 2               | 2              |

-- EXPECTED
| customer_id |
|-------------|
| 2           |

-- CASE category with no products
-- INPUT
products
| product_id:int | product_name:text | category:text |
|----------------|-------------------|---------------|
| 1              | Desk              | Furniture     |

purchases
| customer_id:int | product_id:int |
|-----------------|----------------|
| 1               | 1              |

-- EXPECTED
| customer_id |
|-------------|
