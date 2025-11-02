/* The marketing team needs to track the production trends of Drama, Travel, and Documentary films 
* to inform genre-specific marketing strategies. 
* Show number of Drama, Travel, Documentary per year 
* (include columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies),
* sorted by release year in descending order. Dealing with NULL values is encouraged)
*/

-- film table contains release_year
-- film_category table connects each film to its genre
-- category table contains genre names like “Drama”, “Travel”, “Documentary”
-- count movies per genre for each release year
-- if a genre has no films in a year, show 0 instead of NULL using COALESCE
-- sort by release_year DESC
-- the first subquery aggregates by year and category
-- the outer query pivots it just like in the CTE version

SELECT 
    release_year,
    COALESCE(MAX(CASE WHEN category_name = 'Drama' THEN movie_count END), 0) AS number_of_drama_movies,
    COALESCE(MAX(CASE WHEN category_name = 'Travel' THEN movie_count END), 0) AS number_of_travel_movies,
    COALESCE(MAX(CASE WHEN category_name = 'Documentary' THEN movie_count END), 0) AS number_of_documentary_movies
FROM (
    SELECT 
        f.release_year,
        c.name AS category_name,
        COUNT(f.film_id) AS movie_count
    FROM public.film f
    LEFT JOIN public.film_category fc ON f.film_id = fc.film_id
    LEFT JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary')
    GROUP BY f.release_year, c.name
) AS sub
GROUP BY release_year
ORDER BY release_year DESC;