-- ============================================================================
/* Task 1: Create a view called 'sales_revenue_by_category_qtr' 
   that shows the film category  and total sales revenue for the current quarter and year. 
   The view should only display categories with at least one sale in the current quarter. 

   Note: make it dynamic - when the next quarter begins, it automatically considers that as the current quarter
*/
-- ============================================================================

CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_revenue
FROM 
    payment p
    INNER JOIN rental r ON p.rental_id = r.rental_id
    INNER JOIN inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN film f ON i.film_id = f.film_id
    INNER JOIN film_category fc ON f.film_id = fc.film_id
    INNER JOIN category c ON fc.category_id = c.category_id
WHERE 
    EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
    AND EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY 
    c.name
HAVING 
    SUM(p.amount) > 0
ORDER BY 
    total_revenue DESC;

-- Test the view
SELECT * FROM sales_revenue_by_category_qtr;


-- ============================================================================
/*  Task 2: Create a query language function called 'get_sales_revenue_by_category_qtr' 
    that accepts one parameter representing the current quarter and year and returns
    the same result as the 'sales_revenue_by_category_qtr' view. */
-- ============================================================================

CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(p_quarter INT, p_year INT)
RETURNS TABLE(category VARCHAR, total_revenue NUMERIC) AS $$
BEGIN
    -- Validate quarter parameter
    IF p_quarter < 1 OR p_quarter > 4 THEN
        RAISE EXCEPTION 'Invalid quarter: %. Quarter must be between 1 and 4.', p_quarter;
    END IF;
    
    -- Validate year parameter
    IF p_year < 1900 OR p_year > 2100 THEN
        RAISE EXCEPTION 'Invalid year: %. Year must be between 1900 and 2100.', p_year;
    END IF;
    
    RETURN QUERY
    SELECT 
        c.name::VARCHAR AS category,
        SUM(p.amount) AS total_revenue
    FROM 
        payment p
        INNER JOIN rental r ON p.rental_id = r.rental_id
        INNER JOIN inventory i ON r.inventory_id = i.inventory_id
        INNER JOIN film f ON i.film_id = f.film_id
        INNER JOIN film_category fc ON f.film_id = fc.film_id
        INNER JOIN category c ON fc.category_id = c.category_id
    WHERE 
        EXTRACT(QUARTER FROM p.payment_date) = p_quarter
        AND EXTRACT(YEAR FROM p.payment_date) = p_year
    GROUP BY 
        c.name
    HAVING 
        SUM(p.amount) > 0
    ORDER BY 
        total_revenue DESC;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT * FROM get_sales_revenue_by_category_qtr(1, 2017);


-- ============================================================================
/*  Task 3: Create a procedure language function that takes a country as an input 
 *  parameter and returns the most popular film in that specific country. 
    The function should format the result set as follows:
    Query (example):select * from core.most_popular_films_by_countries(array['Afghanistan','Brazil','United States’]); */

-- ============================================================================

CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(p_countries TEXT[])
RETURNS TABLE(
    country VARCHAR,
    film VARCHAR,
    rating MPAA_RATING,
    language BPCHAR,
    length SMALLINT,
    release_year YEAR
) AS $$
BEGIN
    -- Validate input parameter
    IF p_countries IS NULL OR array_length(p_countries, 1) IS NULL THEN
        RAISE EXCEPTION 'Country array cannot be NULL or empty';
    END IF;
    
    RETURN QUERY
    WITH rental_counts AS (
        SELECT 
            co.country,
            f.film_id,
            f.title AS film,
            f.rating,
            l.name AS language,
            f.length,
            f.release_year,
            COUNT(r.rental_id) AS rental_count,
            ROW_NUMBER() OVER (PARTITION BY co.country ORDER BY COUNT(r.rental_id) DESC, f.title) AS rn
        FROM 
            country co
            INNER JOIN city ci ON co.country_id = ci.country_id
            INNER JOIN address a ON ci.city_id = a.city_id
            INNER JOIN customer cust ON a.address_id = cust.address_id
            INNER JOIN rental r ON cust.customer_id = r.customer_id
            INNER JOIN inventory i ON r.inventory_id = i.inventory_id
            INNER JOIN film f ON i.film_id = f.film_id
            INNER JOIN language l ON f.language_id = l.language_id
        WHERE 
            co.country = ANY(p_countries)
        GROUP BY 
            co.country, f.film_id, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT 
        rc.country::VARCHAR,
        rc.film::VARCHAR,
        rc.rating,
        rc.language,
        rc.length,
        rc.release_year
    FROM 
        rental_counts rc
    WHERE 
        rc.rn = 1
    ORDER BY 
        rc.country;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT * FROM public.most_popular_films_by_countries(ARRAY['Afghanistan','Brazil','United States']);


-- ============================================================================
/*  Task 4: Create a procedure language function that generates a list of movies available 
    in stock based on a partial title match (e.g., movies containing the word 'love' in their title). 
    The titles of these movies are formatted as '%...%', and if a movie with the specified title is not in stock, 
    return a message indicating that it was not found.
    The function should produce the result set in the following format
    (note: the 'row_num' field is an automatically generated counter field, starting from 1 and incrementing for each entry, e.g., 1, 2, ..., 100, 101, ...).

    Query (example):select * from core.films_in_stock_by_title('%love%’); */

-- ============================================================================
DROP FUNCTION films_in_stock_by_title(text);

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(p_title_pattern TEXT)
RETURNS TABLE(
    row_num BIGINT,
    film_id INT,
    title VARCHAR,
    language_name BPCHAR,
    customer_name TEXT,
    rental_date TIMESTAMPTZ
) AS $$
DECLARE
    v_count INT;
BEGIN
    -- Validate input parameter
    IF p_title_pattern IS NULL OR TRIM(p_title_pattern) = '' THEN
        RAISE EXCEPTION 'Title pattern cannot be NULL or empty';
    END IF;
    
    -- Check if any films match the pattern
    SELECT COUNT(*) INTO v_count
    FROM film f
    WHERE f.title ILIKE p_title_pattern;
    
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No films found matching pattern: %', p_title_pattern;
    END IF;
    
    -- Check if any matching films are in stock
    SELECT COUNT(DISTINCT f.film_id) INTO v_count
    FROM film f
    INNER JOIN inventory i ON f.film_id = i.film_id
    LEFT JOIN rental r ON i.inventory_id = r.inventory_id
    WHERE f.title ILIKE p_title_pattern
      AND (r.return_date IS NOT NULL OR r.rental_id IS NULL);
    
    IF v_count = 0 THEN
        RAISE EXCEPTION 'Films matching pattern "%" are not currently in stock', p_title_pattern;
    END IF;
    
    RETURN QUERY
    WITH available_films AS (
        SELECT DISTINCT
            f.film_id,
            f.title,
            l.name AS language_name,
            i.inventory_id,
            r.rental_id,
            r.customer_id,
            r.rental_date,
            r.return_date
        FROM 
            film f
            INNER JOIN language l ON f.language_id = l.language_id
            INNER JOIN inventory i ON f.film_id = i.film_id
            LEFT JOIN rental r ON i.inventory_id = r.inventory_id
        WHERE 
            f.title ILIKE p_title_pattern
            AND (r.return_date IS NOT NULL OR r.rental_id IS NULL)
    ),
    latest_rentals AS (
        SELECT 
            af.film_id,
            af.title,
            af.language_name,
            af.customer_id,
            af.rental_date,
            ROW_NUMBER() OVER (PARTITION BY af.film_id ORDER BY af.rental_date DESC NULLS LAST) AS rn
        FROM 
            available_films af
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY lr.title, lr.film_id) AS row_num,
        lr.film_id::INT,
        lr.title::VARCHAR,
        lr.language_name,
        CASE 
            WHEN lr.customer_id IS NOT NULL THEN 
                (SELECT c.first_name || ' ' || c.last_name 
                 FROM customer c 
                 WHERE c.customer_id = lr.customer_id)
            ELSE NULL
        END AS customer_name,
        lr.rental_date
    FROM 
        latest_rentals lr
    WHERE 
        lr.rn = 1
    ORDER BY 
        lr.title, lr.film_id;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT * FROM public.films_in_stock_by_title('%love%');


-- ============================================================================
/*  Task 5:  Create a procedure language function called 'new_movie' that takes a movie title as a parameter 
    and inserts a new movie with the given title in the film table. 
    The function should generate a new unique film ID, set the rental rate to 4.99, the rental duration to three days, the replacement cost to 19.99. 
    The release year and language are optional and by default should be current year and Klingon respectively. 
    The function should also verify that the language exists in the 'language' table. 
    Then, ensure that no such function has been created before; if so, replace it. */
-- ============================================================================

CREATE OR REPLACE FUNCTION public.new_movie(
    p_title VARCHAR,
    p_release_year INT DEFAULT NULL,
    p_language VARCHAR DEFAULT 'Klingon'
)
RETURNS INT AS $$
DECLARE
    v_new_film_id INT;
    v_language_id INT;
    v_release_year INT;
    v_duplicate_count INT;
BEGIN
    -- Validate title parameter
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be NULL or empty';
    END IF;
    
    -- Set release year to current year if not provided
    v_release_year := COALESCE(p_release_year, EXTRACT(YEAR FROM CURRENT_DATE)::INT);
    
    -- Validate release year
    IF v_release_year < 1900 OR v_release_year > 2100 THEN
        RAISE EXCEPTION 'Invalid release year: %. Year must be between 1900 and 2030.', v_release_year;
    END IF;
    
    -- Check if language exists
    SELECT language_id INTO v_language_id
    FROM language
    WHERE name = p_language;
    
    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in the language table', p_language;
    END IF;
    
    -- Check for duplicate movie (same title and release year)
    SELECT COUNT(*) INTO v_duplicate_count
    FROM film
    WHERE title = p_title 
      AND release_year = v_release_year;
    
    IF v_duplicate_count > 0 THEN
        RAISE EXCEPTION 'Movie "%" with release year % already exists', p_title, v_release_year;
    END IF;
    
    -- Generate new film_id
    SELECT COALESCE(MAX(film_id), 0) + 1 INTO v_new_film_id
    FROM film;
    
    -- Insert new movie
    INSERT INTO film (
        film_id,
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost,
        last_update
    ) VALUES (
        v_new_film_id,
        p_title,
        v_release_year,
        v_language_id,
        3,              -- rental duration: 3 days
        4.99,           -- rental rate: $4.99
        19.99,          -- replacement cost: $19.99
        CURRENT_TIMESTAMP
    );
    
    RETURN v_new_film_id;
END;
$$ LANGUAGE plpgsql;

-- Test the function
-- First, ensure Klingon language exists (add if needed for testing)
INSERT INTO language (name) VALUES ('Klingon') ON CONFLICT DO NOTHING;

-- Test with default parameters
SELECT public.new_movie('How to Train Your Dragon');

-- Test with custom parameters
SELECT public.new_movie('Avatar: Fire and Ash', 2025, 'English');

-- Verify the insertion
SELECT * FROM film WHERE title = 'How to Train Your Dragon';