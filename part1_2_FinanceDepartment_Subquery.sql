/* The finance department requires a report on store performance to assess profitability
* and plan resource allocation for stores after March 2017. 
* Calculate the revenue earned by each rental store after March 2017 
* (since April) (include columns: address and address2 – as one column, revenue)
*/ 

SELECT 
    s.store_id,
    (a.address || ' ' || COALESCE(a.address2, '')) AS full_address,
    (
        SELECT SUM(p.amount)
        FROM public.payment p
        LEFT JOIN public.rental r ON p.rental_id = r.rental_id
        LEFT JOIN public.inventory i ON r.inventory_id = i.inventory_id
        WHERE i.store_id = s.store_id
          AND p.payment_date >= '2017-04-01'
    ) AS revenue
FROM public.store s
LEFT JOIN address a ON s.address_id = a.address_id
ORDER BY revenue DESC;


-- Subquery is nested logic, fften the slowest approach especially with IN clauses
-- the subquery calculates total revenue for each store inside the SELECT clause
-- it filters payments by date and matches each store’s rentals to payments
-- p.payment_date >= '2017-04-01' captures all payments from April 2017 onward
-- SUM(p.amount) aggregates all payment amounts per store
-- tables used: payment, rental, inventory, store, address
-- combining address fields for clear store identification in reports
-- ORDER BY revenue DESC shows highest-performing stores first