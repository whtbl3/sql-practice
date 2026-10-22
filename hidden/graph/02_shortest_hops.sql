-- HIDDEN TESTS for problem graph/02. No QUERY section: the problem's QUERY is used.

-- CASE Ben Thanh has no links: only itself
-- INPUT
links
| stop_a  | stop_b   |
|---------|----------|
| Can Gio | Vung Tau |

-- EXPECTED
| stop      | hops |
|-----------|------|
| Ben Thanh | 0    |

-- CASE a long way round and a short cut to the same stop
-- INPUT
links
| stop_a    | stop_b |
|-----------|--------|
| Ben Thanh | A      |
| A         | B      |
| B         | C      |
| C         | D      |
| Ben Thanh | D      |

-- EXPECTED
| stop      | hops |
|-----------|------|
| Ben Thanh | 0    |
| A         | 1    |
| D         | 1    |
| B         | 2    |
| C         | 2    |
