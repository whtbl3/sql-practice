-- HIDDEN TESTS for problem dml/06. No QUERY section: the problem's QUERY is used.

-- CASE no shipments
-- INPUT
inventory
| sku:text | qty:int |
|----------|---------|
| A        | 1       |

shipments
| sku:text | qty:int |
|----------|---------|

-- EXPECTED
inventory
| sku | qty |
|-----|-----|
| A   | 1   |

-- CASE inventory is empty
-- INPUT
inventory
| sku:text | qty:int |
|----------|---------|

shipments
| sku:text | qty:int |
|----------|---------|
| A        | 4       |
| B        | 6       |

-- EXPECTED
inventory
| sku | qty |
|-----|-----|
| A   | 4   |
| B   | 6   |

-- CASE only new skus
-- INPUT
inventory
| sku:text | qty:int |
|----------|---------|
| A        | 1       |

shipments
| sku:text | qty:int |
|----------|---------|
| B        | 2       |
| C        | 3       |

-- EXPECTED
inventory
| sku | qty |
|-----|-----|
| A   | 1   |
| B   | 2   |
| C   | 3   |

-- CASE only existing skus
-- INPUT
inventory
| sku:text | qty:int |
|----------|---------|
| A        | 1       |
| B        | 2       |

shipments
| sku:text | qty:int |
|----------|---------|
| A        | 10      |
| B        | 20      |

-- EXPECTED
inventory
| sku | qty |
|-----|-----|
| A   | 11  |
| B   | 22  |

-- CASE a new sku is not counted twice
-- INPUT
inventory
| sku:text | qty:int |
|----------|---------|
| A        | 5       |

shipments
| sku:text | qty:int |
|----------|---------|
| A        | 1       |
| Z        | 9       |

-- EXPECTED
inventory
| sku | qty |
|-----|-----|
| A   | 6   |
| Z   | 9   |
