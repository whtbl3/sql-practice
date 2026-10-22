r"""
-- Problem misc/05: Daily revenue including empty days  [Medium]
-- Pattern: Calendar generation (generate_series) + LEFT JOIN
-- Variant: gap filling
--
-- Task: Return one row per calendar day from the first to the last sale_date with the day's total
--   revenue, 0 on days without sales. Sort by sale_date.
-- Learn: grinding/sql-analytics-patterns.md, mục 6

-- INPUT
sales
| sale_date  | amount |
|------------|--------|
| 2024-01-01 | 100    |
| 2024-01-01 | 50     |
| 2024-01-03 | 70     |
| 2024-01-06 | 20     |

-- EXPECTED
| sale_date  | revenue |
|------------|---------|
| 2024-01-01 | 150     |
| 2024-01-02 | 0       |
| 2024-01-03 | 70      |
| 2024-01-04 | 0       |
| 2024-01-05 | 0       |
| 2024-01-06 | 20      |
"""
import pandas as pd


def solve(sales: pd.DataFrame) -> pd.DataFrame:
    if sales.empty:
        return pd.DataFrame({"sale_date": [], "revenue": []})
    days = pd.date_range(sales["sale_date"].min(), sales["sale_date"].max(), freq="D")
    revenue = sales.groupby("sale_date")["amount"].sum().reindex(days, fill_value=0)
    return revenue.rename_axis("sale_date").reset_index(name="revenue")
