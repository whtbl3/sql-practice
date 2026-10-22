-- HIDDEN TESTS for problem agg/09. No QUERY section: the problem's QUERY is used.

-- CASE no sales: only the grand total, with a NULL sum
-- INPUT
sales
| sale_id:int | region:text | province:text | store:text | revenue_vnd:int |
|-------------|-------------|---------------|------------|-----------------|

-- EXPECTED
| region      | province | store | revenue_vnd | level   |
|-------------|----------|-------|-------------|---------|
| Grand total |          |       | NULL        | Country |

-- CASE one store
-- INPUT
sales
| sale_id | region | province | store | revenue_vnd |
|---------|--------|----------|-------|-------------|
| 1       | South  | Can Tho  | CT-09 | 70          |

-- EXPECTED
| region      | province     | store          | revenue_vnd | level    |
|-------------|--------------|----------------|-------------|----------|
| South       | Can Tho      | CT-09          | 70          | Store    |
| South       | Can Tho      | Province total | 70          | Province |
| South       | Region total |                | 70          | Region   |
| Grand total |              |                | 70          | Country  |
