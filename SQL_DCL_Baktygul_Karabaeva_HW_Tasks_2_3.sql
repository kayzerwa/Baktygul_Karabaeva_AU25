
-- Role-Based Authentication and Row-Level Security Tasks
-- TASK 2.1: Create rentaluser with connection privileges only
-- ============================================================================

-- Create the user

DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'rentaluser') THEN

      RAISE NOTICE 'Role "rentaluser" already exists. Skipping.';
   ELSE
      CREATE USER rentaluser WITH PASSWORD 'rentalpassword';
   END IF;
END
$do$;

-- Grant connection privilege to the database
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

-- Verify user creation
SELECT usename, usecreatedb, usesuper 
FROM pg_user 
WHERE usename = 'rentaluser';

-- TASK 2.2: Grant SELECT permission on customer table and verify
-- ============================================================================

-- Grant USAGE on the schema (required to access objects in the schema)
GRANT USAGE ON SCHEMA public TO rentaluser;

-- Grant SELECT permission on customer table
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- Verification query to show what permissions rentaluser has
SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'rentaluser' AND table_schema = 'public';

-- Test query (run as rentaluser)
-- Switch to rentaluser to test permissions
/*SET ROLE rentaluser;

-- Test SELECT on customer table

SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.active
FROM public.customer c
ORDER BY c.customer_id
LIMIT 5;


RESET ROLE;*/

-- TASK 2.3: Create rental group and add rentaluser
-- ============================================================================

-- Create the rental group (role) & add rentaluser to the rental group

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'rental'
    ) THEN
        CREATE ROLE rental;
		GRANT rental TO rentaluser;
    END IF;
END$$;


-- Verify group membership
SELECT 
    r.rolname as group_role,
    m.rolname as member_role
FROM pg_roles r
INNER JOIN pg_auth_members am ON r.oid = am.roleid
INNER JOIN pg_roles m ON am.member = m.oid
WHERE r.rolname = 'rental';

-- TASK 2.4: Grant INSERT and UPDATE to rental group, then test
-- ============================================================================

-- Grant USAGE on schema to the rental group
GRANT USAGE ON SCHEMA public TO rental;

-- Grant INSERT and UPDATE permissions on rental table
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

-- Grant USAGE on sequences (needed for INSERT with auto-increment columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rental;

-- Grant SELECT permission on ALL tables (needed to read from other tables)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rental;

-- Switch to rentaluser (who is member of rental group)
SET ROLE rentaluser;

-- Test INSERT: Add a new rental record
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT DISTINCT ON (f.film_id)
    timestamp '2020-01-01' + (random() * INTERVAL '1 month') + (random() * INTERVAL '24 hours'),
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
WHERE LOWER(f.title) = 'jason trap'
  AND LOWER(c.first_name) = 'barry'
  AND LOWER(c.last_name) = 'lovelace'
RETURNING rental_id, rental_date, inventory_id, customer_id;


-- Test UPDATE: Update the newly inserted record

UPDATE public.rental 
SET return_date = CURRENT_TIMESTAMP + INTERVAL '5 days',
    last_update = CURRENT_TIMESTAMP
WHERE rental_id = (SELECT MAX(rental_id) FROM public.rental);


-- Verify the operations
SELECT 
    r.rental_id,
    r.rental_date,
    r.return_date,
    r.customer_id,
    r.inventory_id,
    r.staff_id
FROM public.rental r
ORDER BY r.rental_id DESC
LIMIT 5;

RESET ROLE;

-- TASK 2.5: Revoke INSERT permission and verify denial
-- ============================================================================

-- Revoke INSERT permission from rental group
REVOKE INSERT ON TABLE public.rental FROM rental;

-- Verify current permissions for rental group
SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'rental' AND table_schema = 'public' AND table_name = 'rental'
ORDER BY privilege_type;


-- TASK 2.6: Create personalized role for a customer with rental/payment history
-- ============================================================================

CREATE OR REPLACE FUNCTION get_customer_user()
RETURNS TABLE(customer_id INT, username TEXT, password TEXT) AS $$
DECLARE
    selected_customer_id INT;
    customer_first_name VARCHAR;
    customer_last_name VARCHAR;
    new_username VARCHAR;
    user_password VARCHAR := 'TempPass123!';
BEGIN
    SELECT c.customer_id, c.first_name, c.last_name,
		COUNT(DISTINCT r.rental_id) as rental_count,
    	COUNT(DISTINCT p.payment_id) as payment_count
    INTO selected_customer_id, customer_first_name, customer_last_name
    FROM public.customer c
    INNER JOIN public.rental r ON c.customer_id = r.customer_id
	INNER JOIN public.payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
	HAVING COUNT(DISTINCT r.rental_id) > 0 
   		AND COUNT(DISTINCT p.payment_id) > 0
    ORDER BY rental_count DESC
    LIMIT 1;

    new_username := LOWER('client_' || customer_first_name || '_' || customer_last_name);

    RETURN QUERY SELECT selected_customer_id, new_username::TEXT, user_password::TEXT;

END;
$$ LANGUAGE plpgsql;


DO $$
DECLARE 
    uname text;
	pass text;
BEGIN
	SELECT username, password
	INTO uname, pass
	FROM get_customer_user();

	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = uname) THEN
		EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', uname, pass);
        EXECUTE format('GRANT CONNECT ON DATABASE dvdrental TO %I', uname);
		EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', uname);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %I', uname);
    ELSE
    	RAISE NOTICE 'User % already exists, skipping', uname;
    END IF;
