/* =====================================================================
   MULTI-TABLE SALES ANALYSIS  |  Northwind (orders + order_details)
   Author: Sneha Dubey  |  Veda Technology - Data Analytics Track
   Tested on: SQLite / DB Browser for SQLite
   (MySQL/SQL Server: sirf date functions badalne padte hain - README dekho)
   ===================================================================== */

/* ---------- 0. TABLES (CSV import ke baad ye 2 tables bante hain) -----
   orders(order_id, customer_id, employee_id, order_date, required_date,
          shipped_date, ship_via, freight, ship_name, ship_address,
          ship_city, ship_region, ship_postal_code, ship_country)
   order_details(order_id, product_id, unit_price, quantity, discount)
   Relationship: orders (1)  --->  (many) order_details   on order_id
--------------------------------------------------------------------- */

/* ---------- 1. JOIN VALIDATION (pehle check, phir analysis) --------- */

-- 1a. Row counts
SELECT 'orders' AS tbl, COUNT(*) AS row_count FROM orders
UNION ALL
SELECT 'order_details', COUNT(*) FROM order_details;

-- 1b. Primary key duplicate? (0 rows aana chahiye)
SELECT order_id, COUNT(*) FROM orders GROUP BY order_id HAVING COUNT(*) > 1;

-- 1c. Orphan rows: details jinka order nahi hai (0 aana chahiye)
SELECT COUNT(*) AS orphan_detail_rows
FROM order_details od
LEFT JOIN orders o ON o.order_id = od.order_id
WHERE o.order_id IS NULL;

-- 1d. Orders jinme koi item nahi (0 aana chahiye)
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_details od ON od.order_id = o.order_id
WHERE od.order_id IS NULL;

-- 1e. Join ke baad row count = order_details row count hona chahiye (2155)
SELECT COUNT(*) AS rows_after_join
FROM orders o JOIN order_details od ON od.order_id = o.order_id;

/* ---------- 2. DOUBLE COUNTING DEMO --------------------------------- */
-- Freight orders table ka column hai (1 value per ORDER).
-- Join ke baad har order ki freight uski item lines ke saath repeat hoti hai.
SELECT
  (SELECT ROUND(SUM(freight),2) FROM orders)               AS true_freight,
  ROUND(SUM(o.freight),2)                                  AS inflated_freight_after_join
FROM orders o JOIN order_details od ON od.order_id = o.order_id;

-- FIX: pehle order_details ko order level par aggregate karo, phir join karo
SELECT ROUND(SUM(o.freight),2) AS freight_correct
FROM orders o
JOIN (SELECT order_id FROM order_details GROUP BY order_id) x
  ON x.order_id = o.order_id;

/* ---------- 3. REUSABLE VIEWS (Power BI inhi se data lega) ---------- */

DROP VIEW IF EXISTS vw_sales_lines;
CREATE VIEW vw_sales_lines AS
SELECT
  o.order_id,
  od.product_id,
  o.customer_id,
  o.employee_id,
  o.order_date,
  SUBSTR(o.order_date,1,4)                         AS order_year,
  SUBSTR(o.order_date,1,7)                         AS order_month,
  o.ship_country,
  o.ship_city,
  od.unit_price,
  od.quantity,
  od.discount,
  od.unit_price*od.quantity                                   AS gross_sales,
  od.unit_price*od.quantity*od.discount                       AS discount_amount,
  od.unit_price*od.quantity*(1-od.discount)                    AS net_sales,
  CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE 0 END AS is_late
FROM orders o
JOIN order_details od ON od.order_id = o.order_id;

DROP VIEW IF EXISTS vw_orders_summary;   -- ORDER grain: 1 row = 1 order
CREATE VIEW vw_orders_summary AS
SELECT
  o.order_id, o.customer_id, o.employee_id, o.order_date,
  o.ship_country, o.freight,
  COUNT(od.product_id)                                   AS item_lines,
  SUM(od.quantity)                                       AS total_units,
  SUM(od.unit_price*od.quantity*(1-od.discount))        AS order_net_sales
FROM orders o
JOIN order_details od ON od.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.employee_id, o.order_date,
         o.ship_country, o.freight;

