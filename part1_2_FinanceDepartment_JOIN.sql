/* The finance department requires a report on store performance to assess profitability
* and plan resource allocation for stores after March 2017. 
* Calculate the revenue earned by each rental store after March 2017 
* (since April) (include columns: address and address2 – as one column, revenue)
*/ 

SELECT 
    s.store_id,
    (a.address || ' ' || COALESCE(a.address2, '')) AS full_address,
    SUM(p.amount) AS revenue
FROM public.payment p
LEFT JOIN public.rental r ON p.rental_id = r.rental_id
LEFT JOIN public.inventory i ON r.inventory_id = i.inventory_id
LEFT JOIN public.store s ON i.store_id = s.store_id
LEFT JOIN public.address a ON s.address_id = a.address_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY s.store_id, a.address, a.address2
ORDER BY revenue DESC;


-- JOIN solution is simple, performant and readable
-- p.payment_date >= '2017-04-01' captures all payments from April 2017 onward
-- SUM(p.amount) aggregates all payment amounts per store
-- table connection: payment → rental → inventory → store → address to connect payments to physical stores
-- combining address fields for clear store identification in reports
-- ORDER BY revenue DESC shows highest-performing stores first
