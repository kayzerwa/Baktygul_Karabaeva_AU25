/* The HR department aims to reward top-performing employees in 2017
* with bonuses to recognize their contribution to stores revenue. 
* Show which three employees generated the most revenue in 2017? 
* staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
* if staff processed the payment then he works in the same store; 
* take into account only payment_date */

-- HR department rewards the top 3 employees who has the highest revenue in 2017, filter payments from 2017
-- payment table contains transactions with amount, staff_id, and payment_date
-- staff table contains employee details
-- store identifies where each staff member works
/* a staff might have worked in multiple stores but we assume the store 
where they made their last payment in 2017 is their current store for that year */
-- sum each staff’s total revenue (SUM(amount)) for that year
-- determine their last store in 2017 (the store linked to their most recent payment)
-- sort by total revenue descending and show the top 3

WITH staff_revenue AS (
    SELECT 
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment p
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id
),
last_store AS (
    SELECT 
        p.staff_id,
        s.store_id,
        MAX(p.payment_date) AS last_payment_date
    FROM public.payment p
    LEFT JOIN public.staff s ON p.staff_id = s.staff_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id, s.store_id
)
SELECT 
    st.first_name,
    st.last_name,
    ls.store_id,
    sr.total_revenue
FROM staff_revenue sr
LEFT JOIN last_store ls ON sr.staff_id = ls.staff_id
LEFT JOIN public.staff st ON sr.staff_id = st.staff_id
WHERE ls.last_payment_date = (
    SELECT MAX(p2.payment_date)
    FROM payment p2
    WHERE p2.staff_id = ls.staff_id
      AND EXTRACT(YEAR FROM p2.payment_date) = 2017
)
ORDER BY sr.total_revenue DESC
LIMIT 3;

-- staff_revenue sums all payments per staff in 2017
-- last_store finds the last payment per staff in 2017 to determine their store
-- final query joins both and selects the top 3 by total revenue