DROP VIEW IF EXISTS vw_customers;        -- customers table nahi tha, orders se banayi
CREATE VIEW vw_customers AS
SELECT customer_id,
       MIN(ship_country) AS country,
       COUNT(*)          AS total_orders
FROM orders GROUP BY customer_id;

/* ---------- 4. VALIDATE TOTALS (interview Q2) ----------------------- */
-- Line-level total aur order-level total EXACT same hone chahiye
SELECT
  (SELECT ROUND(SUM(net_sales),2)      FROM vw_sales_lines)     AS total_from_lines,
  (SELECT ROUND(SUM(order_net_sales),2) FROM vw_orders_summary) AS total_from_orders,
  (SELECT ROUND(SUM(unit_price*quantity*(1-discount)),2) FROM order_details) AS total_from_raw_table;

/* ---------- 5. BUSINESS ANALYSIS ------------------------------------ */

-- Q1. KPI summary
SELECT ROUND(SUM(net_sales),0)                        AS total_net_sales,
       COUNT(DISTINCT order_id)                       AS total_orders,
       COUNT(DISTINCT customer_id)                    AS total_customers,
       ROUND(SUM(net_sales)/COUNT(DISTINCT order_id),0) AS avg_order_value,
       ROUND(SUM(discount_amount),0)                  AS total_discount_given
FROM vw_sales_lines;

-- Q2. Year-wise sales (NOTE: 1998 sirf May tak ka data hai)
SELECT order_year, ROUND(SUM(net_sales),0) AS net_sales,
       COUNT(DISTINCT order_id) AS orders
FROM vw_sales_lines GROUP BY order_year ORDER BY order_year;

-- Q3. Monthly trend
SELECT order_month, ROUND(SUM(net_sales),0) AS net_sales
FROM vw_sales_lines GROUP BY order_month ORDER BY order_month;

-- Q4. Top 10 countries by sales + % share
SELECT ship_country,
       ROUND(SUM(net_sales),0) AS net_sales,
       ROUND(100.0*SUM(net_sales)/(SELECT SUM(net_sales) FROM vw_sales_lines),1) AS pct_share
FROM vw_sales_lines GROUP BY ship_country ORDER BY net_sales DESC LIMIT 10;

-- Q5. Top 10 customers
SELECT customer_id, ROUND(SUM(net_sales),0) AS net_sales,
       COUNT(DISTINCT order_id) AS orders
FROM vw_sales_lines GROUP BY customer_id ORDER BY net_sales DESC LIMIT 10;

-- Q6. Top 10 products
SELECT product_id, ROUND(SUM(net_sales),0) AS net_sales, SUM(quantity) AS units
FROM vw_sales_lines GROUP BY product_id ORDER BY net_sales DESC LIMIT 10;

-- Q7. Employee performance
SELECT employee_id, ROUND(SUM(net_sales),0) AS net_sales,
       COUNT(DISTINCT order_id) AS orders
FROM vw_sales_lines GROUP BY employee_id ORDER BY net_sales DESC;

-- Q8. Discount impact
SELECT CASE WHEN discount > 0 THEN 'Discounted' ELSE 'Full price' END AS price_type,
       COUNT(*) AS lines, ROUND(AVG(quantity),1) AS avg_units_per_line,
       ROUND(SUM(net_sales),0) AS net_sales
FROM vw_sales_lines GROUP BY 1;

-- Q9. Late deliveries (shipped_date > required_date)
SELECT COUNT(*) AS shipped_orders,
       SUM(CASE WHEN shipped_date > required_date THEN 1 ELSE 0 END) AS late_orders,
       ROUND(100.0*SUM(CASE WHEN shipped_date > required_date THEN 1 ELSE 0 END)/COUNT(*),1) AS late_pct
FROM orders WHERE shipped_date IS NOT NULL;

-- Q10. Top-3 customer concentration
WITH c AS (SELECT customer_id, SUM(net_sales) s FROM vw_sales_lines GROUP BY customer_id),
     r AS (SELECT s, ROW_NUMBER() OVER (ORDER BY s DESC) rn FROM c)
SELECT ROUND(100.0*SUM(CASE WHEN rn<=3 THEN s END)/SUM(s),1) AS top3_customer_share_pct FROM r;
