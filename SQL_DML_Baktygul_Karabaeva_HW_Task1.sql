-- This task adds favorite movies, actors, updates customer data, and 
-- performs rental transactions in a rerunnable manner without creating duplicates
-- ============================================================================

-- SUBTASK 1: Add top-3 favorite movies to the 'film' table
-- ============================================================================

INSERT INTO public.film (
    title, description, release_year, language_id, 
    rental_duration, rental_rate, length, replacement_cost, 
    rating, last_update, special_features
)
SELECT 
	new_films.title, 
	new_films.description, 
	new_films.release_year, 
	lang.language_id, 
	new_films.rental_duration, 
	new_films.rental_rate, 
	new_films.length, 
	new_films.replacement_cost, 
	new_films.rating::mpaa_rating, 
	CURRENT_DATE AS last_update, 
	new_films.special_features::text[]
 FROM (
 	VALUES 
 		('Serendipity', 'A couple reunites years after the night they first met.', 
         2001, 7, 4.99, 90, 19.99, 'PG', ARRAY['Deleted Scenes', 'Behind the Scenes']::text[]),
        ('Interstellar', 'A team travels through a wormhole in search of a new home for humanity.', 
         2014, 14, 9.99, 169, 24.99, 'PG-13', ARRAY['Trailers', 'Commentaries']::text[]),
        ('The Matrix', 'A hacker discovers the truth about reality.', 
         1999, 21, 19.99, 136, 29.99, 'R', ARRAY['Trailers', 'Commentaries']::text[])
 
 ) AS new_films(title, description, release_year, rental_duration, rental_rate, 
               length, replacement_cost, rating, special_features)
 LEFT JOIN (SELECT language_id FROM public.language WHERE LOWER(name) = 'english' LIMIT 1) AS lang ON TRUE 
 WHERE NOT EXISTS (
 		SELECT 1 FROM public.film WHERE film.title = new_films.title
 )
 RETURNING film_id, title, rental_rate, rental_duration;
 
 COMMIT;


-- SUBTASK 2: Add real actors to 'actor' table
-- ====================================================
 
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT v.first_name, v.last_name, CURRENT_DATE
FROM (
    VALUES
        ('John', 'Cusack'),
        ('Kate', 'Beckinsale'),
        ('Matthew', 'McConaughey'),
        ('Anne', 'Hathaway'),
        ('Keanu', 'Reeves'),
        ('Laurence', 'Fishburne')
) AS v(first_name, last_name)
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor a
    WHERE LOWER(a.first_name) = LOWER(v.first_name)
      AND LOWER(a.last_name)  = LOWER(v.last_name)
)
RETURNING actor_id, first_name, last_name;

COMMIT;

-- SUBTASK 3: Link actors to films in 'film_actor' table
-- ============================================================================

-- Link John Cusack and Kate Beckinsale to Serendipity
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
INNER JOIN public.film f 
  ON LOWER(f.title) = 'serendipity'
WHERE (LOWER(a.first_name), LOWER(a.last_name)) IN (
        ('john', 'cusack'),
        ('kate', 'beckinsale')
      )
  AND NOT EXISTS (
        SELECT 1 
        FROM public.film_actor fa
        WHERE fa.actor_id = a.actor_id
          AND fa.film_id = f.film_id
      )
RETURNING actor_id, film_id;


-- Link Matthew McConaughey and Anne Hathaway to Interstellar
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
INNER JOIN public.film f 
       ON LOWER(f.title) = 'interstellar'
WHERE (LOWER(a.first_name), LOWER(a.last_name)) IN (
        ('matthew', 'mcconaughey'),
        ('anne', 'hathaway')
      )
  AND NOT EXISTS (
        SELECT 1 
        FROM public.film_actor fa
        WHERE fa.actor_id = a.actor_id
          AND fa.film_id = f.film_id
      )
RETURNING actor_id, film_id;


-- Link Keanu Reeves and Laurence Fishburne to The Matrix
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
INNER JOIN public.film f 
       ON LOWER(f.title) = 'the matrix'
WHERE (LOWER(a.first_name), LOWER(a.last_name)) IN (
        ('keanu', 'reeves'),
        ('laurence', 'fishburne')
      )
  AND NOT EXISTS (
        SELECT 1 
        FROM public.film_actor fa
        WHERE fa.actor_id = a.actor_id
          AND fa.film_id = f.film_id
      )
RETURNING actor_id, film_id;

COMMIT;

-- SUBTASK 4: Add movies to store inventory
-- ============================================================================

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, s.store_id, CURRENT_DATE
FROM public.film f
INNER JOIN (
    SELECT store_id 
    FROM public.store 
    ORDER BY store_id 
    LIMIT 1
) s ON TRUE
WHERE LOWER(f.title) IN ('serendipity', 'interstellar', 'the matrix')
  AND NOT EXISTS (
        SELECT 1 
        FROM public.inventory i
        WHERE i.film_id = f.film_id
          AND i.store_id = s.store_id
  )
RETURNING inventory_id, film_id, store_id;


COMMIT;

-- SUBTASK 5: Find and update customer with 43+ rentals and payments
-- ============================================================================

SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    COUNT(DISTINCT r.rental_id) as rental_count,
    COUNT(DISTINCT p.payment_id) as payment_count
FROM public.customer c
LEFT JOIN public.rental r ON c.customer_id = r.customer_id
LEFT JOIN public.payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
HAVING COUNT(DISTINCT r.rental_id) >= 43 
   AND COUNT(DISTINCT p.payment_id) >= 43
ORDER BY rental_count DESC, payment_count DESC
LIMIT 1;

