-- This task adds favorite movies, actors, updates customer data, and 
-- performs rental transactions in a rerunnable manner without creating duplicates
-- ============================================================================

-- SUBTASK 1: Add top-3 favorite movies to the 'film' table
-- ============================================================================

-- Movie 1: Serendipity (2001)
INSERT INTO public.film (
    title, description, release_year, language_id, 
    rental_duration, rental_rate, length, replacement_cost, 
    rating, last_update, special_features
)
SELECT 
    'Serendipity',
    'A couple reunites years after the night they first met.',
    2001,
    1, -- English language_id
    7, -- 1 week (7 days)
    4.99,
    90, -- runtime in minutes
    19.99,
    'PG',
    CURRENT_DATE,
    '{"Deleted Scenes","Behind the Scenes"}'
    
WHERE NOT EXISTS (
    SELECT 1 FROM public.film WHERE title = 'Serendipity'
)
RETURNING film_id, title, rental_rate, rental_duration;

-- Movie 2: Interstellar (2014)
INSERT INTO public.film (
    title, description, release_year, language_id, 
    rental_duration, rental_rate, length, replacement_cost, 
    rating, last_update, special_features
)
SELECT 
    'Interstellar',
    'A team travels through a wormhole in search of a new home for humanity.',
    2014,
    1, -- English language_id
    14, -- 2 weeks (14 days)
    9.99,
    169, -- runtime in minutes
    24.99,
    'PG-13',
    CURRENT_DATE,
    '{"Trailers","Commentaries"}'
    
WHERE NOT EXISTS (
    SELECT 1 FROM public.film WHERE title = 'Interstellar'
)
RETURNING film_id, title, rental_rate, rental_duration;

-- Movie 3: The Matrix (1999)
INSERT INTO public.film (
    title, description, release_year, language_id, 
    rental_duration, rental_rate, length, replacement_cost, 
    rating, last_update, special_features
)
SELECT 
    'The Matrix',
    'A hacker discovers the truth about reality.',
    1999,
    1, -- English language_id
    21, -- 3 weeks (21 days)
    19.99,
    136, -- runtime in minutes
    29.99,
    'R',
    CURRENT_DATE,
    '{"Trailers","Commentaries"}'
    
WHERE NOT EXISTS (
    SELECT 1 FROM public.film WHERE title = 'The Matrix'
)
RETURNING film_id, title, rental_rate, rental_duration;

COMMIT;

-- SUBTASK 2: Add real actors to 'actor' table
-- ============================================================================

-- Actors from Serendipity
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'John', 'Cusack', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE first_name = 'John' AND last_name = 'Cusack'
)
RETURNING actor_id, first_name, last_name;

INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'Kate', 'Beckinsale', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE first_name = 'Kate' AND last_name = 'Beckinsale'
)
RETURNING actor_id, first_name, last_name;

-- Actors from Interstellar
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'Matthew', 'McConaughey', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE first_name = 'Matthew' AND last_name = 'McConaughey'
)
RETURNING actor_id, first_name, last_name;

INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'Anne', 'Hathaway', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE first_name = 'Anne' AND last_name = 'Hathaway'
)
RETURNING actor_id, first_name, last_name;

-- Actors from The Matrix
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'Keanu', 'Reeves', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE first_name = 'Keanu' AND last_name = 'Reeves'
)
RETURNING actor_id, first_name, last_name;

INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'Laurence', 'Fishburne', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE first_name = 'Laurence' AND last_name = 'Fishburne'
)
RETURNING actor_id, first_name, last_name;

COMMIT;

-- SUBTASK 3: Link actors to films in 'film_actor' table
-- ============================================================================

-- Link John Cusack and Kate Beckinsale to Serendipity
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
CROSS JOIN public.film f
WHERE a.first_name = 'John' AND a.last_name = 'Cusack'
  AND f.title = 'Serendipity'
  AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
CROSS JOIN public.film f
WHERE a.first_name = 'Kate' AND a.last_name = 'Beckinsale'
  AND f.title = 'Serendipity'
  AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

-- Link Matthew McConaughey and Anne Hathaway to Interstellar
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
CROSS JOIN public.film f
WHERE a.first_name = 'Matthew' AND a.last_name = 'McConaughey'
  AND f.title = 'Interstellar'
  AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
