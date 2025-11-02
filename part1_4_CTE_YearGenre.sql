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
-- the CTE first counts how many movies exist per year and genre
-- the outer query pivots that data into three columns using CASE and MAX()
-- COALESCE replaces NULLs with 0

WITH genre_per_year AS (
    SELECT 
        f.release_year,
        c.name AS category_name,
        COUNT(f.film_id) AS movie_count
    FROM public.film f
    LEFT JOIN public.film_category fc ON f.film_id = fc.film_id
    LEFT JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary')
    GROUP BY f.release_year, c.name
)
SELECT 
    g.release_year,
    COALESCE(MAX(CASE WHEN g.category_name = 'Drama' THEN g.movie_count END), 0) AS number_of_drama_movies,
    COALESCE(MAX(CASE WHEN g.category_name = 'Travel' THEN g.movie_count END), 0) AS number_of_travel_movies,
    COALESCE(MAX(CASE WHEN g.category_name = 'Documentary' THEN g.movie_count END), 0) AS number_of_documentary_movies
FROM genre_per_year g
GROUP BY g.release_year
ORDER BY g.release_year DESC;