-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Script 01: Complete Relational Schema Definition
-- Engine: PostgreSQL 15+
-- ============================================================================

-- Drop existing schema if needed (for fresh setup)
-- DROP SCHEMA IF EXISTS epms CASCADE;
-- CREATE SCHEMA epms;
-- SET search_path TO epms, public;

-- Enable required extensions
-- btree_gist allows indexing scalar datatypes (such as INT) alongside ranges in GiST indexes
-- This is critical for EXCLUSION constraints preventing overlapping temporal validity windows.
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- ============================================================================
-- 1. CUSTOM ENUM TYPES
-- Storing categorical domains as ENUMs reduces row footprint to 4 bytes per column
-- and strictly enforces domain integrity at the database storage engine layer.
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('ADMIN', 'HR', 'ACCOUNTANT', 'EMPLOYEE');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'employment_status') THEN
        CREATE TYPE employment_status AS ENUM ('ACTIVE', 'ON_LEAVE', 'TERMINATED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_status') THEN
        CREATE TYPE attendance_status AS ENUM ('PRESENT', 'ABSENT', 'HALF_DAY', 'ON_LEAVE', 'HOLIDAY', 'WEEKEND');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'leave_app_status') THEN
        CREATE TYPE leave_app_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tax_regime') THEN
        CREATE TYPE tax_regime AS ENUM ('OLD', 'NEW');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payroll_status') THEN
        CREATE TYPE payroll_status AS ENUM ('DRAFT', 'PROCESSING', 'PROCESSED', 'APPROVED', 'PAID');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE payment_status AS ENUM ('PENDING', 'PROCESSED', 'PAID', 'FAILED');
    END IF;
END $$;

-- ============================================================================
-- 2. CORE MASTER TABLES
-- ============================================================================