CROSS JOIN public.film f
WHERE a.first_name = 'Anne' AND a.last_name = 'Hathaway'
  AND f.title = 'Interstellar'
  AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

-- Link Keanu Reeves and Laurence Fishburne to The Matrix
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
CROSS JOIN public.film f
WHERE a.first_name = 'Keanu' AND a.last_name = 'Reeves'
  AND f.title = 'The Matrix'
  AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
CROSS JOIN public.film f
WHERE a.first_name = 'Laurence' AND a.last_name = 'Fishburne'
  AND f.title = 'The Matrix'
  AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

COMMIT;

-- SUBTASK 4: Add movies to store inventory
-- ============================================================================

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, 1, CURRENT_DATE
FROM public.film f
WHERE f.title = 'Serendipity'
  AND NOT EXISTS (
    SELECT 1 FROM public.inventory i 
    WHERE i.film_id = f.film_id AND i.store_id = 1
)
RETURNING inventory_id, film_id, store_id;

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, 1, CURRENT_DATE
FROM public.film f
WHERE f.title = 'Interstellar'
  AND NOT EXISTS (
    SELECT 1 FROM public.inventory i 
    WHERE i.film_id = f.film_id AND i.store_id = 1
)
RETURNING inventory_id, film_id, store_id;

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, 1, CURRENT_DATE
FROM public.film f
WHERE f.title = 'The Matrix'
  AND NOT EXISTS (
    SELECT 1 FROM public.inventory i 
    WHERE i.film_id = f.film_id AND i.store_id = 1
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
    first_name = 'Baktygul',  
    last_name = 'Karabaeva',    
    email = 'baktygul.karabaeva@example.com', 
    last_update = CURRENT_DATE
WHERE customer_id = (
    SELECT c.customer_id
    FROM public.customer c
    LEFT JOIN public.rental r ON c.customer_id = r.customer_id
    LEFT JOIN public.payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
    HAVING COUNT(DISTINCT r.rental_id) >= 43 
       AND COUNT(DISTINCT p.payment_id) >= 43
    ORDER BY COUNT(DISTINCT r.rental_id) DESC, COUNT(DISTINCT p.payment_id) DESC
    LIMIT 1
)
RETURNING customer_id, first_name, last_name, email;

COMMIT;

-- SUBTASK 6: Remove existing rental and payment records for the customer
-- ============================================================================

-- First, let's see what we're about to delete:
SELECT 'Payments to delete:' as description, COUNT(*) as count
FROM public.payment
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = LOWER('Baktygul') AND LOWER(last_name) = LOWER('Karabaeva')
)
UNION ALL
SELECT 'Rentals to delete:' as description, COUNT(*) as count
FROM public.rental
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = LOWER('Baktygul') AND LOWER(last_name) = LOWER('Karabaeva')
);

-- Delete payments first (due to foreign key constraints)
DELETE FROM public.payment
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = LOWER('Baktygul') AND LOWER(last_name) = LOWER('Karabaeva')
)
RETURNING payment_id, customer_id, amount;

-- Delete rentals
DELETE FROM public.rental
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE LOWER(first_name) = LOWER('Baktygul') AND LOWER(last_name) = LOWER('Karabaeva')
)
RETURNING rental_id, customer_id, rental_date;

COMMIT;

-- SUBTASK 7: Rent the favorite movies and create payment records
-- ============================================================================

-- Rent "Serendipity"
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT 
    '2017-06-01 10:00:00'::timestamp, -- Using 2017 date for partition compatibility
    i.inventory_id,
    c.customer_id,
    NULL, -- Not returned yet
    1, -- staff_id = 1
    CURRENT_DATE
FROM public.inventory i
CROSS JOIN public.customer c
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(f.title) = LOWER('Serendipity')
  AND LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva')
  AND i.store_id = 1
  AND NOT EXISTS (
    SELECT 1 FROM public.rental r 
    WHERE r.inventory_id = i.inventory_id 
      AND r.customer_id = c.customer_id
      AND r.rental_date = '2017-06-01 10:00:00'::timestamp
)
LIMIT 1
RETURNING rental_id, rental_date, inventory_id, customer_id;

-- Rent "Interstellar"
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT 
    '2017-06-01 11:00:00'::timestamp,
    i.inventory_id,
    c.customer_id,
    NULL,
    1,
    CURRENT_DATE
