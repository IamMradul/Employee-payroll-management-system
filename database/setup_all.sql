-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Master Setup Script: Runs all database scripts sequentially
-- Usage: psql -U postgres -d payroll_db -f database/setup_all.sql
-- ============================================================================

\echo '==================================================='
\echo '  INITIALIZING EMPLOYEE PAYROLL MANAGEMENT SYSTEM  '
\echo '==================================================='

\echo '1. Running Schema Definitions (01_schema.sql)...'
\i 01_schema.sql

\echo '2. Applying Indexes & Performance Constraints (02_indexes.sql)...'
\i 02_indexes.sql

\echo '3. Creating Functions, Stored Procedures & Cursors (03_functions.sql)...'
\i 03_functions.sql

\echo '4. Installing Automated Triggers & Audit Rules (04_triggers.sql)...'
\i 04_triggers.sql

\echo '5. Creating Views, Recursive CTEs & Materialized Views (05_views.sql)...'
\i 05_views.sql

\echo '6. Configuring Database Roles, Grants & Row-Level Security (06_roles.sql)...'
\i 06_roles.sql

\echo '7. Seeding 28 Employees, Attendance & 6 Months Payroll (07_seed_data.sql)...'
\i 07_seed_data.sql

\echo '==================================================='
\echo '  DATABASE INITIALIZATION COMPLETED SUCCESSFULLY!  '
\echo '==================================================='
