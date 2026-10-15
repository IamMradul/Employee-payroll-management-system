-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Script 06: Roles, Permissions, and Row-Level Security (RLS)
-- Engine: PostgreSQL 15+
-- ============================================================================

-- ============================================================================
-- 1. DATABASE ROLES CREATION
-- Principle of Least Privilege: Separation of duties across administrative,
-- human resources, finance/accounting, and self-service tiers.
-- ============================================================================

DO $$
BEGIN
    -- Application connection pool user (connects from FastAPI backend)
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'epms_app_user') THEN
        CREATE ROLE epms_app_user WITH LOGIN PASSWORD 'epms_secure_pass_2026';
    END IF;

    -- Logical business roles
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'epms_admin_role') THEN
        CREATE ROLE epms_admin_role;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'epms_hr_role') THEN
        CREATE ROLE epms_hr_role;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'epms_accountant_role') THEN
        CREATE ROLE epms_accountant_role;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'epms_employee_role') THEN
        CREATE ROLE epms_employee_role;
    END IF;
END $$;

-- Grant core permissions to application user
GRANT ALL ON SCHEMA public TO epms_app_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO epms_app_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO epms_app_user;
GRANT ALL ON ALL PROCEDURES IN SCHEMA public TO epms_app_user;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO epms_app_user;

-- ============================================================================
-- 2. TABLE-LEVEL PRIVILEGES PER LOGICAL ROLE
-- ============================================================================

-- 2.1 Admin Role: Full Unrestricted Access
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO epms_admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO epms_admin_role;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA public TO epms_admin_role;

-- 2.2 HR Role: Employee Management & Leaves; Read-Only Compensation & Payslips
GRANT SELECT, INSERT, UPDATE ON employees, attendance, leave_balances, leave_applications TO epms_hr_role;
GRANT SELECT, INSERT, UPDATE ON salary_structures TO epms_hr_role;
GRANT SELECT ON departments, designations, holidays, leave_types TO epms_hr_role;
GRANT SELECT ON payslips, payroll_runs TO epms_hr_role; -- Cannot initiate payroll disbursement
GRANT SELECT ON salary_change_audit TO epms_hr_role;

-- 2.3 Accountant Role: Compensation, Tax Slabs, Payroll Runs & Disbursement
GRANT SELECT ON employees, departments, designations, attendance, leave_applications TO epms_accountant_role;
GRANT SELECT, INSERT, UPDATE ON payroll_runs, payslips, tax_slabs, payroll_config TO epms_accountant_role;
GRANT EXECUTE ON PROCEDURE process_monthly_payroll, approve_payroll_run, disburse_payroll TO epms_accountant_role;
GRANT EXECUTE ON PROCEDURE refresh_payroll_analytics_mv TO epms_accountant_role;

-- 2.4 Employee Role: Read-Only Self Access
GRANT SELECT ON departments, designations, holidays, leave_types TO epms_employee_role;
GRANT SELECT ON employees, attendance, leave_balances, payslips TO epms_employee_role;
GRANT SELECT, INSERT ON leave_applications TO epms_employee_role; -- Can apply for leave

-- ============================================================================
-- 3. ROW-LEVEL SECURITY (RLS) POLICIES
-- The connection pool connects as `epms_app_user`. For each incoming API request,
-- the backend establishes session context using transaction-scoped SET LOCAL commands:
--   SET LOCAL app.current_role = 'EMPLOYEE';
--   SET LOCAL app.current_employee_id = '12';
-- This cleanly avoids connection pool session leakage across requests.
-- ============================================================================

-- Enable RLS on core sensitive tables
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE payslips ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 3.1 RLS Policies for PAYSLIPS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS p_payslips_admin_all ON payslips;
CREATE POLICY p_payslips_admin_all ON payslips
    FOR ALL
    TO PUBLIC
    USING (
        current_setting('app.current_role', true) IN ('ADMIN', 'ACCOUNTANT', 'HR')
        OR current_setting('app.current_role', true) IS NULL -- Fallback for direct DB admin
    );

