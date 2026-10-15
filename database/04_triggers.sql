-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Script 04: Advanced PL/pgSQL Triggers & Audit Automation
-- Engine: PostgreSQL 15+
-- ============================================================================

-- ============================================================================
-- 1. AGE VALIDATION TRIGGER (Safe for pg_restore)
-- Replaces non-immutable CHECK constraint using CURRENT_DATE with deterministic
-- validation comparing date_of_birth against joining_date (minimum 18 years).
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_validate_employee_age()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Employee must be at least 18 years of age on their date of joining
    IF NEW.date_of_birth > (NEW.joining_date - INTERVAL '18 years') THEN
        RAISE EXCEPTION 'Employee age violation: Employee % must be at least 18 years old upon joining (DOB: %, Joining: %)',
            NEW.emp_code, NEW.date_of_birth, NEW.joining_date;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_employee_age ON employees;
CREATE TRIGGER trg_validate_employee_age
    BEFORE INSERT OR UPDATE OF date_of_birth, joining_date
    ON employees
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_employee_age();

COMMENT ON FUNCTION fn_validate_employee_age IS 'Guarantees employee is >= 18 years old at date of employment, safe across database dump restores';

-- ============================================================================
-- 2. AUTOMATIC TIMESTAMPTZ UPDATER TRIGGER
-- Ensures updated_at always reflects the exact timestamp of modification.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_employees_updated_at ON employees;
CREATE TRIGGER trg_employees_updated_at
    BEFORE UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

DROP TRIGGER IF EXISTS trg_salary_structures_updated_at ON salary_structures;
CREATE TRIGGER trg_salary_structures_updated_at
    BEFORE UPDATE ON salary_structures
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

-- ============================================================================
-- 3. AUDIT LOGGING TRIGGER ON SALARY MODIFICATIONS
-- Captures full JSONB snapshots of pre-change and post-change structures,
-- actor identity (via session settings or DB role), and action category.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_audit_salary_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor VARCHAR(100);
    v_action VARCHAR(10);
    v_emp_id INT;
    v_struct_id INT;
    v_old_json JSONB := NULL;
    v_new_json JSONB := NULL;
BEGIN
    -- Determine actor from application session setting or PostgreSQL system user
    v_actor := COALESCE(
        NULLIF(current_setting('app.current_username', true), ''),
        session_user
    );

    IF (TG_OP = 'INSERT') THEN
        v_action := 'INSERT';
        v_emp_id := NEW.employee_id;
        v_struct_id := NEW.structure_id;
        v_new_json := to_jsonb(NEW);
    ELSIF (TG_OP = 'UPDATE') THEN
        v_action := 'UPDATE';
        v_emp_id := NEW.employee_id;
        v_struct_id := NEW.structure_id;
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);
    ELSIF (TG_OP = 'DELETE') THEN
        v_action := 'DELETE';
        v_emp_id := OLD.employee_id;
        v_struct_id := OLD.structure_id;
        v_old_json := to_jsonb(OLD);
    END IF;

    -- Insert into persistent audit log
    INSERT INTO salary_change_audit (
        employee_id,
        structure_id,
        action_type,
        old_values,
        new_values,
        changed_by,
        changed_at
    ) VALUES (
        v_emp_id,
        v_struct_id,
        v_action,
        v_old_json,
        v_new_json,
        v_actor,
        CURRENT_TIMESTAMP
    );

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_salary_changes ON salary_structures;
CREATE TRIGGER trg_audit_salary_changes
    AFTER INSERT OR UPDATE OR DELETE
    ON salary_structures
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_salary_changes();

COMMENT ON FUNCTION fn_audit_salary_changes IS 'Automated immutable audit logging for all salary structure adjustments';

-- ============================================================================
-- 4. PREVENT NEGATIVE SALARIES AND INVALID FINANCIAL DISBURSEMENTS
-- Attached to partitioned payslips table to guarantee arithmetic integrity.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_prevent_negative_salary()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Deductions must not exceed gross earnings
    IF NEW.total_deductions > NEW.gross_salary THEN
        RAISE EXCEPTION 'Financial integrity constraint failed: Total deductions (₹%) exceed gross earnings (₹%) for employee ID % in period %-%',
            NEW.total_deductions, NEW.gross_salary, NEW.employee_id, NEW.payroll_year, NEW.payroll_month;
    END IF;

    -- Net salary must be strictly positive or zero
    IF NEW.net_salary < 0.00 THEN
        RAISE EXCEPTION 'Negative salary disallowed: Net salary calculated as ₹% for employee ID %',
            NEW.net_salary, NEW.employee_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_negative_salary ON payslips;
CREATE TRIGGER trg_prevent_negative_salary
    BEFORE INSERT OR UPDATE
    ON payslips
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_negative_salary();

-- ============================================================================
-- 5. AUTOMATIC LEAVE BALANCE DEDUCTION & RESTORATION TRIGGER
-- When HR marks leave as APPROVED, automatically deducts from leave_balances.
-- When an approved leave is CANCELLED/REJECTED, restores the balance.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_manage_leave_balance_on_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_leave_year INT;
    v_available NUMERIC;
BEGIN
    v_leave_year := EXTRACT(YEAR FROM NEW.start_date)::INT;

    -- Case 1: Application transitioning from non-approved to APPROVED
    IF NEW.status = 'APPROVED' AND (OLD.status IS NULL OR OLD.status != 'APPROVED') THEN
        -- Check available quota in employee's leave balance
        SELECT (total_allocated - leaves_used) INTO v_available
        FROM leave_balances
        WHERE employee_id = NEW.employee_id
          AND leave_type_id = NEW.leave_type_id
          AND year = v_leave_year;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No leave balance allocation found for employee ID % (type %, year %)',
                NEW.employee_id, NEW.leave_type_id, v_leave_year;
        END IF;

        IF v_available < NEW.days_count THEN
            RAISE EXCEPTION 'Insufficient leave balance! Requested: %, Remaining available: %',
                NEW.days_count, v_available;
        END IF;

        -- Deduct from balance
        UPDATE leave_balances
        SET leaves_used = leaves_used + NEW.days_count
        WHERE employee_id = NEW.employee_id
          AND leave_type_id = NEW.leave_type_id
          AND year = v_leave_year;

    -- Case 2: Previously APPROVED leave is now CANCELLED or REJECTED
    ELSIF OLD.status = 'APPROVED' AND NEW.status IN ('CANCELLED', 'REJECTED') THEN
        -- Restore used days
        UPDATE leave_balances
        SET leaves_used = GREATEST(0.0, leaves_used - OLD.days_count)
        WHERE employee_id = NEW.employee_id
          AND leave_type_id = NEW.leave_type_id
          AND year = v_leave_year;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_manage_leave_balance ON leave_applications;
CREATE TRIGGER trg_manage_leave_balance
    AFTER INSERT OR UPDATE OF status
    ON leave_applications
    FOR EACH ROW
    EXECUTE FUNCTION fn_manage_leave_balance_on_approval();

COMMENT ON FUNCTION fn_manage_leave_balance_on_approval IS 'Maintains real-time consistency between approved leave applications and remaining quotas';
