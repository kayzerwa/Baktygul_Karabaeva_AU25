/* Which actors/actresses didn't act for a longer period of time than the others? 
The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with nostalgic or reliable film stars
The task can be interpreted in various ways, and here are a few options (provide solutions for each one):
V1: gap between the latest release_year and current year per each actor;
V2: gaps between sequential films per each actor; */

/* V2 solution by CTE: find gaps between sequential movies for each actor, 
 how many years passed between two consecutive films they acted in.
 This helps identify actors with irregular careers (big breaks between movies). */
-- calculate differences between all pairs of movies for each actor
-- find all combinations of a later film and an earlier film and compute their year difference
-- sorts by actor ID and release year

WITH actor_films AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        f.film_id,
        f.title,
        f.release_year
    FROM public.actor a
    JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    JOIN public.film f ON fa.film_id = f.film_id
),
film_pairs AS (
    SELECT 
        af1.actor_id,
        af1.first_name,
        af1.last_name,
        af1.title AS previous_film,
        af1.release_year AS previous_year,
        af2.title AS next_film,
        af2.release_year AS next_year
    FROM actor_films af1
    JOIN actor_films af2 
      ON af1.actor_id = af2.actor_id
     AND af2.release_year > af1.release_year
    WHERE NOT EXISTS (
        SELECT 1
        FROM actor_films af3
        WHERE af3.actor_id = af1.actor_id
          AND af3.release_year > af1.release_year
          AND af3.release_year < af2.release_year
    )
)
SELECT 
    actor_id,
    first_name,
    last_name,
    previous_film,
    previous_year,
    next_film,
    next_year,
    COALESCE(next_year - previous_year, 0) AS gap_years
FROM film_pairs
ORDER BY actor_id, previous_year;


   
    


