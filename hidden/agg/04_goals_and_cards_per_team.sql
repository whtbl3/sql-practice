-- HIDDEN TESTS for problem agg/04. No QUERY section: the problem's QUERY is used.

-- CASE empty tables
-- INPUT
teams
| team_id:int | name:text |
|-------------|-----------|

goals
| goal_id:int | team_id:int |
|-------------|-------------|

cards
| card_id:int | team_id:int |
|-------------|-------------|

-- EXPECTED
| team | goals | cards |
|------|-------|-------|

-- CASE team without any events
-- INPUT
teams
| team_id:int | name:text |
|-------------|-----------|
| 1           | Idle      |

goals
| goal_id:int | team_id:int |
|-------------|-------------|

cards
| card_id:int | team_id:int |
|-------------|-------------|

-- EXPECTED
| team | goals | cards |
|------|-------|-------|
| Idle | 0     | 0     |

-- CASE many goals times many cards
-- INPUT
teams
| team_id:int | name:text |
|-------------|-----------|
| 1           | A         |

goals
| goal_id:int | team_id:int |
|-------------|-------------|
| 1           | 1           |
| 2           | 1           |
| 3           | 1           |
| 4           | 1           |

cards
| card_id:int | team_id:int |
|-------------|-------------|
| 1           | 1           |
| 2           | 1           |
| 3           | 1           |
| 4           | 1           |
| 5           | 1           |

-- EXPECTED
| team | goals | cards |
|------|-------|-------|
| A    | 4     | 5     |
