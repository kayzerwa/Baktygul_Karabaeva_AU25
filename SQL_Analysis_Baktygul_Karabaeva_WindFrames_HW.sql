
-- TASKS: WRITING QUUERIES USING WINDOW FRAMES

-- Task 1:
-- Create a query for analyzing the annual sales data for the years 1999 to 2001, 
-- focusing on different sales channels and regions: 'Americas,' 'Asia,' and 'Europe.' 
-- The resulting report should contain the following columns:
-- AMOUNT_SOLD: This column should show the total sales amount for each sales channel
-- % BY CHANNELS: In this column, we should display the percentage of total sales for each channel (e.g. 100% - total sales for Americas in 1999, 63.64% - percentage of sales for the channel “Direct Sales”)
-- % PREVIOUS PERIOD: This column should display the same percentage values as in the '% BY CHANNELS' column but for the previous year
-- % DIFF: This column should show the difference between the '% BY CHANNELS' and '% PREVIOUS PERIOD' columns, indicating the change in sales percentage from the previous year.
-- The final result should be sorted in ascending order based on three criteria: first by 'country_region,' then by 'calendar_year,' and finally by 'channel_desc'


SELECT 
    country_region,
    calendar_year,
    channel_desc,
    amount_sold AS "amount_sold",
    pct_by_channels AS "% by channels",
    LAG(pct_by_channels) OVER (
        PARTITION BY country_region, channel_desc 
        ORDER BY calendar_year
    ) AS "% previous period",
    ROUND(
        pct_by_channels - LAG(pct_by_channels) OVER (
            PARTITION BY country_region, channel_desc 
            ORDER BY calendar_year
        ), 2
    ) AS "% diff"
FROM (
    SELECT 
        co.country_region,
        t.calendar_year,
        ch.channel_desc,
        SUM(s.amount_sold) AS amount_sold,
        ROUND(
            SUM(s.amount_sold) * 100.0 / 
            SUM(SUM(s.amount_sold)) OVER (
                PARTITION BY co.country_region, t.calendar_year
            ), 
            2
        ) AS pct_by_channels
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.customers cu ON s.cust_id = cu.cust_id
    JOIN sh.countries co ON cu.country_id = co.country_id
    JOIN sh.channels ch ON s.channel_id = ch.channel_id
    WHERE t.calendar_year BETWEEN 1999 AND 2001
        AND co.country_region IN ('Americas', 'Asia', 'Europe')
    GROUP BY co.country_region, t.calendar_year, ch.channel_desc
) sales_summary
ORDER BY country_region, calendar_year, channel_desc;
    
  
-- Task 2:
-- You need to create a query that meets the following requirements:
-- Generate a sales report for the 49th, 50th, and 51st weeks of 1999.
-- Include a column named CUM_SUM to display the amounts accumulated during each week.
-- Include a column named CENTERED_3_DAY_AVG to show the average sales for the previous, current, and following days using a centered moving average.
-- For Monday, calculate the average sales based on the weekend sales (Saturday and Sunday) as well as Monday and Tuesday.
-- For Friday, calculate the average sales on Thursday, Friday, and the weekend.
-- Ensure that your calculations are accurate for the beginning of week 49 and the end of week 51.
  
SELECT 
    time_id,
    calendar_week_number,
    day_name,
    day_number_in_week,
    amount_sold,
    -- Cumulative sum within each week, reset at each week boundary
    SUM(amount_sold) OVER (
        PARTITION BY calendar_week_number 
        ORDER BY time_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS "cum_sum",
    -- Centered 3-day average with special handling for Monday and Friday
    CASE 
        -- Monday: average of Sat, Sun, Mon, Tue (2 preceding + current + 1 following)
        WHEN day_name = 'Monday' THEN
            ROUND(
                AVG(amount_sold) OVER (
                    ORDER BY time_id
                    ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING
                ), 2
            )
        -- Friday: average of Thu, Fri, Sat, Sun (1 preceding + current + 2 following)
        WHEN day_name = 'Friday' THEN
            ROUND(
                AVG(amount_sold) OVER (
                    ORDER BY time_id
                    ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING
                ), 2
            )
        -- Other days: standard centered 3-day average (previous, current, next)
        ELSE
            ROUND(
                AVG(amount_sold) OVER (
                    ORDER BY time_id
                    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
                ), 2
            )
    END AS "centered_3_day_avg"
FROM (
    SELECT 
        t.time_id,
        t.calendar_week_number,
        t.day_name,
        t.day_number_in_week,
        SUM(s.amount_sold) AS amount_sold
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year = 1999
        AND t.calendar_week_number IN (49, 50, 51)
    GROUP BY t.time_id, t.calendar_week_number, t.day_name, t.day_number_in_week
) daily_sales
ORDER BY time_id;


-- Task 3: 
-- Please provide 3 instances of utilizing window functions that include a frame clause, using RANGE, ROWS, and GROUPS modes. 
-- Additionally, explain the reason for choosing a specific frame type for each example. 
-- This can be presented as a single query or as three distinct queries.

WITH daily_product_sales AS (
    SELECT 
        t.time_id,
        t.calendar_year,
        t.calendar_month_number,
        t.day_number_in_month,
        p.prod_category,
        SUM(s.amount_sold) AS daily_amount,
        SUM(s.quantity_sold) AS daily_quantity
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.products p ON s.prod_id = p.prod_id
    WHERE t.calendar_year = 2001
        AND t.calendar_month_number = 1
    GROUP BY t.time_id, t.calendar_year, t.calendar_month_number, 
             t.day_number_in_month, p.prod_category
)
SELECT 
    time_id,
    day_number_in_month,
    prod_category,
    daily_amount,
    
    /* ROWS MODE
     * Purpose: Calculate a 3-ROW moving average
     * Use Case: Smoothing sales data using exactly 3 physical rows
     * Why ROWS: We want exactly 3 rows regardless of their values
     * - Includes current row + 1 preceding + 1 following
     * - Works with physical row positions
     */
    ROUND(
        AVG(daily_amount) OVER (
            PARTITION BY prod_category
            ORDER BY time_id
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ), 2
    ) AS "rows_3_day_moving_avg",
    
    /* RANGE MODE
     * Purpose: Calculate cumulative sales within a 5-day time range
     * Use Case: Sum all sales within 5 days before and including current day
     * Why RANGE: Handles multiple rows with same ORDER BY value (same day)
     * - If multiple categories sold on same day, all are included
     * - Based on logical ordering value, not physical row count
     * - More appropriate for time-based windows
     */
    ROUND(
        SUM(daily_amount) OVER (
            PARTITION BY prod_category
            ORDER BY day_number_in_month
            RANGE BETWEEN 5 PRECEDING AND CURRENT ROW
        ), 2
    ) AS "range_5_day_cum_sum",
    
    /* GROUPS MODE
     * Purpose: Compare current day's sales to previous 2 days as groups
     * Use Case: Calculate average sales across 3 distinct day groups
     * Why GROUPS: Treats all rows with same ORDER BY value as one group
     * - Each unique day is one group (even if multiple categories)
     * - Includes 2 preceding day-groups + current day-group
     * - Perfect for comparing distinct time periods or categories
     */
    ROUND(
        AVG(daily_amount) OVER (
            PARTITION BY prod_category
            ORDER BY day_number_in_month
            GROUPS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS "groups_3_day_group_avg"
    
FROM daily_product_sales
ORDER BY prod_category, time_id;
