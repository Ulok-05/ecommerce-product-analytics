-- ============================================================
-- Create tables and load CSV data
-- ============================================================

-- Run from the project root in the DuckDB CLI:
--   duckdb ecommerce.duckdb
--   .read setup/00_create_tables.sql
--
-- The script can be run again safely: existing tables are dropped
-- and recreated. Every table has a primary key, so loading the same
-- CSV twice fails with an error instead of silently duplicating rows.


-- Drop existing tables (derived tables first)
DROP TABLE IF EXISTS events_clean;
DROP TABLE IF EXISTS acquisition_costs;
DROP TABLE IF EXISTS conversions;
DROP TABLE IF EXISTS nps_responses;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS users;


-- Create users table
CREATE TABLE users (
    user_id VARCHAR PRIMARY KEY,
    signup_time TIMESTAMP,
    country VARCHAR
);

-- Create events table
CREATE TABLE events (
    event_id VARCHAR PRIMARY KEY,
    user_id VARCHAR,
    event_time TIMESTAMP,
    event_name VARCHAR,
    feature_name VARCHAR,
    session_id VARCHAR,
    duration_ms INTEGER
);

-- Create subscriptions table
CREATE TABLE subscriptions (
    subscription_id VARCHAR PRIMARY KEY,
    user_id VARCHAR,
    start_date DATE,
    end_date DATE,
    plan VARCHAR,
    mrr_amount DECIMAL
);

-- Create nps_responses table
CREATE TABLE nps_responses (
    response_id VARCHAR PRIMARY KEY,
    user_id VARCHAR,
    response_date DATE,
    score INTEGER,
    feedback TEXT
);

-- Create conversions table
CREATE TABLE conversions (
    conversion_id VARCHAR PRIMARY KEY,
    user_id VARCHAR,
    conversion_time TIMESTAMP,
    conversion_type VARCHAR
);

-- Create acquisition_costs table
-- One acquisition record per user.
CREATE TABLE acquisition_costs (
    user_id VARCHAR PRIMARY KEY,
    acquisition_channel VARCHAR,
    cost DECIMAL
);


-- Load CSV data into tables
COPY users FROM 'mock_data/files/users.csv' (AUTO_DETECT TRUE);
COPY events FROM 'mock_data/files/events.csv' (AUTO_DETECT TRUE);
COPY subscriptions FROM 'mock_data/files/subscriptions.csv' (AUTO_DETECT TRUE);
COPY nps_responses FROM 'mock_data/files/npsResponses.csv' (AUTO_DETECT TRUE);
COPY conversions FROM 'mock_data/files/conversions.csv' (AUTO_DETECT TRUE);
COPY acquisition_costs FROM 'mock_data/files/acquisitionCosts.csv' (AUTO_DETECT TRUE);


-- Check: row counts in the database must match the CSV files
SELECT 'users' AS table_name,
       (SELECT COUNT(*) FROM users) AS db_rows,
       (SELECT COUNT(*) FROM read_csv('mock_data/files/users.csv')) AS csv_rows
UNION ALL
SELECT 'events',
       (SELECT COUNT(*) FROM events),
       (SELECT COUNT(*) FROM read_csv('mock_data/files/events.csv'))
UNION ALL
SELECT 'subscriptions',
       (SELECT COUNT(*) FROM subscriptions),
       (SELECT COUNT(*) FROM read_csv('mock_data/files/subscriptions.csv'))
UNION ALL
SELECT 'nps_responses',
       (SELECT COUNT(*) FROM nps_responses),
       (SELECT COUNT(*) FROM read_csv('mock_data/files/npsResponses.csv'))
UNION ALL
SELECT 'conversions',
       (SELECT COUNT(*) FROM conversions),
       (SELECT COUNT(*) FROM read_csv('mock_data/files/conversions.csv'))
UNION ALL
SELECT 'acquisition_costs',
       (SELECT COUNT(*) FROM acquisition_costs),
       (SELECT COUNT(*) FROM read_csv('mock_data/files/acquisitionCosts.csv'));
