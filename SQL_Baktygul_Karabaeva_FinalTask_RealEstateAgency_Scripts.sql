
-- REAL ESTATE AGENCY DATABASE - PHYSICAL IMPLEMENTATION
-- TASK 3: CREATE DATABASE AND SCHEMA
-- =====================================================================

-- Drop and recreate database for clean reruns
DROP DATABASE IF EXISTS property_management_db;

CREATE DATABASE property_management_db
	WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Connect to the database
\c property_management_db

-- Create schema with domain-appropriate name
-- DROP SCHEMA IF EXISTS realty CASCADE;
CREATE SCHEMA IF NOT EXISTS realty;

-- Set search path to use 'realty' schema by default
SET search_path TO realty, public;

-- =====================================================================
-- TASK 3: CREATE TABLES WITH CONSTRAINTS FROM PARENT TO CHILD
-- =====================================================================

-- TABLE 1: AGENTS
CREATE TABLE IF NOT EXISTS realty.agents (
    agent_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE, -- Email must be unique
    phone VARCHAR(20) NOT NULL,
    license_number VARCHAR(50) UNIQUE, -- License number must be unique per agent
    commission_rate DECIMAL(5,2) DEFAULT 0.05, -- 5% default commission
    is_active BOOLEAN DEFAULT TRUE,
    specialization VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Add comment explaining commission_rate data type choice
COMMENT ON COLUMN realty.agents.commission_rate IS 'DECIMAL(5,2) allows rates from 0.00 to 999.99%, typically 0.01-0.10 (1-10%)';

-- TABLE 2: CLIENTS
CREATE TABLE IF NOT EXISTS realty.clients (
    client_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE, -- Email must be unique
    phone VARCHAR(20) NOT NULL,
    client_type VARCHAR(20) NOT NULL, -- ENUM-like: BUYER, SELLER, LANDLORD, TENANT
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE,
    preferred_contact VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- TABLE 3: PROPERTIES
CREATE TABLE IF NOT EXISTS realty.properties (
    property_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_client_id INT NOT NULL,
    listing_agent_id INT NOT NULL,
    property_type VARCHAR(20) NOT NULL, -- ENUM-like: HOUSE, APARTMENT, CONDO, LAND, COMMERCIAL
    address VARCHAR(200) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    listing_price DECIMAL(15,2) NOT NULL, -- Supports prices up to $9,999,999,999,999.99
    listing_type VARCHAR(10) NOT NULL, -- ENUM-like: SALE, RENT
    bedrooms INT,
    bathrooms DECIMAL(3,1), -- Allows half-baths (e.g., 2.5)
    square_feet INT,
    status VARCHAR(20) DEFAULT 'AVAILABLE', -- AVAILABLE, PENDING, SOLD, RENTED
    created_at TIMESTAMP DEFAULT NOW(),
  
    -- Foreign keys
    CONSTRAINT fk_properties_owner FOREIGN KEY (owner_client_id) REFERENCES realty.clients(client_id) ON DELETE CASCADE,
    CONSTRAINT fk_properties_listing_agent FOREIGN KEY (listing_agent_id) REFERENCES realty.agents(agent_id) ON DELETE CASCADE
);

COMMENT ON COLUMN realty.properties.bathrooms IS 'DECIMAL(3,1) allows half-bathrooms representation (e.g., 2.5 baths)';

-- TABLE 4: MARKET_DATA (Independent table - no dependencies on transactions)
CREATE TABLE IF NOT EXISTS realty.market_data (
    market_data_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    neighborhood VARCHAR(100),
    property_type VARCHAR(50),
    average_price DECIMAL(15,2),
    median_price DECIMAL(15,2),
    price_per_sqft DECIMAL(10,2),
    days_on_market INT,
    trend VARCHAR(20), -- UP, DOWN, STABLE
    created_at TIMESTAMP DEFAULT NOW()
);

-- TABLE 5: TRANSACTIONS (depends on PROPERTIES and CLIENTS)
CREATE TABLE IF NOT EXISTS realty.transactions (
    transaction_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    property_id INT NOT NULL,
    buyer_client_id INT,
    seller_client_id INT,
    agent_id INT NOT NULL,
    transaction_type VARCHAR(10) NOT NULL, -- SALE, RENTAL
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    sale_price DECIMAL(15,2) NOT NULL,
    commission_amount DECIMAL(15,2),
    status VARCHAR(20) DEFAULT 'PENDING', -- COMPLETED, CANCELLED, PENDING
    closing_date DATE,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Foreign keys
	CONSTRAINT fk_transactions_property FOREIGN KEY (property_id) REFERENCES realty.properties(property_id) ON DELETE CASCADE,
    CONSTRAINT fk_transactions_buyer FOREIGN KEY (buyer_client_id) REFERENCES realty.clients(client_id) ON DELETE CASCADE,
    CONSTRAINT fk_transactions_seller FOREIGN KEY (seller_client_id) REFERENCES realty.clients(client_id) ON DELETE CASCADE,
    CONSTRAINT fk_transactions_agent FOREIGN KEY (agent_id) REFERENCES realty.agents(agent_id) ON DELETE CASCADE
);

-- TABLE 6: FINANCIAL_RECORDS (depends on TRANSACTIONS and AGENTS)
CREATE TABLE IF NOT EXISTS  realty.financial_records (
    financial_record_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id INT NOT NULL,
    agent_id INT NOT NULL,
    record_type VARCHAR(20) NOT NULL, -- COMMISSION, FEE, EXPENSE
    amount DECIMAL(15,2) NOT NULL,
    record_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_status VARCHAR(20) DEFAULT 'PENDING', -- PAID, PENDING, OVERDUE
    payment_method VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
  
	-- Foreign keys
	CONSTRAINT fk_financial_transaction FOREIGN KEY (transaction_id) REFERENCES realty.transactions(transaction_id) ON DELETE CASCADE,
    CONSTRAINT fk_financial_agent FOREIGN KEY (agent_id) REFERENCES realty.agents(agent_id) ON DELETE CASCADE
);

-- TABLE 7: PROPERTY_AGENTS (Junction table - Many-to-Many)
CREATE TABLE IF NOT EXISTS realty.property_agents (
    property_agent_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    property_id INT NOT NULL,
    agent_id INT NOT NULL,
    role VARCHAR(20) NOT NULL, -- LISTING_AGENT, SHOWING_AGENT, CO_AGENT
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Composite unique constraint: same agent can't have same role twice on same property
    CONSTRAINT unique_property_agent_role UNIQUE(property_id, agent_id, role),
	-- Foreign keys 
	CONSTRAINT fk_property_agents_property FOREIGN KEY (property_id) REFERENCES realty.properties(property_id) ON DELETE CASCADE,
    CONSTRAINT fk_property_agents_agent FOREIGN KEY (agent_id) REFERENCES realty.agents(agent_id) ON DELETE CASCADE
);

-- TASK 3.1: ADD CHECK CONSTRAINTS USING ALTER TABLE
-- =====================================================================

-- CHECK CONSTRAINT 1: Ensure transaction dates are after January 1, 2024
-- Business operations started on Jan 1, 2024; all transactions must be after this date
ALTER TABLE realty.transactions
    ADD CONSTRAINT chk_transaction_date_valid
    CHECK (transaction_date >= '2024-01-01');

COMMENT ON CONSTRAINT chk_transaction_date_valid ON realty.transactions IS
'Ensures all transactions are recorded after business operations started (Jan 1, 2024)';

-- CHECK CONSTRAINT 2: Ensure listing prices are positive (cannot be negative)
-- Property prices must be positive values for valid business transactions
ALTER TABLE realty.properties
    ADD CONSTRAINT chk_listing_price_positive
    CHECK (listing_price > 0);

COMMENT ON CONSTRAINT chk_listing_price_positive ON realty.properties IS
'Property prices must be positive values';

-- CHECK CONSTRAINT 3: Ensure commission rates are within valid range (0-100%)
-- Commission rates must be realistic percentages between 0% and 100%
ALTER TABLE realty.agents
    ADD CONSTRAINT chk_commission_rate_valid
    CHECK (commission_rate >= 0 AND commission_rate <= 1.00);

COMMENT ON CONSTRAINT chk_commission_rate_valid ON realty.agents IS
'Commission rates must be between 0% and 100% (0.00 to 1.00)';

-- CHECK CONSTRAINT 4: Ensure property status is one of the allowed values
-- Property status must match predefined business workflow states
ALTER TABLE realty.properties
    ADD CONSTRAINT chk_property_status_valid
    CHECK (UPPER(status) IN ('AVAILABLE', 'PENDING', 'SOLD', 'RENTED'));

COMMENT ON CONSTRAINT chk_property_status_valid ON realty.properties IS
'Property status must be one of the predefined valid statuses';

-- CHECK CONSTRAINT 5: Ensure client type is one of the allowed values
-- Client type must be one of four valid business categories
ALTER TABLE realty.clients
    ADD CONSTRAINT chk_client_type_valid
    CHECK (UPPER(client_type) IN ('BUYER', 'SELLER', 'LANDLORD', 'TENANT'));

COMMENT ON CONSTRAINT chk_client_type_valid ON realty.clients IS
'Client type must be one of the four valid business categories';

-- CHECK CONSTRAINT 6: Ensure transaction type matches allowed values
-- Transactions must be either SALE or RENTAL for proper business categorization
ALTER TABLE realty.transactions
    ADD CONSTRAINT chk_transaction_type_valid
    CHECK (UPPER(transaction_type) IN ('SALE', 'RENTAL'));

COMMENT ON CONSTRAINT chk_transaction_type_valid ON realty.transactions IS
'Transaction type must be either SALE or RENTAL';

-- CHECK CONSTRAINT 7: Ensure financial amounts are non-negative
-- Financial records cannot have negative amounts in business accounting
ALTER TABLE realty.financial_records
    ADD CONSTRAINT chk_amount_non_negative
    CHECK (amount >= 0);

COMMENT ON CONSTRAINT chk_amount_non_negative ON realty.financial_records IS
'Financial amounts cannot be negative';

-- CHECK CONSTRAINT 8: Ensure square footage is positive when specified
-- Square footage must be positive if provided; NULL is acceptable for land/special properties
ALTER TABLE realty.properties
    ADD CONSTRAINT chk_square_feet_positive
    CHECK (square_feet IS NULL OR square_feet > 0);

COMMENT ON CONSTRAINT chk_square_feet_positive ON realty.properties IS
'Square footage must be positive if specified';


-- =====================================================================
-- TASK 4: POPULATE TABLES WITH SAMPLE DATA
-- All data spans September-December 2024 (last 3 months from Dec 6, 2024)
-- Using TRUNCATE and no ON CONFLICT to prevent duplicates
-- =====================================================================

-- Clean all tables before inserting (prevents duplicates on reruns)
TRUNCATE TABLE realty.property_agents, 
               realty.financial_records, 
               realty.transactions, 
               realty.market_data,
               realty.properties, 
               realty.clients, 
               realty.agents 
RESTART IDENTITY CASCADE;

-- INSERT AGENTS 
INSERT INTO realty.agents (first_name, last_name, email, phone, license_number, commission_rate, specialization, is_active)
VALUES 
    	('Sarah', 'Johnson', 'sarah.johnson@realty.com', '555-0101', 'LIC-2024-001', 0.05, 'Residential', TRUE),
    	('Michael', 'Chen', 'michael.chen@realty.com', '555-0102', 'LIC-2024-002', 0.055, 'Commercial', TRUE),
    	('Emily', 'Rodriguez', 'emily.rodriguez@realty.com', '555-0103', 'LIC-2024-003', 0.05, 'Luxury Homes', TRUE),
    	('David', 'Thompson', 'david.thompson@realty.com', '555-0104', 'LIC-2024-004', 0.045, 'Rentals', TRUE),
    	('Jessica', 'Williams', 'jessica.williams@realty.com', '555-0105', 'LIC-2024-005', 0.05, 'Condos', TRUE),
    	('Robert', 'Martinez', 'robert.martinez@realty.com', '555-0106', 'LIC-2024-006', 0.06, 'Investment', TRUE),
    	('Amanda', 'Taylor', 'amanda.taylor@realty.com', '555-0107', 'LIC-2024-007', 0.05, 'First-time Buyers', TRUE),
    	('Christopher', 'Lee', 'christopher.lee@realty.com', '555-0108', 'LIC-2024-008', 0.055, 'Commercial', FALSE);

-- INSERT CLIENTS (buyers, sellers, landlords, tenants)
INSERT INTO realty.clients (first_name, last_name, email, phone, client_type, registration_date, preferred_contact)
VALUES
    ('John', 'Smith', 'john.smith@email.com', '555-1001', 'BUYER', '2024-09-15', 'EMAIL'),
    ('Maria', 'Garcia', 'maria.garcia@email.com', '555-1002', 'SELLER', '2024-09-20', 'PHONE'),
    ('James', 'Wilson', 'james.wilson@email.com', '555-1003', 'LANDLORD', '2024-10-01', 'EMAIL'),
    ('Linda', 'Anderson', 'linda.anderson@email.com', '555-1004', 'BUYER', '2024-10-10', 'PHONE'),
    ('Patricia', 'Thomas', 'patricia.thomas@email.com', '555-1005', 'SELLER', '2024-10-15', 'EMAIL'),
    ('Richard', 'Jackson', 'richard.jackson@email.com', '555-1006', 'TENANT', '2024-11-01', 'PHONE'),
    ('Susan', 'White', 'susan.white@email.com', '555-1007', 'BUYER', '2024-11-05', 'EMAIL'),
    ('Daniel', 'Harris', 'daniel.harris@email.com', '555-1008', 'LANDLORD', '2024-11-10', 'PHONE'),
    ('Karen', 'Martin', 'karen.martin@email.com', '555-1009', 'SELLER', '2024-11-20', 'EMAIL'),
    ('Steven', 'Clark', 'steven.clark@email.com', '555-1010', 'BUYER', '2024-12-01', 'PHONE');

-- INSERT PROPERTIES
-- Using subqueries to get client_id and agent_id by natural keys
INSERT INTO realty.properties (owner_client_id, listing_agent_id, property_type, address, city, state, zip_code, listing_price, listing_type, bedrooms, bathrooms, square_feet, status)
VALUES
    (
        (SELECT client_id FROM realty.clients WHERE email = 'maria.garcia@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-001'),
        'HOUSE', '123 Oak Street', 'Austin', 'TX', '78701', 450000.00, 'SALE', 3, 2.0, 1800, 'SOLD'
    ),
    (
        (SELECT client_id FROM realty.clients WHERE email = 'patricia.thomas@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-003'),
        'CONDO', '456 Pine Avenue', 'Austin', 'TX', '78702', 325000.00, 'SALE', 2, 2.0, 1200, 'AVAILABLE'
    ),
    (
        (SELECT client_id FROM realty.clients WHERE email = 'james.wilson@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-004'),
        'APARTMENT', '789 Maple Drive', 'Austin', 'TX', '78703', 2500.00, 'RENT', 2, 1.0, 950, 'RENTED'
    ),
    (
        (SELECT client_id FROM realty.clients WHERE email = 'karen.martin@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-002'),
        'COMMERCIAL', '321 Business Blvd', 'Austin', 'TX', '78704', 850000.00, 'SALE', NULL, 3.0, 5000, 'PENDING'
    ),
    (
        (SELECT client_id FROM realty.clients WHERE email = 'daniel.harris@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-004'),
        'HOUSE', '555 Elm Street', 'Austin', 'TX', '78705', 3200.00, 'RENT', 4, 2.5, 2200, 'AVAILABLE'
    ),
    (
        (SELECT client_id FROM realty.clients WHERE email = 'maria.garcia@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-005'),
        'CONDO', '888 Lake View', 'Austin', 'TX', '78706', 280000.00, 'SALE', 1, 1.0, 750, 'SOLD'
    ),
    (
        (SELECT client_id FROM realty.clients WHERE email = 'patricia.thomas@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-001'),
        'HOUSE', '999 Hill Road', 'Austin', 'TX', '78707', 525000.00, 'SALE', 4, 3.0, 2400, 'AVAILABLE'
    ),
    (
        (SELECT client_id FROM realty.clients WHERE email = 'james.wilson@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-004'),
        'APARTMENT', '111 Downtown Plaza', 'Austin', 'TX', '78708', 1800.00, 'RENT', 1, 1.0, 650, 'AVAILABLE'
    );

-- INSERT MARKET_DATA (last 3 months of 2024)
INSERT INTO realty.market_data (city, state, neighborhood, property_type, average_price, median_price, price_per_sqft, days_on_market, trend)
VALUES
    ('Austin', 'TX', 'Downtown', 'CONDO', 315000.00, 298000.00, 285.50, 32, 'UP'),
    ('Austin', 'TX', 'West Lake', 'HOUSE', 625000.00, 580000.00, 295.00, 45, 'STABLE'),
    ('Austin', 'TX', 'Downtown', 'CONDO', 322000.00, 305000.00, 292.00, 28, 'UP'),
    ('Austin', 'TX', 'West Lake', 'HOUSE', 618000.00, 575000.00, 290.00, 42, 'DOWN'),
    ('Austin', 'TX', 'Downtown', 'CONDO', 328000.00, 310000.00, 298.00, 25, 'UP'),
    ('Austin', 'TX', 'East Side', 'HOUSE', 485000.00, 465000.00, 245.00, 38, 'STABLE');

-- INSERT TRANSACTIONS (last 3 months)
INSERT INTO realty.transactions (property_id, buyer_client_id, seller_client_id, agent_id, transaction_type, transaction_date, sale_price, commission_amount, status, closing_date)
VALUES
    (
        (SELECT property_id FROM realty.properties WHERE address = '123 Oak Street'),
        (SELECT client_id FROM realty.clients WHERE email = 'john.smith@email.com'),
        (SELECT client_id FROM realty.clients WHERE email = 'maria.garcia@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-001'),
        'SALE', '2024-10-15', 450000.00, 22500.00, 'COMPLETED', '2024-10-15'
    ),
    (
        (SELECT property_id FROM realty.properties WHERE address = '789 Maple Drive'),
        (SELECT client_id FROM realty.clients WHERE email = 'richard.jackson@email.com'),
        (SELECT client_id FROM realty.clients WHERE email = 'james.wilson@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-004'),
        'RENTAL', '2024-11-01', 2500.00, 112.50, 'COMPLETED', '2024-11-01'
    ),
    (
        (SELECT property_id FROM realty.properties WHERE address = '888 Lake View'),
        (SELECT client_id FROM realty.clients WHERE email = 'linda.anderson@email.com'),
        (SELECT client_id FROM realty.clients WHERE email = 'maria.garcia@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-005'),
        'SALE', '2024-11-20', 280000.00, 14000.00, 'COMPLETED', '2024-11-20'
    ),
    (
        (SELECT property_id FROM realty.properties WHERE address = '321 Business Blvd'),
        (SELECT client_id FROM realty.clients WHERE email = 'susan.white@email.com'),
        (SELECT client_id FROM realty.clients WHERE email = 'karen.martin@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-002'),
        'SALE', '2024-12-01', 850000.00, 46750.00, 'PENDING', NULL
    ),
    (
        (SELECT property_id FROM realty.properties WHERE address = '456 Pine Avenue'),
        (SELECT client_id FROM realty.clients WHERE email = 'steven.clark@email.com'),
        (SELECT client_id FROM realty.clients WHERE email = 'patricia.thomas@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-003'),
        'SALE', '2024-12-03', 325000.00, 16250.00, 'PENDING', NULL
    ),
    (
        (SELECT property_id FROM realty.properties WHERE address = '555 Elm Street'),
        (SELECT client_id FROM realty.clients WHERE email = 'john.smith@email.com'),
        (SELECT client_id FROM realty.clients WHERE email = 'daniel.harris@email.com'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-004'),
        'RENTAL', '2024-11-15', 3200.00, 144.00, 'PENDING', NULL
    );

-- INSERT FINANCIAL_RECORDS
INSERT INTO realty.financial_records (transaction_id, agent_id, record_type, amount, record_date, payment_status, payment_method, description)
VALUES
    (
        (SELECT transaction_id FROM realty.transactions WHERE sale_price = 450000.00 AND transaction_type = 'SALE'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-001'),
        'COMMISSION', 22500.00, '2024-10-20', 'PAID', 'BANK_TRANSFER', 'Commission for Oak Street sale'
    ),
    (
        (SELECT transaction_id FROM realty.transactions WHERE sale_price = 2500.00 AND transaction_type = 'RENTAL' AND transaction_date = '2024-11-01'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-004'),
        'COMMISSION', 112.50, '2024-11-05', 'PAID', 'CHECK', 'Commission for Maple Drive rental'
    ),
    (
        (SELECT transaction_id FROM realty.transactions WHERE sale_price = 280000.00),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-005'),
        'COMMISSION', 14000.00, '2024-11-25', 'PAID', 'BANK_TRANSFER', 'Commission for Lake View condo'
    ),
    (
        (SELECT transaction_id FROM realty.transactions WHERE sale_price = 850000.00),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-002'),
        'COMMISSION', 46750.00, '2024-12-01', 'PENDING', NULL, 'Commission for Business Blvd commercial'
    ),
    (
        (SELECT transaction_id FROM realty.transactions WHERE sale_price = 450000.00 AND transaction_type = 'SALE'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-001'),
        'EXPENSE', 500.00, '2024-10-10', 'PAID', 'CREDIT_CARD', 'Marketing materials for Oak Street listing'
    ),
    (
        (SELECT transaction_id FROM realty.transactions WHERE sale_price = 325000.00),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-003'),
        'FEE', 350.00, '2024-12-03', 'PENDING', NULL, 'Processing fee for Pine Avenue transaction'
    );

-- INSERT PROPERTY_AGENTS (junction table entries)
INSERT INTO realty.property_agents (property_id, agent_id, role, assigned_date)
VALUES
    -- Oak Street property
    (
        (SELECT property_id FROM realty.properties WHERE address = '123 Oak Street'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-001'),
        'LISTING_AGENT', '2024-09-15'
    ),
    (
        (SELECT property_id FROM realty.properties WHERE address = '123 Oak Street'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-007'),
        'CO_AGENT', '2024-09-20'
    ),
    -- Pine Avenue condo
    (
        (SELECT property_id FROM realty.properties WHERE address = '456 Pine Avenue'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-003'),
        'LISTING_AGENT', '2024-10-15'
    ),
    -- Maple Drive apartment
    (
        (SELECT property_id FROM realty.properties WHERE address = '789 Maple Drive'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-004'),
        'LISTING_AGENT', '2024-10-01'
    ),
    -- Business Blvd commercial
    (
        (SELECT property_id FROM realty.properties WHERE address = '321 Business Blvd'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-002'),
        'LISTING_AGENT', '2024-11-01'
    ),
    (
        (SELECT property_id FROM realty.properties WHERE address = '321 Business Blvd'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-006'),
        'SHOWING_AGENT', '2024-11-10'
    ),
    -- Lake View condo
    (
        (SELECT property_id FROM realty.properties WHERE address = '888 Lake View'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-005'),
        'LISTING_AGENT', '2024-10-01'
    ),
    -- Hill Road house
    (
        (SELECT property_id FROM realty.properties WHERE address = '999 Hill Road'),
        (SELECT agent_id FROM realty.agents WHERE license_number = 'LIC-2024-001'),
        'LISTING_AGENT', '2024-11-15'
    );

-- =====================================================================
-- TASK 5.1: FUNCTION TO UPDATE DATA
-- =====================================================================

CREATE OR REPLACE FUNCTION realty.update_table_column(
    p_table_name TEXT,
    p_primary_key_value INT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_primary_key_column TEXT;
BEGIN
    -- Determine primary key column name based on table
    CASE p_table_name
        WHEN 'agents' THEN v_primary_key_column := 'agent_id';
        WHEN 'clients' THEN v_primary_key_column := 'client_id';
        WHEN 'properties' THEN v_primary_key_column := 'property_id';
        WHEN 'transactions' THEN v_primary_key_column := 'transaction_id';
        WHEN 'financial_records' THEN v_primary_key_column := 'financial_record_id';
        WHEN 'market_data' THEN v_primary_key_column := 'market_data_id';
        WHEN 'property_agents' THEN v_primary_key_column := 'property_agent_id';
        ELSE
            RAISE EXCEPTION 'Invalid table name: %', p_table_name;
    END CASE;
    
    -- Build and execute dynamic SQL
    v_sql := format('UPDATE realty.%I SET %I = %L WHERE %I = %L',
                    p_table_name, 
                    p_column_name, 
                    p_new_value, 
                    v_primary_key_column, 
                    p_primary_key_value);
    
    EXECUTE v_sql;
    
    -- Return success message
    RETURN format('Successfully updated %s.%s (ID: %s) - Set %s = %s',
                  p_table_name,
                  v_primary_key_column,
                  p_primary_key_value,
                  p_column_name,
                  p_new_value);
                  
EXCEPTION
    WHEN OTHERS THEN
        RETURN format('Error updating record: %s', SQLERRM);
END;
$$;

COMMENT ON FUNCTION realty.update_table_column IS 
'Generic function to update any column in any table using primary key. 
Uses dynamic SQL with proper escaping to prevent SQL injection.';

-- =====================================================================
-- TASK 5.2: FUNCTION TO ADD NEW TRANSACTION
-- =====================================================================

CREATE OR REPLACE FUNCTION realty.add_transaction(
    p_property_address TEXT,
    p_buyer_email TEXT,
    p_seller_email TEXT,
    p_agent_license TEXT,
    p_transaction_type TEXT,
    p_sale_price DECIMAL(15,2),
    p_transaction_date DATE DEFAULT CURRENT_DATE,
    p_commission_amount DECIMAL(15,2) DEFAULT NULL,
    p_closing_date DATE DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id INT;
    v_buyer_id INT;
    v_seller_id INT;
    v_agent_id INT;
    v_transaction_id INT;
    v_calculated_commission DECIMAL(15,2);
BEGIN
    -- Lookup property by address (natural key)
    SELECT property_id INTO v_property_id
    FROM realty.properties
    WHERE address = p_property_address;
    
    IF v_property_id IS NULL THEN
        RAISE EXCEPTION 'Property not found with address: %', p_property_address;
    END IF;
    
    -- Lookup buyer by email (natural key) - can be NULL for rentals
    IF p_buyer_email IS NOT NULL THEN
        SELECT client_id INTO v_buyer_id
        FROM realty.clients
        WHERE email = p_buyer_email;
        
        IF v_buyer_id IS NULL THEN
            RAISE EXCEPTION 'Buyer not found with email: %', p_buyer_email;
        END IF;
    END IF;
    
    -- Lookup seller by email (natural key)
    SELECT client_id INTO v_seller_id
    FROM realty.clients
    WHERE email = p_seller_email;
    
    IF v_seller_id IS NULL THEN
        RAISE EXCEPTION 'Seller not found with email: %', p_seller_email;
    END IF;
    
    -- Lookup agent by license number (natural key)
    SELECT agent_id INTO v_agent_id
    FROM realty.agents
    WHERE license_number = p_agent_license;
    
    IF v_agent_id IS NULL THEN
        RAISE EXCEPTION 'Agent not found with license: %', p_agent_license;
    END IF;
    
    -- Calculate commission if not provided
    IF p_commission_amount IS NULL THEN
        SELECT p_sale_price * commission_rate INTO v_calculated_commission
        FROM realty.agents
        WHERE agent_id = v_agent_id;
    ELSE
        v_calculated_commission := p_commission_amount;
    END IF;
    
    -- Insert the transaction
    INSERT INTO realty.transactions (
        property_id, 
        buyer_client_id, 
        seller_client_id, 
        agent_id,
        transaction_type,
        transaction_date,
        sale_price,
        commission_amount,
        closing_date,
        status
    )
    VALUES (
        v_property_id,
        v_buyer_id,
        v_seller_id,
        v_agent_id,
        p_transaction_type,
        p_transaction_date,
        p_sale_price,
        v_calculated_commission,
        p_closing_date,
        CASE WHEN p_closing_date IS NOT NULL THEN 'COMPLETED' ELSE 'PENDING' END
    )
    RETURNING transaction_id INTO v_transaction_id;
    
    -- Return success message with transaction details
    RETURN format('Transaction created successfully! ID: %s | Property: %s | Price: $%s | Commission: $%s',
                  v_transaction_id,
                  p_property_address,
                  p_sale_price,
                  v_calculated_commission);
                  
EXCEPTION
    WHEN OTHERS THEN
        RETURN format('Error creating transaction: %s', SQLERRM);
END;
$$;

COMMENT ON FUNCTION realty.add_transaction IS 
'Adds a new transaction using natural keys (address, email, license).
Automatically calculates commission based on agent rate if not provided.
Returns confirmation message with transaction details.';

-- =====================================================================
-- TASK 6: ANALYTICS VIEW FOR MOST RECENT QUARTER
-- =====================================================================

CREATE OR REPLACE VIEW realty.quarterly_analytics AS
WITH latest_quarter AS (
    -- Dynamically determine the most recent quarter in the database
    SELECT 
        DATE_TRUNC('quarter', MAX(transaction_date))::DATE AS quarter_start,
        (DATE_TRUNC('quarter', MAX(transaction_date)) + INTERVAL '3 months - 1 day')::DATE AS quarter_end
    FROM realty.transactions
)
SELECT
	-- Transaction Information
    t.transaction_type,
    t.transaction_date,
    t.sale_price,
    t.commission_amount,
    t.status,
    t.closing_date,
    -- Property Information
    p.property_type,
    p.address AS property_address,
    p.city,
    p.state,
    p.listing_type,
    p.bedrooms,
    p.bathrooms,
    p.square_feet,
    -- Agent Information
    a.first_name AS agent_first_name,
    a.last_name AS agent_last_name,
    a.email AS agent_email,
    a.specialization AS agent_specialization,
    -- Buyer Information
    bc.first_name AS buyer_first_name,
    bc.last_name AS buyer_last_name,
    bc.email AS buyer_email,
    -- Seller Information
    sc.first_name AS seller_first_name,
    sc.last_name AS seller_last_name,
    sc.email AS seller_email,
    -- Calculated Fields
    ROUND(t.sale_price / NULLIF(p.square_feet, 0), 2) AS price_per_sqft,
    ROUND((t.commission_amount / NULLIF(t.sale_price, 0)) * 100, 2) AS commission_percentage,
    -- Quarter Information
    lq.quarter_start,
    lq.quarter_end
FROM realty.transactions t
CROSS JOIN latest_quarter lq
INNER JOIN realty.properties p ON t.property_id = p.property_id
INNER JOIN realty.agents a ON t.agent_id = a.agent_id
LEFT JOIN realty.clients bc ON t.buyer_client_id = bc.client_id
LEFT JOIN realty.clients sc ON t.seller_client_id = sc.client_id
WHERE t.transaction_date BETWEEN lq.quarter_start AND lq.quarter_end
ORDER BY t.transaction_date DESC, t.sale_price DESC;

COMMENT ON VIEW realty.quarterly_analytics IS 
'Provides comprehensive analytics for the most recent quarter in the database.
Excludes surrogate keys and includes calculated metrics like price per sqft and commission percentage.
Automatically adapts to show the latest quarter based on transaction dates.';

-- =====================================================================
-- TASK 7: CREATE READ-ONLY ROLE FOR MANAGER
-- =====================================================================

-- Drop role if exists for rerunnability
DROP ROLE IF EXISTS realty_manager_readonly;

-- Create the read-only role
CREATE ROLE realty_manager_readonly WITH
    LOGIN
    PASSWORD 'SecureManagerPass2024!' -- In production, use a secure password manager
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT
    CONNECTION LIMIT 10; -- Limit concurrent connections

-- Grant CONNECT privilege on the database
GRANT CONNECT ON DATABASE property_management_db TO realty_manager_readonly;

-- Grant USAGE on the schema
GRANT USAGE ON SCHEMA realty TO realty_manager_readonly;

-- Grant SELECT on all existing tables in the schema
GRANT SELECT ON ALL TABLES IN SCHEMA realty TO realty_manager_readonly;

-- Grant SELECT on all future tables (ensures new tables are accessible)
ALTER DEFAULT PRIVILEGES IN SCHEMA realty 
    GRANT SELECT ON TABLES TO realty_manager_readonly;

-- Grant SELECT on the view
GRANT SELECT ON realty.quarterly_analytics TO realty_manager_readonly;

-- Grant USAGE on all sequences (needed to view sequence values, but not modify)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA realty TO realty_manager_readonly;

COMMENT ON ROLE realty_manager_readonly IS 
'Read-only role for managers. Has SELECT privileges on all tables and views.
Can login but cannot modify data, create objects, or perform admin functions.
Limited to 10 concurrent connections for resource management.';

-- =====================================================================
-- VERIFICATION QUERIES AND EXAMPLES
-- =====================================================================

-- Show row counts for all tables
SELECT 'agents' AS table_name, COUNT(*) AS row_count FROM realty.agents
UNION ALL
SELECT 'clients', COUNT(*) FROM realty.clients
UNION ALL
SELECT 'properties', COUNT(*) FROM realty.properties
UNION ALL
SELECT 'market_data', COUNT(*) FROM realty.market_data
UNION ALL
SELECT 'transactions', COUNT(*) FROM realty.transactions
UNION ALL
SELECT 'financial_records', COUNT(*) FROM realty.financial_records
UNION ALL
SELECT 'property_agents', COUNT(*) FROM realty.property_agents
ORDER BY table_name;

-- Example: Test update function
-- UPDATE agent specialization
SELECT realty.update_table_column(
    'agents',
    1, -- agent_id
    'specialization',
    'Luxury Residential'
);

-- Example: Test add transaction function
SELECT realty.add_transaction(
    p_property_address := '999 Hill Road',
    p_buyer_email := 'steven.clark@email.com',
    p_seller_email := 'patricia.thomas@email.com',
    p_agent_license := 'LIC-2024-001',
    p_transaction_type := 'SALE',
    p_sale_price := 525000.00,
    p_transaction_date := '2024-12-05'
);

-- Example: View quarterly analytics
SELECT * FROM realty.quarterly_analytics LIMIT 10;

-- =====================================================================
-- ADDITIONAL USEFUL QUERIES
-- =====================================================================

-- Summary of transactions by type and status
SELECT 
    transaction_type,
    status,
    COUNT(*) AS transaction_count,
    SUM(sale_price) AS total_value,
    SUM(commission_amount) AS total_commission
FROM realty.transactions
GROUP BY transaction_type, status
ORDER BY transaction_type, status;

-- Top performing agents by commission
SELECT 
    a.first_name || ' ' || a.last_name AS agent_name,
    a.specialization,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.commission_amount) AS total_commission_earned,
    AVG(t.sale_price) AS avg_sale_price
FROM realty.agents a
INNER JOIN realty.transactions t ON a.agent_id = t.agent_id
GROUP BY a.agent_id, a.first_name, a.last_name, a.specialization
ORDER BY total_commission_earned DESC;

-- Properties with multiple agents
SELECT 
    p.address,
    p.property_type,
    p.listing_price,
    COUNT(pa.agent_id) AS agent_count,
    STRING_AGG(a.first_name || ' ' || a.last_name || ' (' || pa.role || ')', ', ') AS agents
FROM realty.properties p
INNER JOIN realty.property_agents pa ON p.property_id = pa.property_id
INNER JOIN realty.agents a ON pa.agent_id = a.agent_id
GROUP BY p.property_id, p.address, p.property_type, p.listing_price
HAVING COUNT(pa.agent_id) > 1
ORDER BY agent_count DESC;


-- END OF SCRIPT

