/*The marketing team needs a list of animation movies between 2017 and 2019 
 * to promote family-friendly content in an upcoming season in stores. 
 * Show all animation movies released during this period with rate more than 1, 
 * sorted alphabetically
 */

SELECT 
    f.title,
    f.release_year,
    f.rental_rate
FROM public.film f
WHERE f.film_id IN (
    SELECT fc.film_id
    FROM public.film_category fc
    LEFT JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name = 'Animation'
        AND f.release_year BETWEEN 2017 AND 2019
        AND f.rental_rate > 1
)
ORDER BY f.title;

-- Subquery solution: nested logic, can be difficult to read multiple nested subqueries
-- target: animation genre, film->film_category->category => 3 tables engaged
-- release_year between 2017 and 2019 (inclusive)
-- family-friendly filtering - exclude adult/inappropriate content
-- sorted alphabetically
-- for the promotion selected columns: title, release_year, rental_rate