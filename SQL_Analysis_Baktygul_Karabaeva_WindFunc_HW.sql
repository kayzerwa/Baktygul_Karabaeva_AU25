-- WINDOW FUNCTIONS
-- TASK 1:
-- ========================================================================
/* 
 - Create a query to produce a sales report highlighting the top customers with the highest sales across different sales channels. 
 - This report should list the top 5 customers for each channel. 
 - Additionally, calculate a key performance indicator (KPI) called 'sales_percentage,' which represents the percentage 
 of a customer's sales relative to the total sales within their respective channel.
 
Please format the columns as follows:
- Display the total sales amount with two decimal places
- Display the sales percentage with four decimal places and include the percent sign (%) at the end
- Display the result for each channel in descending order of sales
*/

WITH ranked_customers AS (
    -- Calculate total sales per customer per channel, channel totals, and rankings in one CTE
    SELECT 
        c.cust_id,
        c.cust_first_name,
        c.cust_last_name,
        ch.channel_desc,
        SUM(s.amount_sold) AS total_sales,
        SUM(SUM(s.amount_sold)) OVER (PARTITION BY ch.channel_desc) AS channel_total_sales,
        ROW_NUMBER() OVER (PARTITION BY ch.channel_desc ORDER BY SUM(s.amount_sold) DESC) AS rank
    FROM sh.sales s
    JOIN sh.customers c ON s.cust_id = c.cust_id
    JOIN sh.channels ch ON s.channel_id = ch.channel_id
    GROUP BY c.cust_id, c.cust_first_name, c.cust_last_name, ch.channel_desc
)
SELECT 
    cust_id,
    cust_first_name,
    cust_last_name,
    channel_desc,
    TO_CHAR(total_sales, 'FM999999999990.00') AS total_sales,
    TO_CHAR((total_sales / channel_total_sales * 100), 'FM9990.0000') || '%' AS sales_percentage
FROM ranked_customers
WHERE rank <= 5
ORDER BY channel_desc, rank;

       
-- TASK 2:
-- ========================================================================
/* 
- Create a query to retrieve data for a report that displays the total sales for all products in the Photo category in the Asian region for the year 2000. 
- Calculate the overall report total and name it 'YEAR_SUM'.
- Display the sales amount with two decimal places
- Display the result in descending order of 'YEAR_SUM'
- For this report, consider exploring the use of the crosstab function.
 */

-- Enable the tablefunc extension for crosstab (run once)
CREATE EXTENSION IF NOT EXISTS tablefunc;

WITH monthly_sales AS (
    SELECT 
        p.prod_name,
        t.calendar_month_desc,
        SUM(s.amount_sold) AS monthly_amount
    FROM sh.sales s
    JOIN sh.products p ON s.prod_id = p.prod_id
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.customers c ON s.cust_id = c.cust_id
    JOIN sh.countries co ON c.country_id = co.country_id
    WHERE p.prod_category = 'Photo'
        AND co.country_subregion = 'Asia'
        AND t.calendar_year = 2000
    GROUP BY p.prod_name, t.calendar_month_desc
),
product_year_totals AS (
    SELECT 
        p.prod_name,
        SUM(s.amount_sold) AS year_sum
    FROM sh.sales s
    JOIN sh.products p ON s.prod_id = p.prod_id
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.customers c ON s.cust_id = c.cust_id
    JOIN sh.countries co ON c.country_id = co.country_id
    WHERE p.prod_category = 'Photo'
        AND co.country_subregion = 'Asia'
        AND t.calendar_year = 2000
    GROUP BY p.prod_name
)
SELECT 
    ct.*,
    TO_CHAR(pyt.year_sum, 'FM999999990.00') AS year_sum
