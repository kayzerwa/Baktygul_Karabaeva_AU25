/* Which actors/actresses didn't act for a longer period of time than the others? 
The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with nostalgic or reliable film stars
The task can be interpreted in various ways, and here are a few options (provide solutions for each one):
V1: gap between the latest release_year and current year per each actor;
V2: gaps between sequential films per each actor; */

/* V1 solution by JOIN: find how long it has been since each actor’s last movie, 
the gap between their latest release year and the current year 2025.
This shows actors who have been inactive recently. */
-- release_year comes from the film table

SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    lf.latest_release_year,
    COALESCE(EXTRACT(YEAR FROM CURRENT_DATE) - lf.latest_release_year, 0) AS gap_years
FROM public.actor a
INNER JOIN (
    SELECT 
        fa.actor_id,
        MAX(f.release_year) AS latest_release_year
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY fa.actor_id
) AS lf ON a.actor_id = lf.actor_id
ORDER BY gap_years DESC, a.last_name, a.first_name
LIMIT 10;
