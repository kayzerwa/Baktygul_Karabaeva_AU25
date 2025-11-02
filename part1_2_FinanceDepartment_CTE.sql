/* The finance department requires a report on store performance to assess profitability
* and plan resource allocation for stores after March 2017. 
* Calculate the revenue earned by each rental store after March 2017 
* (since April) (include columns: address and address2 – as one column, revenue)
*/ 

WITH store_revenue AS (
    SELECT 
        i.store_id,
        SUM(p.amount) AS revenue
    FROM public.payment p
    LEFT JOIN public.rental r ON p.rental_id = r.rental_id
    LEFT JOIN public.inventory i ON r.inventory_id = i.inventory_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
)
SELECT 
    s.store_id,
    (a.address || ' ' || COALESCE(a.address2, '')) AS full_address,
    sr.revenue
FROM public.store s
LEFT JOIN public.address a ON s.address_id = a.address_id
LEFT JOIN store_revenue sr ON s.store_id = sr.store_id
ORDER BY sr.revenue DESC;


-- CTE is a structured approach, for complex multi-step queries
-- store_revenue first aggregates revenue per store after March 2017
-- the main query joins it with the store and address tables to include the full address
-- p.payment_date >= '2017-04-01' captures all payments from April 2017 onward
-- SUM(p.amount) aggregates all payment amounts per store
-- tables used: payment, rental, inventory, store, address
-- combining address fields for clear store identification in reports
-- ORDER BY revenue DESC shows highest-performing stores first