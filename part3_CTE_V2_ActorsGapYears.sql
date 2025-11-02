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

WITH actor_films AS (
    SELECT a.actor_id, a.first_name, a.last_name, f.release_year
    FROM public.actor a
    JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    JOIN public.film f ON f.film_id = fa.film_id
),
gaps AS (
    SELECT 
        f1.actor_id,
        f1.first_name,
        f1.last_name,
        MAX(f2.release_year - f1.release_year) AS max_gap
    FROM actor_films f1
    JOIN actor_films f2 
        ON f1.actor_id = f2.actor_id
       AND f2.release_year > f1.release_year
    GROUP BY f1.actor_id, f1.first_name, f1.last_name
)
SELECT * FROM gaps ORDER BY max_gap DESC;