
-- Role-Based Authentication and Row-Level Security Tasks
-- TASK 2.1: Create rentaluser with connection privileges only
-- ============================================================================

-- Create the user
CREATE USER rentaluser WITH PASSWORD 'rentalpassword';

-- Grant connection privilege to the database
GRANT CONNECT ON DATABASE dvd_rental TO rentaluser;

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
SET ROLE rentaluser;

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


RESET ROLE;

-- TASK 2.3: Create rental group and add rentaluser
-- ============================================================================

-- Create the rental group (role)
CREATE ROLE rental;

-- Add rentaluser to the rental group
GRANT rental TO rentaluser;

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

-- Switch to rentaluser (who is member of rental group)
SET ROLE rentaluser;

-- Test INSERT: Add a new rental record

INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (
    CURRENT_TIMESTAMP,
    1,  -- Valid inventory_id
    1,  -- Valid customer_id
    CURRENT_TIMESTAMP + INTERVAL '3 days',
    1,  -- Valid staff_id
    CURRENT_TIMESTAMP
);


-- Test UPDATE: Update the newly inserted record

UPDATE public.rental 
SET return_date = CURRENT_TIMESTAMP + INTERVAL '5 days',
    last_update = CURRENT_TIMESTAMP
WHERE rental_id = (SELECT MAX(rental_id) FROM public.rental);


-- Verify the operations
/*
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
*/

-- RESET ROLE;

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

-- Switch to rentaluser to test
-- SET ROLE rentaluser;

-- This INSERT should fail with permission denied error
/*
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (
    CURRENT_TIMESTAMP,
    2,
    2,
    CURRENT_TIMESTAMP + INTERVAL '3 days',
    1,
    CURRENT_TIMESTAMP
);
*/
-- Expected error: ERROR: permission denied for table rental

-- RESET ROLE;

-- TASK 2.6: Create personalized role for a customer with rental/payment history
-- ============================================================================

-- Find a customer with both rental and payment history
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    COUNT(DISTINCT r.rental_id) as rental_count,
    COUNT(DISTINCT p.payment_id) as payment_count
FROM public.customer c
INNER JOIN public.rental r ON c.customer_id = r.customer_id
INNER JOIN public.payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
HAVING COUNT(DISTINCT r.rental_id) > 0 
   AND COUNT(DISTINCT p.payment_id) > 0
ORDER BY rental_count DESC
LIMIT 5;

-- Using customer: Mary Smith (customer_id = 1)
-- Verify her data exists
SELECT 
    'Customer Record' as record_type,
    COUNT(*) as count
FROM public.customer c
WHERE c.customer_id = 1
UNION ALL
SELECT 
    'Rental Records' as record_type,
    COUNT(*) as count
FROM public.rental r
WHERE r.customer_id = 1
UNION ALL
SELECT 
    'Payment Records' as record_type,
    COUNT(*) as count
FROM public.payment p
WHERE p.customer_id = 1;

-- Create personalized role: client_mary_smith
CREATE ROLE client_mary_smith WITH LOGIN PASSWORD 'marypassword';

-- Grant connection to database
GRANT CONNECT ON DATABASE dvd_rental TO client_mary_smith;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO client_mary_smith;

-- Grant SELECT on customer table (to view their own info)
GRANT SELECT ON TABLE public.customer TO client_mary_smith;

-- Grant SELECT on rental table (to view their rental history)
GRANT SELECT ON TABLE public.rental TO client_mary_smith;

-- Grant SELECT on payment table (to view their payment history)
GRANT SELECT ON TABLE public.payment TO client_mary_smith;

-- Grant SELECT on related tables for complete information
GRANT SELECT ON TABLE public.film TO client_mary_smith;
GRANT SELECT ON TABLE public.inventory TO client_mary_smith;
GRANT SELECT ON TABLE public.store TO client_mary_smith;
GRANT SELECT ON TABLE public.address TO client_mary_smith;
GRANT SELECT ON TABLE public.city TO client_mary_smith;
GRANT SELECT ON TABLE public.country TO client_mary_smith;
GRANT SELECT ON TABLE public.staff TO client_mary_smith;
GRANT SELECT ON TABLE public.film_category TO client_mary_smith;
GRANT SELECT ON TABLE public.category TO client_mary_smith;