FROM crosstab(
    'SELECT 
        p.prod_name,
        t.calendar_month_desc,
        SUM(s.amount_sold)
    FROM sh.sales s
    JOIN sh.products p ON s.prod_id = p.prod_id
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.customers c ON s.cust_id = c.cust_id
    JOIN sh.countries co ON c.country_id = co.country_id
    WHERE p.prod_category = ''Photo''
        AND co.country_subregion = ''Asia''
        AND t.calendar_year = 2000
    GROUP BY p.prod_name, t.calendar_month_desc
    ORDER BY 1, 2',
    'SELECT DISTINCT calendar_month_desc 
     FROM times 
     WHERE calendar_year = 2000 
     ORDER BY calendar_month_desc'
) AS ct(
    prod_name VARCHAR,
    "2000-01" NUMERIC,
    "2000-02" NUMERIC,
    "2000-03" NUMERIC,
    "2000-04" NUMERIC,
    "2000-05" NUMERIC,
    "2000-06" NUMERIC,
    "2000-07" NUMERIC,
    "2000-08" NUMERIC,
    "2000-09" NUMERIC,
    "2000-10" NUMERIC,
    "2000-11" NUMERIC,
    "2000-12" NUMERIC
)
JOIN product_year_totals pyt ON ct.prod_name = pyt.prod_name
ORDER BY pyt.year_sum DESC;

-- TASK 3: 
-- ========================================================================
/* 
- Create a query to generate a sales report for customers ranked in the top 300 based on total sales in the years 1998, 1999, and 2001. 
- The report should be categorized based on sales channels, and separate calculations should be performed for each channel.
- Retrieve customers who ranked among the top 300 in sales for the years 1998, 1999, and 2001
- Categorize the customers based on their sales channels
- Perform separate calculations for each sales channel
- Include in the report only purchases made on the channel specified
- Format the column so that total sales are displayed with two decimal places
*/

WITH customer_channel_sales AS (
	SELECT 
		s.cust_id,
		c.channel_id,
		c.channel_desc,
		t.calendar_year,
		sum(s.amount_sold) AS total_sales
	FROM sh.sales s
	JOIN sh.times t ON t.time_id = s.time_id
	JOIN sh.channels c ON c.channel_id = s.channel_id
	WHERE t.calendar_year IN (1998, 1999, 2001)
	GROUP BY 
		s.cust_id, c.channel_id, c.channel_desc, t.calendar_year ),
ranked_customers AS (
	SELECT 
		cust_id,
		channel_id, 
		channel_desc,
		calendar_year, 
		total_sales,
		RANK() OVER (PARTITION BY calendar_year, channel_id ORDER BY total_sales DESC )AS sales_rank
	FROM customer_channel_sales)
SELECT
	rc.calendar_year,
	rc.channel_desc AS sales_channel,
	cu.cust_id,
	cu.cust_first_name,
	cu.cust_last_name,
	TO_CHAR(rc.total_sales, 'FM9999999990.00') AS total_sales
FROM ranked_customers rc
JOIN customers cu ON cu.cust_id = rc.cust_id
WHERE rc.sales_rank <= 300
ORDER BY 
	rc.calendar_year, rc.channel_desc, rc.sales_rank;

-- TASK 4: 
-- ========================================================================
/*
- Create a query to generate a sales report for January 2000, February 2000, and March 2000 specifically for the Europe and Americas regions.
- Display the result by months and by product category in alphabetical order.
*/

SELECT 
    t.calendar_month_desc,
    p.prod_category,
    co.country_region,
    TO_CHAR(SUM(s.amount_sold), 'FM999999990.00') AS total_sales
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
JOIN sh.products p ON s.prod_id = p.prod_id
JOIN sh.customers c ON s.cust_id = c.cust_id
JOIN sh.countries co ON c.country_id = co.country_id
WHERE t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
    AND co.country_region IN ('Europe', 'Americas')
GROUP BY t.calendar_month_desc, p.prod_category, co.country_region
ORDER BY t.calendar_month_desc, p.prod_category, co.country_region;