-- Update the customer record with personal information

UPDATE public.customer
SET 
    first_name   = 'Baktygul',
    last_name    = 'Karabaeva',
    email        = 'baktygul.karabaeva@example.com',
    store_id     = (SELECT store_id FROM public.store ORDER BY store_id LIMIT 1),
    address_id   = (SELECT address_id FROM public.address ORDER BY address_id LIMIT 1),
    activebool   = TRUE,
    create_date  = CURRENT_DATE,
    last_update  = CURRENT_TIMESTAMP,
    active       = 1
WHERE customer_id = (
    SELECT c.customer_id
    FROM public.customer c
    LEFT JOIN public.rental r  ON c.customer_id = r.customer_id
    LEFT JOIN public.payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
    HAVING COUNT(DISTINCT r.rental_id) >= 43 
       AND COUNT(DISTINCT p.payment_id) >= 43
    ORDER BY COUNT(DISTINCT r.rental_id) DESC,
             COUNT(DISTINCT p.payment_id) DESC
    LIMIT 1
)
RETURNING customer_id, first_name, last_name, email, store_id, address_id, activebool, create_date, last_update, active;

COMMIT;

-- SUBTASK 6: Remove existing rental and payment records for the customer
-- ============================================================================

-- First, let's see what we're about to delete:
SELECT 'Payments to delete:' as description, COUNT(*) as count
FROM public.payment
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = 'baktygul' AND LOWER(last_name) = 'karabaeva'
    LIMIT 1
);
COMMIT;

SELECT 'Rentals to delete:' as description, COUNT(*) as count
FROM public.rental
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = 'baktygul' AND LOWER(last_name) = 'karabaeva'
);
COMMIT;

-- Delete payments first (due to foreign key constraints)
DELETE FROM public.payment
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = 'baktygul' AND LOWER(last_name) = 'karabaeva'
    LIMIT 1
)
RETURNING payment_id, customer_id, amount;
COMMIT;

-- Delete rentals
DELETE FROM public.rental
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = 'baktygul' AND LOWER(last_name) = 'karabaeva'
    LIMIT 1
)
RETURNING rental_id, customer_id, rental_date;

COMMIT;

-- SUBTASK 7: Rent the favorite movies and create payment records
-- ============================================================================

INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT DISTINCT ON (f.film_id)
    timestamp '2017-01-01' + (random() * INTERVAL '1 month') + (random() * INTERVAL '24 hours'),
    i.inventory_id,
    c.customer_id,
    NULL,
    s.staff_id,
    CURRENT_TIMESTAMP
FROM public.film f
INNER JOIN public.inventory i ON i.film_id = f.film_id
INNER JOIN public.store st ON st.store_id = i.store_id
INNER JOIN public.staff s ON s.store_id = st.store_id
CROSS JOIN public.customer c
WHERE LOWER(f.title) IN ('serendipity', 'interstellar', 'the matrix')
  AND LOWER(c.first_name) = 'baktygul'
  AND LOWER(c.last_name) = 'karabaeva'
RETURNING rental_id, rental_date, inventory_id, customer_id;

COMMIT;


-- Payments for the rentals just created
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
    r.customer_id,
    r.staff_id,
    r.rental_id,
    f.rental_rate,
    r.rental_date
FROM public.rental r
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
INNER JOIN public.customer c ON r.customer_id = c.customer_id
WHERE LOWER(c.first_name) = 'baktygul'
  AND LOWER(c.last_name) = 'karabaeva'
  AND NOT EXISTS (
        SELECT 1 FROM public.payment p
        WHERE p.rental_id = r.rental_id
)
RETURNING payment_id, rental_id, amount, payment_date;

COMMIT;

-- ============================================================================
-- Verifying the queries that all data was inserted correctly
-- ============================================================================

-- Check films were added
SELECT film_id, title, rental_rate, rental_duration 
FROM public.film 
WHERE LOWER(title) IN ('serendipity', 'interstellar', 'the matrix');

-- Check actors were added
SELECT actor_id, first_name, last_name 
FROM public.actor 
WHERE LOWER(last_name) IN ('cusack', 'beckinsale', 'mcconaughey', 'hathaway', 'reeves', 'fishburne');

-- Check film-actor relationships
SELECT f.title, a.first_name, a.last_name
FROM public.film_actor fa
INNER JOIN public.film f ON fa.film_id = f.film_id
INNER JOIN public.actor a ON fa.actor_id = a.actor_id
WHERE LOWER(f.title) IN ('serendipity', 'interstellar', 'the matrix')
ORDER BY f.title, a.last_name;

-- Check inventory
SELECT i.inventory_id, f.title, i.store_id
FROM public.inventory i
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(f.title) IN ('serendipity', 'interstellar', 'the matrix');

-- Check customer update and rentals
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(r.rental_id) as rental_count,
    COUNT(p.payment_id) as payment_count
FROM public.customer c
LEFT JOIN public.rental r ON c.customer_id = r.customer_id
LEFT JOIN public.payment p ON c.customer_id = p.customer_id
WHERE LOWER(c.first_name) = 'baktygul' AND LOWER(c.last_name) = 'karabaeva'
GROUP BY c.customer_id, c.first_name, c.last_name;

-- Check rental details for your movies
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    f.title,
    r.rental_date,
    p.amount,
    p.payment_date
FROM public.rental r
INNER JOIN public.customer c ON r.customer_id = c.customer_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
LEFT JOIN public.payment p ON r.rental_id = p.rental_id
WHERE LOWER(c.first_name) = 'baktygul' AND LOWER(c.last_name) = 'karabaeva'
ORDER BY r.rental_date;