-- 2.1 Departments
CREATE TABLE IF NOT EXISTS departments (
    department_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_code VARCHAR(10) NOT NULL UNIQUE,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100) NOT NULL,
    annual_budget NUMERIC(14,2) NOT NULL DEFAULT 0.00 CHECK (annual_budget >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE departments IS 'Cost centres and organizational units within the enterprise';

-- 2.2 Designations / Job Titles & Pay Bands
CREATE TABLE IF NOT EXISTS designations (
    designation_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    designation_code VARCHAR(10) NOT NULL UNIQUE,
    designation_title VARCHAR(100) NOT NULL,
    min_salary NUMERIC(12,2) NOT NULL CHECK (min_salary >= 0),
    max_salary NUMERIC(12,2) NOT NULL,
    pay_grade INT NOT NULL CHECK (pay_grade BETWEEN 1 AND 10),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_salary_range CHECK (max_salary >= min_salary)
);

COMMENT ON TABLE designations IS 'Job role definitions, hierarchy grades, and legal salary bands';

-- 2.3 Users (Authentication and System Access Roles)
CREATE TABLE IF NOT EXISTS users (
    user_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'EMPLOYEE',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE users IS 'User authentication and role-based permissions registry';

-- 2.4 Employees (Core Entity with Self-Referencing Manager Hierarchy)
CREATE TABLE IF NOT EXISTS employees (
    employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT UNIQUE REFERENCES users(user_id) ON DELETE SET NULL, -- Nullable: 1:0..1 relationship
    emp_code VARCHAR(15) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    date_of_birth DATE NOT NULL, -- Age >= 18 is enforced via trigger trg_validate_employee_age (safe for pg_restore)
    gender CHAR(1) NOT NULL CHECK (gender IN ('M', 'F', 'O')),
    department_id INT NOT NULL REFERENCES departments(department_id) ON DELETE RESTRICT,
    designation_id INT NOT NULL REFERENCES designations(designation_id) ON DELETE RESTRICT,
    manager_id INT REFERENCES employees(employee_id) ON DELETE SET NULL, -- Self-referencing FK
    joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
    exit_date DATE,
    status employment_status NOT NULL DEFAULT 'ACTIVE',
    bank_account_no VARCHAR(30) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    ifsc_code VARCHAR(15) NOT NULL,
    pan_number VARCHAR(10) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_phone_format CHECK (phone ~ '^\+?[0-9]{10,15}$'),
    CONSTRAINT chk_pan_format CHECK (pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$'),
    CONSTRAINT chk_exit_after_joining CHECK (exit_date IS NULL OR exit_date >= joining_date),
    CONSTRAINT chk_cannot_manage_self CHECK (manager_id != employee_id)
);

COMMENT ON TABLE employees IS 'Master employee table storing biographical, organizational, and banking attributes';

-- ============================================================================
-- 3. COMPENSATION & TEMPORAL VALIDITY
-- ============================================================================

-- 3.1 Salary Structures
-- Demonstrates temporal validity using GiST exclusion constraints to prevent overlapping date ranges
CREATE TABLE IF NOT EXISTS salary_structures (
    structure_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    basic_pay NUMERIC(12,2) NOT NULL CHECK (basic_pay > 0),
    hra NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (hra >= 0),
    da NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (da >= 0),
    special_allowance NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (special_allowance >= 0),
    pf_percentage NUMERIC(5,2) NOT NULL DEFAULT 12.00 CHECK (pf_percentage BETWEEN 0 AND 20),
    professional_tax NUMERIC(8,2) NOT NULL DEFAULT 200.00 CHECK (professional_tax >= 0),
    insurance_deduction NUMERIC(8,2) NOT NULL DEFAULT 0.00 CHECK (insurance_deduction >= 0),
    flexible_allowances JSONB NOT NULL DEFAULT '{}'::jsonb, -- Semi-structured JSONB allowances
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_effective_range CHECK (effective_to IS NULL OR effective_to >= effective_from),
    -- ADVANCED ADBMS FEATURE: Exclusion constraint preventing overlapping temporal ranges for the same employee
    CONSTRAINT no_overlapping_salary_ranges EXCLUDE USING gist (
        employee_id WITH =,
        daterange(effective_from, COALESCE(effective_to, 'infinity'::date), '[]') WITH &&
    )
);

-- Partial Unique Index: Guarantees at most one active (current) salary structure per employee
CREATE UNIQUE INDEX IF NOT EXISTS uq_employee_current_salary
ON salary_structures (employee_id)
WHERE is_current = TRUE;

COMMENT ON TABLE salary_structures IS 'Temporal salary structures with btree_gist exclusion constraints preventing overlap';

-- 3.2 Salary Change Audit (Target table for DML Trigger)
CREATE TABLE IF NOT EXISTS salary_change_audit (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id INT NOT NULL,
    structure_id INT NOT NULL,
    action_type VARCHAR(10) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE salary_change_audit IS 'Audit log automatically populated by triggers on salary modification events';

-- ============================================================================
-- 4. ATTENDANCE, CALENDAR & LEAVE MANAGEMENT
-- ============================================================================

-- 4.1 Company Holidays Master
CREATE TABLE IF NOT EXISTS holidays (
    holiday_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    holiday_date DATE NOT NULL UNIQUE,
    holiday_name VARCHAR(100) NOT NULL,
    is_optional BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE holidays IS 'Official company holidays and mandatory calendar non-working days';

-- 4.2 Attendance
CREATE TABLE IF NOT EXISTS attendance (
    attendance_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    check_in TIME,
    check_out TIME,
    status attendance_status NOT NULL DEFAULT 'PRESENT',
    overtime_hours NUMERIC(4,2) NOT NULL DEFAULT 0.00 CHECK (overtime_hours BETWEEN 0 AND 12),
    remarks VARCHAR(255),
    CONSTRAINT uq_emp_attendance_date UNIQUE (employee_id, attendance_date),
    CONSTRAINT chk_check_out_after_in CHECK (check_out IS NULL OR check_out >= check_in)
);

COMMENT ON TABLE attendance IS 'Daily employee attendance, timesheets, and overtime tracking';

-- 4.3 Leave Types
CREATE TABLE IF NOT EXISTS leave_types (
    leave_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    leave_code VARCHAR(10) NOT NULL UNIQUE,
    leave_name VARCHAR(50) NOT NULL,
    annual_quota INT NOT NULL CHECK (annual_quota >= 0),
    is_paid BOOLEAN NOT NULL DEFAULT TRUE,
    carry_forward BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE leave_types IS 'Leave catalog with quota policies and payment classification';

-- 4.4 Leave Balances
CREATE TABLE IF NOT EXISTS leave_balances (
    balance_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    leave_type_id INT NOT NULL REFERENCES leave_types(leave_type_id) ON DELETE RESTRICT,
    year INT NOT NULL CHECK (year >= 2000),
    total_allocated NUMERIC(4,1) NOT NULL CHECK (total_allocated >= 0),
    leaves_used NUMERIC(4,1) NOT NULL DEFAULT 0.0 CHECK (leaves_used >= 0),
    -- GENERATED ALWAYS AS column ensures remaining balance is always consistent
    leaves_remaining NUMERIC(4,1) GENERATED ALWAYS AS (total_allocated - leaves_used) STORED,
    CONSTRAINT uq_emp_leave_year UNIQUE (employee_id, leave_type_id, year),
    CONSTRAINT chk_leaves_used_limit CHECK (leaves_used <= total_allocated)
);

COMMENT ON TABLE leave_balances IS 'Yearly quota allocation and balance with a stored generated column';

-- 4.5 Leave Applications
CREATE TABLE IF NOT EXISTS leave_applications (
    leave_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    leave_type_id INT NOT NULL REFERENCES leave_types(leave_type_id) ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days_count NUMERIC(4,1) NOT NULL CHECK (days_count > 0),
    status leave_app_status NOT NULL DEFAULT 'PENDING',
    approved_by INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_at TIMESTAMPTZ,
    CONSTRAINT chk_leave_date_range CHECK (end_date >= start_date)
);

COMMENT ON TABLE leave_applications IS 'Leave requests with approval workflow states';

-- ============================================================================
-- 5. SYSTEM SETTINGS & TAXATION
-- ============================================================================

-- 5.1 Payroll Configuration (Key-Value System Policies)
CREATE TABLE IF NOT EXISTS payroll_config (
    config_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    config_key VARCHAR(50) NOT NULL UNIQUE,
    config_value VARCHAR(255) NOT NULL,
    description TEXT
);

COMMENT ON TABLE payroll_config IS 'System-wide payroll parameters (standard hours, overtime multiplier, cess)';

-- 5.2 Progressive Tax Slabs (Used dynamically by PL/pgSQL calculate_tax)
CREATE TABLE IF NOT EXISTS tax_slabs (
    slab_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    financial_year VARCHAR(9) NOT NULL, -- e.g. '2025-2026'
    regime tax_regime NOT NULL DEFAULT 'NEW',
    min_income NUMERIC(12,2) NOT NULL CHECK (min_income >= 0),
    max_income NUMERIC(12,2), -- NULL denotes infinity / highest slab
    tax_rate_percent NUMERIC(5,2) NOT NULL CHECK (tax_rate_percent BETWEEN 0 AND 100),
    cess_percent NUMERIC(5,2) NOT NULL DEFAULT 4.00 CHECK (cess_percent >= 0),
    CONSTRAINT chk_slab_range CHECK (max_income IS NULL OR max_income > min_income)
);

COMMENT ON TABLE tax_slabs IS 'Income tax rate brackets for progressive TDS calculation';

-- ============================================================================
-- 6. PAYROLL RUNS & PARTITIONED PAYSLIPS
-- ============================================================================

-- 6.1 Payroll Runs (Batch Header)
CREATE TABLE IF NOT EXISTS payroll_runs (
    payroll_run_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payroll_year INT NOT NULL CHECK (payroll_year >= 2000),
    payroll_month INT NOT NULL CHECK (payroll_month BETWEEN 1 AND 12),
    run_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status payroll_status NOT NULL DEFAULT 'DRAFT',
    total_employees INT NOT NULL DEFAULT 0,
    total_gross_pay NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    total_deductions NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    total_net_pay NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    processed_by INT REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT uq_payroll_period UNIQUE (payroll_year, payroll_month)
);

COMMENT ON TABLE payroll_runs IS 'Batch control record for monthly payroll execution runs';

-- 6.2 Global Sequence for Partitioned Payslips
-- Using an explicit sequence guarantees clean, unambiguous ID generation across table partitions
CREATE SEQUENCE IF NOT EXISTS payslip_id_seq START WITH 1 INCREMENT BY 1;

-- 6.3 Partitioned Payslips Table (DECLARATIVE RANGE PARTITIONING)
-- Technical Primary Key: (payslip_id, payroll_year) as required by PostgreSQL declarative partitioning
CREATE TABLE IF NOT EXISTS payslips (
    payslip_id BIGINT DEFAULT nextval('payslip_id_seq'),
    payroll_year INT NOT NULL,                  -- Partition Key (Deliberate denormalization for pruning)
    employee_id INT NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    payroll_run_id INT NOT NULL REFERENCES payroll_runs(payroll_run_id) ON DELETE RESTRICT,
    payroll_month INT NOT NULL CHECK (payroll_month BETWEEN 1 AND 12), -- Deliberate denormalization
    pay_period_start DATE NOT NULL,
    pay_period_end DATE NOT NULL,
    total_working_days INT NOT NULL CHECK (total_working_days BETWEEN 1 AND 31),
    days_present NUMERIC(4,1) NOT NULL CHECK (days_present >= 0),
    paid_leaves NUMERIC(4,1) NOT NULL DEFAULT 0.0 CHECK (paid_leaves >= 0),
    loss_of_pay_days NUMERIC(4,1) NOT NULL DEFAULT 0.0 CHECK (loss_of_pay_days >= 0),
    overtime_hours NUMERIC(5,2) NOT NULL DEFAULT 0.0 CHECK (overtime_hours >= 0),
    basic_pay NUMERIC(12,2) NOT NULL CHECK (basic_pay >= 0),
    hra NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    da NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    special_allowance NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    flexible_allowances_total NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    overtime_pay NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    gross_salary NUMERIC(12,2) NOT NULL CHECK (gross_salary >= 0),
    pf_deduction NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    tax_deduction NUMERIC(12,2) NOT NULL DEFAULT 0.00, -- Monthly TDS
    insurance_deduction NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    lop_deduction NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    total_deductions NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    net_salary NUMERIC(12,2) NOT NULL CHECK (net_salary >= 0),
    salary_breakdown_json JSONB NOT NULL DEFAULT '{}'::jsonb, -- Temporal snapshot of calculation
    payment_status payment_status NOT NULL DEFAULT 'PENDING',
    payment_date DATE,
    payment_reference VARCHAR(100),
    generated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payslip_period CHECK (pay_period_end >= pay_period_start),
    CONSTRAINT pk_payslips PRIMARY KEY (payslip_id, payroll_year)
) PARTITION BY RANGE (payroll_year);

COMMENT ON TABLE payslips IS 'Declaratively partitioned payslip ledger storing immutable historical payroll snapshots';

-- 6.4 Concrete Physical Partitions
CREATE TABLE IF NOT EXISTS payslips_2025 PARTITION OF payslips
    FOR VALUES FROM (2025) TO (2026);

CREATE TABLE IF NOT EXISTS payslips_2026 PARTITION OF payslips
    FOR VALUES FROM (2026) TO (2027);

CREATE TABLE IF NOT EXISTS payslips_future PARTITION OF payslips
    FOR VALUES FROM (2027) TO (MAXVALUE);

-- Unique index per partition on employee and pay period to prevent duplicate payslip generation
CREATE UNIQUE INDEX IF NOT EXISTS uq_payslip_emp_period_2025 
    ON payslips_2025 (employee_id, payroll_month);

CREATE UNIQUE INDEX IF NOT EXISTS uq_payslip_emp_period_2026 
    ON payslips_2026 (employee_id, payroll_month);
