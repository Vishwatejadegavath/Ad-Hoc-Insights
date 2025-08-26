-- ---------------------------------------------------------------------------------------------------------------------
-- Codebasics Resume Challenge: Consumer Goods Ad-Hoc Insights
-- This script contains 10 SQL queries designed to answer specific business questions for AtliQ Hardwares.
-- Each query corresponds to a request from the management team.
-- ---------------------------------------------------------------------------------------------------------------------

-- Request 1: Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
-- ---------------------------------------------------------------------------------------------------------------------
SELECT 
    DISTINCT(market)
FROM dim_customer
WHERE customer = "Atliq Exclusive" 
  AND region = "APAC";


-- Request 2: What is the percentage of unique product increase in 2021 vs. 2020?
-- ---------------------------------------------------------------------------------------------------------------------
WITH cte_2020 AS (
    SELECT COUNT(DISTINCT(product_code)) AS unique_products_2020
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020
),
cte_2021 AS (
    SELECT COUNT(DISTINCT(product_code)) AS unique_products_2021
    FROM fact_sales_monthly
    WHERE fiscal_year = 2021
)
SELECT
    unique_products_2020,
    unique_products_2021,
    ROUND(((unique_products_2021 - unique_products_2020) * 100 / unique_products_2020), 2) AS percentage_chg
FROM cte_2020, cte_2021;


-- Request 3: Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
-- ---------------------------------------------------------------------------------------------------------------------
SELECT 
    segment,
    COUNT(DISTINCT(product_code)) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


-- Request 4: Which segment had the most increase in unique products in 2021 vs 2020?
-- ---------------------------------------------------------------------------------------------------------------------
WITH cte_products_2020 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT(s.product_code)) AS product_count_2020
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2020
    GROUP BY p.segment
),
cte_products_2021 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT(s.product_code)) AS product_count_2021
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.segment
)
SELECT 
    p20.segment,
    p20.product_count_2020,
    p21.product_count_2021,
    (p21.product_count_2021 - p20.product_count_2020) AS difference
FROM cte_products_2020 p20
JOIN cte_products_2021 p21 ON p20.segment = p21.segment
ORDER BY difference DESC;


-- Request 5: Get the products that have the highest and lowest manufacturing costs.
-- ---------------------------------------------------------------------------------------------------------------------
(SELECT
    p.product_code,
    p.product,
    m.manufacturing_cost
FROM dim_product p
JOIN fact_manufacturing_cost m ON p.product_code = m.product_code
ORDER BY m.manufacturing_cost DESC
LIMIT 1)
UNION
(SELECT
    p.product_code,
    p.product,
    m.manufacturing_cost
FROM dim_product p
JOIN fact_manufacturing_cost m ON p.product_code = m.product_code
ORDER BY m.manufacturing_cost ASC
LIMIT 1);


-- Request 6: Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for FY=2021 in India.
-- ---------------------------------------------------------------------------------------------------------------------
SELECT 
    c.customer_code,
    c.customer,
    ROUND(AVG(p.pre_invoice_discount_pct) * 100, 2) AS average_discount_percentage
FROM fact_pre_invoice_deductions p
JOIN dim_customer c ON p.customer_code = c.customer_code
WHERE c.market = "India" 
  AND p.fiscal_year = 2021
GROUP BY c.customer_code, c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;


-- Request 7: Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.
-- ---------------------------------------------------------------------------------------------------------------------
SELECT 
    MONTHNAME(s.date) AS month,
    s.fiscal_year AS year,
    ROUND(SUM(s.sold_quantity * g.gross_price), 2) AS gross_sales_amount
FROM fact_sales_monthly s 
JOIN fact_gross_price g ON s.product_code = g.product_code AND s.fiscal_year = g.fiscal_year
JOIN dim_customer c ON s.customer_code = c.customer_code
WHERE c.customer = "Atliq Exclusive"
GROUP BY 
    s.fiscal_year,
    MONTHNAME(s.date)
ORDER BY year, MONTH(s.date);


-- Request 8: In which quarter of 2020, got the maximum total_sold_quantity?
-- ---------------------------------------------------------------------------------------------------------------------
SELECT 
    CASE
        WHEN MONTH(date) IN (9, 10, 11) THEN "Q1"
        WHEN MONTH(date) IN (12, 1, 2) THEN "Q2"
        WHEN MONTH(date) IN (3, 4, 5) THEN "Q3"
        ELSE "Q4"
    END AS Quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020 
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;


-- Request 9: Which channel helped to bring more gross sales in the fiscal year 2021 and what was its percentage of contribution?
-- ---------------------------------------------------------------------------------------------------------------------
WITH channel_sales AS (
    SELECT 
        c.channel,
        ROUND(SUM(s.sold_quantity * g.gross_price) / 1000000, 2) AS gross_sales_mln
    FROM fact_sales_monthly s
    JOIN dim_customer c ON s.customer_code = c.customer_code
    JOIN fact_gross_price g ON s.product_code = g.product_code AND s.fiscal_year = g.fiscal_year
    WHERE s.fiscal_year = 2021
    GROUP BY c.channel
)
SELECT 
    channel,
    gross_sales_mln,
    ROUND(gross_sales_mln * 100 / (SELECT SUM(gross_sales_mln) FROM channel_sales), 2) AS percentage_contribution
FROM channel_sales
ORDER BY gross_sales_mln DESC;


-- Request 10: Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021.
-- ---------------------------------------------------------------------------------------------------------------------
WITH ranked_products AS (
    SELECT 
        p.division,
        p.product_code,
        p.product,
        SUM(s.sold_quantity) AS total_sold_quantity,
        RANK() OVER(PARTITION BY division ORDER BY SUM(s.sold_quantity) DESC) AS rank_order
    FROM dim_product p
    JOIN fact_sales_monthly s ON p.product_code = s.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, p.product_code, p.product
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM ranked_products 
WHERE rank_order <= 3;