END$$;

-- ============================================================================
-- TASK 3: IMPLEMENT ROW-LEVEL SECURITY
-- TASK 3.1: Enable Row-Level Security on rental and payment tables
-- ============================================================================

-- Enable RLS on the rental table
ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;

-- Enable RLS on the payment table
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

-- Verify RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE LOWER(tablename) IN ('rental', 'payment')
  AND LOWER(schemaname) = 'public'
ORDER BY tablename;


-- TASK 3.2: Configure that role so that the customer can only access their own data in the "rental" and "payment" tables
-- ============================================================================

-- Create helper function for dynamic customer_id
CREATE OR REPLACE FUNCTION get_customer_id_from_username()
RETURNS INT AS $$
DECLARE
    cid INT;
BEGIN
    SELECT customer_id
    INTO cid
    FROM get_customer_user()
    WHERE username = current_user;

    RETURN cid;
END;
$$ LANGUAGE plpgsql;


-- Drop existing policies if they exist (for re-running the script)
DROP POLICY IF EXISTS rental_customer_policy ON public.rental;

CREATE POLICY rental_customer_policy ON public.rental
    FOR SELECT
    USING (customer_id = get_customer_id_from_username());


-- Drop existing policies if they exist
DROP POLICY IF EXISTS payment_customer_policy ON public.payment;


CREATE POLICY payment_customer_policy ON public.payment
    FOR SELECT
    USING (customer_id = get_customer_id_from_username()); 

-- TASK 3.5: View all RLS policies
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression
FROM pg_policies
WHERE tablename IN ('rental', 'payment')
  AND schemaname = 'public'
ORDER BY tablename, policyname;

-- TASK 3.6: VERIFICATION - Compare data visibility (as superuser)
-- ============================================================================

-- Count total rentals in database (superuser can see all)
SELECT 
    'Total rentals (all customers)' as description,
    COUNT(*) as count
FROM public.rental r;

-- Total rentals for current login
SELECT 'Total rentals for this customer' as description, COUNT(*) as count
FROM public.rental r
WHERE r.customer_id = (
  SELECT customer_id FROM get_customer_user()
);

-- Count total payments in database (superuser can see all)
SELECT 
    'Total payments (all customers)' as description,
    COUNT(*) as count
FROM public.payment p;

-- Total payments for current login 
SELECT 'Total payments for this customer' as description, COUNT(*) as count
FROM public.payment p
WHERE p.customer_id = (
  SELECT customer_id FROM get_customer_user()
);

ALTER TABLE public.rental DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rental_customer_policy ON public.rental;

DROP POLICY IF EXISTS payment_customer_policy ON public.payment;