-- Create a view for the customer's rental data
CREATE VIEW public.client_mary_smith_rentals AS
SELECT 
    r.rental_id,
    r.rental_date,
    r.return_date,
    f.title as film_title,
    f.description as film_description,
    f.rating,
    f.rental_rate,
    r.inventory_id
FROM public.rental r
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE r.customer_id = 1;  -- Mary Smith's customer_id

-- Grant access to the personalized view
GRANT SELECT ON public.client_mary_smith_rentals TO client_mary_smith;

-- Create a view for the customer's payment history
CREATE VIEW public.client_mary_smith_payments AS
SELECT 
    p.payment_id,
    p.amount,
    p.payment_date,
    r.rental_date,
    f.title as film_title
FROM public.payment p
INNER JOIN public.rental r ON p.rental_id = r.rental_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE p.customer_id = 1;  -- Mary Smith's customer_id

-- Grant access to the payment view
GRANT SELECT ON public.client_mary_smith_payments TO client_mary_smith;

-- TASK 2 VERIFICATION: Summary of all created roles and permissions
-- ============================================================================

-- 1. View all users and their attributes
SELECT 
    usename as username,
    usecreatedb as can_create_db,
    usesuper as is_superuser,
    valuntil as password_expiry
FROM pg_user
WHERE usename IN ('rentaluser', 'client_mary_smith')
ORDER BY usename;

-- 2. View all roles and groups
SELECT 
    rolname as role_name,
    rolcanlogin as can_login,
    rolsuper as is_superuser
FROM pg_roles
WHERE rolname IN ('rentaluser', 'rental', 'client_mary_smith')
ORDER BY rolname;

-- 3. View role memberships
SELECT 
    r.rolname as group_role,
    m.rolname as member_role
FROM pg_roles r
INNER JOIN pg_auth_members am ON r.oid = am.roleid
INNER JOIN pg_roles m ON am.member = m.oid
WHERE r.rolname = 'rental' OR m.rolname IN ('rentaluser', 'client_mary_smith');

-- 4. View all table privileges
SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges
WHERE grantee IN ('rentaluser', 'rental', 'client_mary_smith')
  AND table_schema = 'public'
ORDER BY grantee, table_name, privilege_type;

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
WHERE tablename IN ('rental', 'payment')
  AND schemaname = 'public'
ORDER BY tablename;


-- TASK 3.2: Create RLS policies for the rental table
-- ============================================================================

-- Drop existing policies if they exist (for re-running the script)
DROP POLICY IF EXISTS rental_customer_policy ON public.rental;
DROP POLICY IF EXISTS rental_admin_policy ON public.rental;

-- Create policy: client_mary_smith can only see their own rentals
CREATE POLICY rental_customer_policy ON public.rental
    FOR SELECT
    TO client_mary_smith
    USING (customer_id = 1);  -- Mary Smith's customer_id

-- Create policy for superuser/admin access (optional but recommended)
CREATE POLICY rental_admin_policy ON public.rental
    FOR ALL
    TO postgres
    USING (true)
    WITH CHECK (true);

-- TASK 3.3: Create RLS policies for the payment table
-- ============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS payment_customer_policy ON public.payment;
DROP POLICY IF EXISTS payment_admin_policy ON public.payment;

-- Create policy: client_mary_smith can only see their own payments
CREATE POLICY payment_customer_policy ON public.payment
    FOR SELECT
    TO client_mary_smith
    USING (customer_id = 1);  -- Mary Smith's customer_id

-- Create policy for superuser/admin access (optional but recommended)
CREATE POLICY payment_admin_policy ON public.payment
    FOR ALL
    TO postgres
    USING (true)
    WITH CHECK (true);

-- TASK 3.4: Create helper function for dynamic customer identification
-- ============================================================================

-- Function to get current customer_id from role name
CREATE OR REPLACE FUNCTION public.get_current_customer_id()
RETURNS INTEGER AS $$
BEGIN
    -- Extract customer_id from role name or session variable
    -- For client_mary_smith, returns 1
    RETURN CASE 
        WHEN current_user = 'client_mary_smith' THEN 1
        -- Add more cases for other customer roles as needed
        ELSE NULL
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

