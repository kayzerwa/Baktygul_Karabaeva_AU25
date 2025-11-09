/* The marketing department in our stores aims to identify the most successful actors 
* since 2015 to boost customer interest in their films. 
* Show top-5 actors by number of movies (released after 2015) they took part in 
* (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
*/

SELECT 
    a.first_name,
    a.last_name,
    COUNT(f.film_id) AS number_of_movies
FROM public.actor a
LEFT JOIN public.film_actor fa ON a.actor_id = fa.actor_id
LEFT JOIN public.film f ON fa.film_id = f.film_id
WHERE f.release_year > 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC
LIMIT 5;


-- films released after 2015, 3 tables used
-- count how many films each actor participated in
-- display top 5 actors with the highest number of movies
-- sort results by number_of_movies descending
-- JOIN solution is the simplest form, directly joining and grouping without a CTE or subquery. 
-- Single-step aggregation, simple and efficient