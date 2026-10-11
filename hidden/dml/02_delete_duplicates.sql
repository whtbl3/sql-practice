-- HIDDEN TESTS for problem dml/02. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
contacts
| id:int | email:text |
|--------|------------|

-- EXPECTED
contacts
| id:int | email:text |
|--------|------------|

-- CASE no duplicate emails
-- INPUT
contacts
| id:int | email:text |
|--------|------------|
| 1      | a@x.com    |
| 2      | b@x.com    |
| 3      | c@x.com    |

-- EXPECTED
contacts
| id:int | email:text |
|--------|------------|
| 1      | a@x.com    |
| 2      | b@x.com    |
| 3      | c@x.com    |

-- CASE all rows duplicated
-- INPUT
contacts
| id:int | email:text |
|--------|------------|
| 1      | a@x.com    |
| 2      | a@x.com    |
| 3      | a@x.com    |
| 4      | a@x.com    |

-- EXPECTED
contacts
| id:int | email:text |
|--------|------------|
| 1      | a@x.com    |

-- CASE smallest id is not the first inserted row
-- INPUT
contacts
| id:int | email:text |
|--------|------------|
| 5      | a@x.com    |
| 2      | a@x.com    |
| 9      | b@x.com    |
| 1      | b@x.com    |

-- EXPECTED
contacts
| id:int | email:text |
|--------|------------|
| 1      | b@x.com    |
| 2      | a@x.com    |