-- Count Mary Smith's rentals specifically
SELECT 
    'Mary Smith rentals only (customer_id=1)' as description,
    COUNT(*) as count
FROM public.rental r
WHERE r.customer_id = 1;

-- Count total payments in database (superuser can see all)
SELECT 
    'Total payments (all customers)' as description,
    COUNT(*) as count
FROM public.payment p;

-- Count Mary Smith's payments specifically
SELECT 
    'Mary Smith payments only (customer_id=1)' as description,
    COUNT(*) as count
FROM public.payment p
WHERE p.customer_id = 1;

-- Show sample of other customers' data (superuser can see)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT r.rental_id) as rental_count
FROM public.customer c
LEFT JOIN public.rental r ON c.customer_id = r.customer_id
WHERE c.customer_id IN (1, 2, 3, 4, 5)
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY c.customer_id;

-- ============================================================================
-- TASK 3.7: TEST RLS - Switch to client_mary_smith role
-- ============================================================================

-- Switch to the customer role to test RLS
-- SET ROLE client_mary_smith;

-- ============================================================================
-- TEST 1: Query rental table (should ONLY see Mary Smith's rentals)
-- ============================================================================

/*
-- Run this as client_mary_smith
-- This query should return ONLY rentals for customer_id = 1
SELECT 
    r.rental_id,
    r.rental_date,
    r.return_date,
    r.customer_id,
    c.first_name,
    c.last_name,
    c.email
FROM public.rental r
INNER JOIN public.customer c ON r.customer_id = c.customer_id
ORDER BY r.rental_date DESC
LIMIT 10;

-- Count visible rentals (should match Mary Smith's count only)
SELECT 
    'Rentals visible to client_mary_smith' as description,
    COUNT(*) as count
FROM public.rental r;
*/

-- ============================================================================
-- TEST 2: Query payment table (should ONLY see Mary Smith's payments)
-- ============================================================================

/*
-- Run this as client_mary_smith
-- This query should return ONLY payments for customer_id = 1
SELECT 
    p.payment_id,
    p.amount,
    p.payment_date,
    p.customer_id,
    c.first_name,
    c.last_name
FROM public.payment p
INNER JOIN public.customer c ON p.customer_id = c.customer_id
ORDER BY p.payment_date DESC
LIMIT 10;

-- Count visible payments (should match Mary Smith's count only)
SELECT 
    'Payments visible to client_mary_smith' as description,
    COUNT(*) as count
FROM public.payment p;
*/

-- ============================================================================
-- TEST 3: Comprehensive query with rental and film details
-- ============================================================================

/*
-- Run this as client_mary_smith
SELECT 
    r.rental_id,
    r.rental_date,
    r.return_date,
    c.first_name || ' ' || c.last_name as customer_name,
    c.email,
    f.title as film_title,
    f.description as film_description,
    f.rating,
    f.rental_rate,
    f.length as film_length_minutes,
    cat.name as film_category,
    s.first_name || ' ' || s.last_name as staff_name,
    st.store_id
FROM public.rental r
INNER JOIN public.customer c ON r.customer_id = c.customer_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
LEFT JOIN public.film_category fc ON f.film_id = fc.film_id
LEFT JOIN public.category cat ON fc.category_id = cat.category_id
INNER JOIN public.staff s ON r.staff_id = s.staff_id
INNER JOIN public.store st ON i.store_id = st.store_id
ORDER BY r.rental_date DESC
LIMIT 20;
*/

-- ============================================================================
-- TEST 4: Payment history with rental and film details
-- ============================================================================

/*
-- Run this as client_mary_smith
SELECT 
    p.payment_id,
    p.amount,
    p.payment_date,
    c.first_name || ' ' || c.last_name as customer_name,
    c.email,
    r.rental_date,
    r.return_date,
    f.title as film_title,
    f.rental_rate,
    s.first_name || ' ' || s.last_name as staff_name
FROM public.payment p
INNER JOIN public.customer c ON p.customer_id = c.customer_id
INNER JOIN public.rental r ON p.rental_id = r.rental_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
INNER JOIN public.staff s ON p.staff_id = s.staff_id
ORDER BY p.payment_date DESC
LIMIT 20;
*/

-- ============================================================================
-- TEST 5: Try to access another customer's data (should return 0 rows)
-- ============================================================================

/*
-- Run this as client_mary_smith
-- Even though we explicitly query customer_id = 2, RLS will return 0 rows
SELECT 
    r.rental_id,
    r.rental_date,
    r.customer_id,
    c.first_name,
    c.last_name
FROM public.rental r
INNER JOIN public.customer c ON r.customer_id = c.customer_id
WHERE r.customer_id = 2;  -- Different customer - should return 0 rows

-- This should also return 0 rows
SELECT 
    p.payment_id,
    p.amount,
    p.customer_id
FROM public.payment p
WHERE p.customer_id = 2;  -- Different customer - should return 0 rows

-- Query without WHERE clause - still only sees Mary Smith's data
SELECT COUNT(*) as visible_rentals
FROM public.rental r;

SELECT COUNT(*) as visible_payments  
FROM public.payment p;
*/

-- ============================================================================
-- TEST 6: Summary statistics for client_mary_smith
-- ============================================================================

/*
-- Run this as client_mary_smith
-- Rental statistics
SELECT 
    COUNT(DISTINCT r.rental_id) as total_rentals,
    COUNT(DISTINCT f.film_id) as unique_films_rented,
    MIN(r.rental_date) as first_rental_date,
    MAX(r.rental_date) as last_rental_date,
    COUNT(CASE WHEN r.return_date IS NULL THEN 1 END) as currently_rented
FROM public.rental r
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id;

-- Payment statistics
SELECT 
    COUNT(p.payment_id) as total_payments,
    SUM(p.amount) as total_amount_paid,
    AVG(p.amount) as average_payment,
    MIN(p.payment_date) as first_payment_date,
    MAX(p.payment_date) as last_payment_date
FROM public.payment p;

-- Favorite film categories
SELECT 
    cat.name as category,
    COUNT(DISTINCT r.rental_id) as times_rented
FROM public.rental r
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category cat ON fc.category_id = cat.category_id
GROUP BY cat.name
ORDER BY times_rented DESC
LIMIT 5;
*/

-- ============================================================================
-- RESET TO SUPERUSER
-- ============================================================================

-- Switch back to superuser
-- RESET ROLE;

-- ============================================================================
-- TASK 3.8: Create enhanced views with RLS protection
-- ============================================================================

-- Create a comprehensive rental history view
CREATE OR REPLACE VIEW public.my_rental_history AS
SELECT 
    r.rental_id,
    r.rental_date,
    r.return_date,
    f.title as film_title,
    f.description as film_description,
    f.rating,
    f.rental_rate,
    f.length as film_length_minutes,
    f.release_year,
    cat.name as category,
    l.name as language,
    s.first_name || ' ' || s.last_name as staff_name,
    st.store_id,
    a.address as store_address,
    ci.city as store_city
FROM public.rental r
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
LEFT JOIN public.film_category fc ON f.film_id = fc.film_id
LEFT JOIN public.category cat ON fc.category_id = cat.category_id
LEFT JOIN public.language l ON f.language_id = l.language_id
INNER JOIN public.staff s ON r.staff_id = s.staff_id
INNER JOIN public.store st ON i.store_id = st.store_id
INNER JOIN public.address a ON st.address_id = a.address_id
INNER JOIN public.city ci ON a.city_id = ci.city_id;

-- Grant access to the view
GRANT SELECT ON public.my_rental_history TO client_mary_smith;
GRANT SELECT ON TABLE public.language TO client_mary_smith;

-- Create a comprehensive payment history view
CREATE OR REPLACE VIEW public.my_payment_history AS
SELECT 
    p.payment_id,
    p.amount,
    p.payment_date,
    r.rental_date,
    r.return_date,
    f.title as film_title,
    f.rental_rate,
    f.rating,
    cat.name as category,
    s.first_name || ' ' || s.last_name as staff_name,
    st.store_id
FROM public.payment p
INNER JOIN public.rental r ON p.rental_id = r.rental_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
LEFT JOIN public.film_category fc ON f.film_id = fc.film_id
LEFT JOIN public.category cat ON fc.category_id = cat.category_id
INNER JOIN public.staff s ON p.staff_id = s.staff_id
INNER JOIN public.store st ON s.store_id = st.store_id;

-- Grant access to the payment view
GRANT SELECT ON public.my_payment_history TO client_mary_smith;