DROP POLICY IF EXISTS p_payslips_employee_self ON payslips;
CREATE POLICY p_payslips_employee_self ON payslips
    FOR SELECT
    TO PUBLIC
    USING (
        current_setting('app.current_role', true) = 'EMPLOYEE'
        AND employee_id = NULLIF(current_setting('app.current_employee_id', true), '')::INT
    );

-- ----------------------------------------------------------------------------
-- 3.2 RLS Policies for EMPLOYEES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS p_employees_staff_read ON employees;
CREATE POLICY p_employees_staff_read ON employees
    FOR SELECT
    TO PUBLIC
    USING (
        -- Staff can read directory; employees can read public cards or their own full details
        current_setting('app.current_role', true) IN ('ADMIN', 'HR', 'ACCOUNTANT')
        OR current_setting('app.current_role', true) IS NULL
        OR employee_id = NULLIF(current_setting('app.current_employee_id', true), '')::INT
    );

-- ----------------------------------------------------------------------------
-- 3.3 RLS Policies for LEAVE APPLICATIONS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS p_leave_apps_staff ON leave_applications;
CREATE POLICY p_leave_apps_staff ON leave_applications
    FOR ALL
    TO PUBLIC
    USING (
        current_setting('app.current_role', true) IN ('ADMIN', 'HR')
        OR current_setting('app.current_role', true) IS NULL
    );

DROP POLICY IF EXISTS p_leave_apps_employee ON leave_applications;
CREATE POLICY p_leave_apps_employee ON leave_applications
    FOR SELECT
    TO PUBLIC
    USING (
        current_setting('app.current_role', true) = 'EMPLOYEE'
        AND employee_id = NULLIF(current_setting('app.current_employee_id', true), '')::INT
    );

DROP POLICY IF EXISTS p_leave_apps_employee_insert ON leave_applications;
CREATE POLICY p_leave_apps_employee_insert ON leave_applications
    FOR INSERT
    TO PUBLIC
    WITH CHECK (
        current_setting('app.current_role', true) = 'EMPLOYEE'
        AND employee_id = NULLIF(current_setting('app.current_employee_id', true), '')::INT
    );

-- ----------------------------------------------------------------------------
-- 3.4 RLS Policies for ATTENDANCE
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS p_attendance_staff ON attendance;
CREATE POLICY p_attendance_staff ON attendance
    FOR ALL
    TO PUBLIC
    USING (
        current_setting('app.current_role', true) IN ('ADMIN', 'HR')
        OR current_setting('app.current_role', true) IS NULL
    );

DROP POLICY IF EXISTS p_attendance_employee ON attendance;
CREATE POLICY p_attendance_employee ON attendance
    FOR SELECT
    TO PUBLIC
    USING (
        current_setting('app.current_role', true) = 'EMPLOYEE'
        AND employee_id = NULLIF(current_setting('app.current_employee_id', true), '')::INT
    );

-- ============================================================================
-- 4. RUNNABLE DEMONSTRATION SNIPPET (EXAMINER VIVA & TESTING)
-- ============================================================================
/*
-- Run this test block to verify that Employee #10 can ONLY see their own payslips:

BEGIN;
-- Simulate an authenticated request by employee ID 10
SELECT set_config('app.current_role', 'EMPLOYEE', true);
SELECT set_config('app.current_employee_id', '10', true);

-- This SELECT will return exclusively rows where employee_id = 10!
SELECT payslip_id, employee_id, payroll_year, payroll_month, gross_salary, net_salary 
FROM payslips;

-- Resetting context (or COMMIT / ROLLBACK automatically clears it)
COMMIT;

BEGIN;
-- Simulate an HR manager or Accountant query
SELECT set_config('app.current_role', 'ACCOUNTANT', true);

-- This SELECT will return all employees' payslips across all departments!
SELECT COUNT(*) FROM payslips;
COMMIT;
*/
