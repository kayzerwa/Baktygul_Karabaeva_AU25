/* Which actors/actresses didn't act for a longer period of time than the others? 
The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with nostalgic or reliable film stars
The task can be interpreted in various ways, and here are a few options (provide solutions for each one):
V1: gap between the latest release_year and current year per each actor;
V2: gaps between sequential films per each actor; */

/* V2 solution by JOIN: find gaps between sequential movies for each actor, 
 how many years passed between two consecutive films they acted in.
 This helps identify actors with irregular careers (big breaks between movies). */
-- calculate differences between all pairs of movies for each actor
-- find all combinations of a later film and an earlier film and compute their year difference
-- sorts by actor ID and release year
 
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    f1.title  AS previous_film,
    f1.release_year AS previous_year,
    f2.title  AS next_film,
    f2.release_year AS next_year,
    COALESCE((f2.release_year - f1.release_year),0) AS gap_years
FROM public.actor a
LEFT JOIN public.film_actor fa1 ON a.actor_id = fa1.actor_id
LEFT JOIN public.film f1 ON fa1.film_id = f1.film_id
LEFT JOIN public.film_actor fa2 ON a.actor_id = fa2.actor_id
LEFT JOIN public.film f2 ON fa2.film_id = f2.film_id
WHERE f2.release_year > f1.release_year
  AND NOT EXISTS (
        SELECT 1
        FROM film_actor fa3
        JOIN film f3 ON fa3.film_id = f3.film_id
        WHERE fa3.actor_id = a.actor_id
          AND f3.release_year > f1.release_year
          AND f3.release_year < f2.release_year
    )
ORDER BY a.actor_id, f1.release_year;