FROM public.inventory i
CROSS JOIN public.customer c
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(f.title) = LOWER('Interstellar')
  AND LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva')
  AND i.store_id = 1
  AND NOT EXISTS (
    SELECT 1 FROM public.rental r 
    WHERE r.inventory_id = i.inventory_id 
      AND r.customer_id = c.customer_id
      AND r.rental_date = '2017-06-01 11:00:00'::timestamp
)
LIMIT 1
RETURNING rental_id, rental_date, inventory_id, customer_id;

-- Rent "The Matrix"
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT 
    '2017-06-01 12:00:00'::timestamp,
    i.inventory_id,
    c.customer_id,
    NULL,
    1,
    CURRENT_DATE
FROM public.inventory i
CROSS JOIN public.customer c
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(f.title) = LOWER('The Matrix')
  AND LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva')
  AND i.store_id = 1
  AND NOT EXISTS (
    SELECT 1 FROM public.rental r 
    WHERE r.inventory_id = i.inventory_id 
      AND r.customer_id = c.customer_id
      AND r.rental_date = '2017-06-01 12:00:00'::timestamp
)
LIMIT 1
RETURNING rental_id, rental_date, inventory_id, customer_id;

COMMIT;

-- Create payment records for the rentals
-- ============================================================================

-- Payment for "Serendipity" rental
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
    c.customer_id,
    1, -- staff_id
    r.rental_id,
    4.99, -- rental rate for this film
    '2017-06-01 10:00:00'::timestamp
FROM public.customer c
INNER JOIN public.rental r ON c.customer_id = r.customer_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva')
  AND LOWER(f.title) = LOWER('Serendipity')
  AND r.rental_date = '2017-06-01 10:00:00'::timestamp
  AND NOT EXISTS (
    SELECT 1 FROM public.payment p 
    WHERE p.rental_id = r.rental_id
)
RETURNING payment_id, rental_id, amount, payment_date;

-- Payment for "Interstellar" rental
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
    c.customer_id,
    1,
    r.rental_id,
    9.99,
    '2017-06-01 11:00:00'::timestamp
FROM public.customer c
INNER JOIN public.rental r ON c.customer_id = r.customer_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva') 
  AND LOWER(f.title) = LOWER('Interstellar')
  AND r.rental_date = '2017-06-01 11:00:00'::timestamp
  AND NOT EXISTS (
    SELECT 1 FROM public.payment p 
    WHERE p.rental_id = r.rental_id
)
RETURNING payment_id, rental_id, amount, payment_date;

-- Payment for "The Matrix" rental
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
    c.customer_id,
    1,
    r.rental_id,
    19.99,
    '2017-06-01 12:00:00'::timestamp
FROM public.customer c
INNER JOIN public.rental r ON c.customer_id = r.customer_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva')
  AND LOWER(f.title) = LOWER('The Matrix')
  AND r.rental_date = '2017-06-01 12:00:00'::timestamp
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
WHERE LOWER(title) IN (LOWER('Serendipity'), LOWER('Interstellar'), LOWER('The Matrix'));

-- Check actors were added
SELECT actor_id, first_name, last_name 
FROM public.actor 
WHERE LOWER(last_name) IN (LOWER('Cusack'), LOWER('Beckinsale'), LOWER('McConaughey'), LOWER('Hathaway'), LOWER('Reeves'), LOWER('Fishburne'));

-- Check film-actor relationships
SELECT f.title, a.first_name, a.last_name
FROM public.film_actor fa
INNER JOIN public.film f ON fa.film_id = f.film_id
INNER JOIN public.actor a ON fa.actor_id = a.actor_id
WHERE LOWER(f.title) IN (LOWER('Serendipity'), LOWER('Interstellar'), LOWER('The Matrix'))
ORDER BY f.title, a.last_name;

-- Check inventory
SELECT i.inventory_id, f.title, i.store_id
FROM public.inventory i
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE LOWER(f.title) IN (LOWER('Serendipity'), LOWER('Interstellar'), LOWER('The Matrix'));

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
WHERE LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva')
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
WHERE LOWER(c.first_name) = LOWER('Baktygul') AND LOWER(c.last_name) = LOWER('Karabaeva')
ORDER BY r.rental_date;