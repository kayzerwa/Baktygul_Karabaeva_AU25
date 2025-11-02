/* Which actors/actresses didn't act for a longer period of time than the others? 
The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with nostalgic or reliable film stars
The task can be interpreted in various ways, and here are a few options (provide solutions for each one):
V1: gap between the latest release_year and current year per each actor;
V2: gaps between sequential films per each actor; */

/* V1 solution by Subquery: find how long it has been since each actor’s last movie, 
the gap between their latest release year and the current year 2025.
This shows actors who have been inactive recently. */
-- release_year comes from the film table

SELECT 
    a.first_name,
    a.last_name,
    EXTRACT(YEAR FROM CURRENT_DATE) - (
        SELECT MAX(f.release_year)
        FROM public.film_actor fa
        LEFT JOIN public.film f ON f.film_id = fa.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS inactivity_years
FROM public.actor a
ORDER BY inactivity_years DESC;
