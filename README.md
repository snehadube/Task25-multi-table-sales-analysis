# Multi-Table Sales Analysis (SQL + Power BI)

Combining **orders** and **order details** from the Northwind dataset to analyse sales end to end - with join validation and no double counting.

> Veda Technology - Data Analytics Internship | Author: Sneha Dubey

## Key results
| Metric | Value |
|---|---|
| Net sales | $1,265,793 |
| Orders / Customers | 830 / 89 |
| Avg order value | $1,525 |
| Top 3 countries share | 47.7% (USA, Germany, Austria) |
| Top 3 customers share | 25.2% |

## 5 insights
1. Sales grew strongly - Jan-Apr 1998 was ~2.2x Jan-Apr 1997.
2. USA + Germany + Austria = 47.7% of net sales.
3. Three customers (QUICK, ERNSH, SAVEA) give 25.2% of sales.
4. Product 38 alone earns ~11% of sales ($141K).
5. Discounted lines sell ~25% more units per line, but discounts cost $88.7K (6.5% of gross sales).

## Double counting (the main learning)
`freight` is stored once per order. After joining to `order_details`, it repeats for every product line:
true freight **$64,943** vs **$207,306** after a naive join (3.19x). Fixed by aggregating to the right grain first.

## Join validation
- No duplicate `order_id` in orders
- 0 orphan rows in order_details, 0 orders without items
- Rows after join (2,155) = rows in order_details
- Total sales matches across line view, order view and raw table: $1,265,793.04

## Files
| File | Purpose |
|---|---|
| `multi_table_sales_analysis.sql` | Validation, views and all analysis queries |
| `vw_sales_lines.csv`, `vw_orders_summary.csv`, `vw_customers.csv` | Clean outputs loaded into Power BI |
| `Multi_Table_Sales_Analysis_Report.pdf` | Full project report |
| `dashboard.png` | Power BI dashboard screenshot |
| `data/` | Original Northwind CSVs |

## How to run
1. Import `northwind_orders.csv` and `northwind_order_details.csv` into SQLite (DB Browser for SQLite) as tables `orders` and `order_details`.
2. Run `multi_table_sales_analysis.sql`.
3. Load the three view CSVs in Power BI and build visuals using the DAX measures in the report.

## Notes
- Dataset has only orders and order details, so analysis uses `product_id` / `customer_id`.
- 1998 data ends on 6 May 1998 (partial year).
- For MySQL/SQL Server replace `SUBSTR(order_date,1,4)` with `YEAR(order_date)` and `SUBSTR(order_date,1,7)` with `DATE_FORMAT(order_date,'%Y-%m')` / `FORMAT(order_date,'yyyy-MM')`.

**Tools:** SQL (SQLite), Power BI, DAX
