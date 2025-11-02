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
-- join solution directly joins all three tables and counts films per year

SELECT 
    f.release_year,
    COALESCE(SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
    COALESCE(SUM(CASE WHEN c.name = 'Travel' THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
    COALESCE(SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM public.film f
LEFT JOIN public.film_category fc ON f.film_id = fc.film_id
LEFT JOIN public.category c ON fc.category_id = c.category_id
WHERE c.name IN ('Drama', 'Travel', 'Documentary')
GROUP BY f.release_year
ORDER BY f.release_year DESC;

