/* The management team wants to identify the most popular movies
and their target audience age groups to optimize marketing efforts. 
Show which 5 movies were rented more than others (number of rentals),
and what's the expected age of the audience for these movies? 
To determine expected age please use 'Motion Picture Association film rating system'*/

-- identify the most rented movies and understand their target age group
-- film table contains movie info (film_id, title, rating)
-- inventory table links films to physical copies
-- rental table records each rental transaction
-- count rentals per film, number of rows in rental per film_id via inventory
-- sort by number of rentals and pick top 5
-- assign expected audience age based on the MPAA rating using a mapping:
-- 'G' for all ages, 'PG' for 10+, 'PG-13' for 13+, 'R' for 17+, 'NC-17' for 18+
-- JOIN solution is the simplest and fastest when readability is not a priority

SELECT 
    f.title,
    f.rating,
    COUNT(r.rental_id) AS number_of_rentals,
    CASE 
        WHEN f.rating = 'G' THEN 'All Ages'
        WHEN f.rating = 'PG' THEN '10+'
        WHEN f.rating = 'PG-13' THEN '13+'
        WHEN f.rating = 'R' THEN '17+'
        WHEN f.rating = 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_age_group
FROM public.film f
LEFT JOIN public.inventory i ON f.film_id = i.film_id
LEFT JOIN public.rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.rating
HAVING COUNT(r.rental_id) > 0
ORDER BY COUNT(r.rental_id) DESC
LIMIT 5;