-- HIDDEN TESTS for problem islands/03. No QUERY section: the problem's QUERY is used.

-- CASE empty table
-- INPUT
invoices
| invoice_no:int |
|----------------|

-- EXPECTED
| gap_start | gap_end |
|-----------|---------|

-- CASE no gaps
-- INPUT
invoices
| invoice_no:int |
|----------------|
| 1              |
| 2              |
| 3              |
| 4              |
| 5              |

-- EXPECTED
| gap_start | gap_end |
|-----------|---------|

-- CASE unsorted input with duplicates
-- INPUT
invoices
| invoice_no:int |
|----------------|
| 5              |
| 1              |
| 5              |
| 3              |
| 1              |

-- EXPECTED
| gap_start | gap_end |
|-----------|---------|
| 2         | 2       |
| 4         | 4       |

-- CASE one huge gap
-- INPUT
invoices
| invoice_no:int |
|----------------|
| 1              |
| 1000           |

-- EXPECTED
| gap_start | gap_end |
|-----------|---------|
| 2         | 999     |

-- CASE negative numbers
-- INPUT
invoices
| invoice_no:int |
|----------------|
| -3             |
| -1             |
| 2              |

-- EXPECTED
| gap_start | gap_end |
|-----------|---------|
| -2        | -2      |
| 0         | 1       |
