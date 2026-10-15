-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Script 03: PL/pgSQL Stored Functions, Procedures, Cursors & Transactions
-- Engine: PostgreSQL 15+
-- ============================================================================

-- ============================================================================
-- 1. HELPER FUNCTION: GET PAYROLL CONFIGURATION VALUE
-- ============================================================================
CREATE OR REPLACE FUNCTION get_payroll_config(p_key VARCHAR, p_default VARCHAR)
RETURNS VARCHAR
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_val VARCHAR;
BEGIN
    SELECT config_value INTO v_val
    FROM payroll_config
    WHERE config_key = p_key;

    RETURN COALESCE(v_val, p_default);
END;
$$;

COMMENT ON FUNCTION get_payroll_config IS 'Safely retrieves configuration parameter with fallback default';

-- ============================================================================
-- 2. PROGRESSIVE TAX CALCULATION FUNCTION (calculate_tax)
-- Advanced Feature: Dynamic Slab Iteration with Progressive Brackets & Health/Education Cess
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_tax(
    p_annual_taxable_income NUMERIC,
    p_financial_year VARCHAR DEFAULT '2025-2026',
    p_regime tax_regime DEFAULT 'NEW'
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_slab RECORD;
    v_taxable_in_slab NUMERIC := 0.00;
    v_total_base_tax NUMERIC := 0.00;
    v_cess_pct NUMERIC := 4.00; -- Default 4% cess
    v_final_tax NUMERIC := 0.00;
    v_standard_deduction NUMERIC := 50000.00; -- Standard Deduction
    v_net_taxable NUMERIC;
BEGIN
    -- Apply standard deduction
    v_net_taxable := GREATEST(0.00, p_annual_taxable_income - v_standard_deduction);

    -- If taxable income is zero or below initial exempt limit
    IF v_net_taxable <= 300000.00 THEN
        RETURN 0.00;
    END IF;

    -- Cursor/Loop over progressive tax brackets ordered by minimum income threshold
    FOR v_slab IN 
        SELECT min_income, max_income, tax_rate_percent, cess_percent
        FROM tax_slabs
        WHERE financial_year = p_financial_year 
          AND regime = p_regime
        ORDER BY min_income ASC
    LOOP
        v_cess_pct := v_slab.cess_percent;

        IF v_net_taxable > v_slab.min_income THEN
            IF v_slab.max_income IS NOT NULL THEN
                -- Income spans part or all of this capped bracket
                v_taxable_in_slab := LEAST(v_net_taxable, v_slab.max_income) - v_slab.min_income;
            ELSE
                -- Top uncapped bracket (e.g. income > 1,500,000)
                v_taxable_in_slab := v_net_taxable - v_slab.min_income;
            END IF;

            v_total_base_tax := v_total_base_tax + (v_taxable_in_slab * (v_slab.tax_rate_percent / 100.0));
        END IF;
    END LOOP;

    -- Add statutory Education & Health Cess (e.g. 4%)
    v_final_tax := v_total_base_tax * (1.0 + (v_cess_pct / 100.0));

    RETURN ROUND(v_final_tax, 2);
END;
$$;

COMMENT ON FUNCTION calculate_tax IS 'Calculates projected annual income tax across dynamic brackets with standard deduction and cess';

-- ============================================================================
-- 3. CALENDAR & ATTENDANCE HELPER FUNCTION
-- Computes calendar days, standard working days (excluding Sundays and holidays)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_month_calendar_info(
    p_year INT,
    p_month INT,
    OUT total_days INT,
    OUT working_days INT,
    OUT period_start DATE,
    OUT period_end DATE
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_curr_date DATE;
    v_dow INT;
    v_is_holiday BOOLEAN;
BEGIN
    period_start := make_date(p_year, p_month, 1);
    period_end := (period_start + INTERVAL '1 month - 1 day')::DATE;
    total_days := (period_end - period_start) + 1;
    working_days := 0;

    v_curr_date := period_start;
    WHILE v_curr_date <= period_end LOOP
        v_dow := EXTRACT(DOW FROM v_curr_date); -- 0 = Sunday
        
        -- Check if current date is in official holidays
        SELECT EXISTS(SELECT 1 FROM holidays WHERE holiday_date = v_curr_date AND NOT is_optional) 
        INTO v_is_holiday;

        -- Count as standard working day if NOT Sunday (0) and NOT an official holiday
        IF v_dow != 0 AND NOT v_is_holiday THEN
            working_days := working_days + 1;
        END IF;

        v_curr_date := v_curr_date + 1;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION get_month_calendar_info IS 'Evaluates calendar span, official holidays, and expected business working days for a month';

-- ============================================================================
-- 4. INDIVIDUAL SALARY CALCULATION FUNCTION (calculate_employee_salary)
-- Calculates full compensation breakdown for a single employee in a given month
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_employee_salary(
    p_employee_id INT,
    p_year INT,
    p_month INT
)
RETURNS TABLE (
    basic_pay NUMERIC,
    hra NUMERIC,
    da NUMERIC,
    special_allowance NUMERIC,
    flexible_allowances_total NUMERIC,
    overtime_hours NUMERIC,
    overtime_pay NUMERIC,
    gross_salary NUMERIC,
    total_working_days INT,
    days_present NUMERIC,
    paid_leaves NUMERIC,
    loss_of_pay_days NUMERIC,
    pf_deduction NUMERIC,
    tax_deduction NUMERIC,
    insurance_deduction NUMERIC,
    lop_deduction NUMERIC,
    other_deductions NUMERIC,
    total_deductions NUMERIC,
    net_salary NUMERIC,
    breakdown_json JSONB
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_struct RECORD;
    v_cal RECORD;
    v_daily_rate NUMERIC;
    v_hourly_rate NUMERIC;
    v_ot_multiplier NUMERIC;
    v_std_hours NUMERIC;
    v_half_days NUMERIC := 0.0;
    v_full_present NUMERIC := 0.0;
    v_absent_days NUMERIC := 0.0;
    v_paid_leave_cnt NUMERIC := 0.0;
    v_unpaid_leave_cnt NUMERIC := 0.0;
    v_flex_sum NUMERIC := 0.0;
    v_flex_key TEXT;
    v_flex_val TEXT;
    v_annual_projected_gross NUMERIC;
    v_annual_tax NUMERIC;
    v_monthly_tds NUMERIC;
    v_period_start DATE;
    v_period_end DATE;
    v_emp_joining DATE;
    v_emp_status employment_status;
BEGIN
    -- Fetch calendar metrics for this month
    SELECT * INTO v_cal FROM get_month_calendar_info(p_year, p_month);
    v_period_start := v_cal.period_start;
    v_period_end := v_cal.period_end;
    total_working_days := v_cal.working_days;

    -- Validate employee exists and is eligible for payroll
    SELECT joining_date, status INTO v_emp_joining, v_emp_status
    FROM employees WHERE employee_id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee with ID % does not exist', p_employee_id;
    END IF;

    IF v_emp_status = 'TERMINATED' THEN
        RAISE EXCEPTION 'Cannot calculate salary for terminated employee ID %', p_employee_id;
    END IF;

    -- Retrieve active salary structure valid for this pay period
    SELECT * INTO v_struct
    FROM salary_structures
    WHERE employee_id = p_employee_id
      AND effective_from <= v_period_end
      AND (effective_to IS NULL OR effective_to >= v_period_start)
    ORDER BY effective_from DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No valid salary structure found for employee ID % in period %-%', 
            p_employee_id, p_year, p_month;
    END IF;

    -- Sum up flexible allowances from JSONB
    IF v_struct.flexible_allowances IS NOT NULL AND v_struct.flexible_allowances != '{}'::jsonb THEN
        FOR v_flex_key, v_flex_val IN 
            SELECT key, value::text FROM jsonb_each_text(v_struct.flexible_allowances)
        LOOP
            v_flex_sum := v_flex_sum + COALESCE(v_flex_val::NUMERIC, 0.00);
        END LOOP;
    END IF;
    flexible_allowances_total := ROUND(v_flex_sum, 2);

    basic_pay := v_struct.basic_pay;
    hra := v_struct.hra;
    da := v_struct.da;
    special_allowance := v_struct.special_allowance;
    insurance_deduction := v_struct.insurance_deduction;

    -- Base monthly fixed compensation before pro-ration
    -- Daily rate calculated on 30 standard days or total month calendar days
    v_daily_rate := (basic_pay + hra + da + special_allowance + flexible_allowances_total) / v_cal.total_days;
    
    v_std_hours := get_payroll_config('STANDARD_DAILY_HOURS', '8')::NUMERIC;
    v_ot_multiplier := get_payroll_config('OVERTIME_HOURLY_MULTIPLIER', '1.5')::NUMERIC;
    v_hourly_rate := v_daily_rate / v_std_hours;

    -- Aggregate attendance records for the month
    SELECT 
        COALESCE(COUNT(*) FILTER (WHERE att.status = 'PRESENT'), 0),
        COALESCE(COUNT(*) FILTER (WHERE att.status = 'HALF_DAY'), 0),
        COALESCE(COUNT(*) FILTER (WHERE att.status = 'ABSENT'), 0),
        COALESCE(SUM(att.overtime_hours), 0.00)
    INTO v_full_present, v_half_days, v_absent_days, overtime_hours
    FROM attendance att
    WHERE att.employee_id = p_employee_id
      AND att.attendance_date BETWEEN v_period_start AND v_period_end;

    days_present := v_full_present + (v_half_days * 0.5);

    -- Check approved leaves in this month
    SELECT 
        COALESCE(SUM(la.days_count) FILTER (WHERE lt.is_paid = TRUE), 0.0),
        COALESCE(SUM(la.days_count) FILTER (WHERE lt.is_paid = FALSE), 0.0)
    INTO v_paid_leave_cnt, v_unpaid_leave_cnt
    FROM leave_applications la
    JOIN leave_types lt ON la.leave_type_id = lt.leave_type_id
    WHERE la.employee_id = p_employee_id
      AND la.status = 'APPROVED'
      AND la.start_date <= v_period_end
      AND la.end_date >= v_period_start;

    paid_leaves := v_paid_leave_cnt;

    -- Loss of pay days = Unapproved absences + Unpaid leaves (LWP) + unpaid half days
    loss_of_pay_days := v_absent_days + v_unpaid_leave_cnt + (v_half_days * 0.5);
    lop_deduction := ROUND(loss_of_pay_days * v_daily_rate, 2);

    -- Overtime pay = Overtime Hours * Hourly Rate * 1.5
    overtime_pay := ROUND(overtime_hours * v_hourly_rate * v_ot_multiplier, 2);

    -- Gross earnings
    gross_salary := ROUND(basic_pay + hra + da + special_allowance + flexible_allowances_total + overtime_pay, 2);

    -- Statutory Deductions
    -- Provident Fund (PF): standard percentage of Basic + DA
    pf_deduction := ROUND((basic_pay + da) * (v_struct.pf_percentage / 100.0), 2);

    -- Professional Tax
    other_deductions := v_struct.professional_tax;

    -- Projected Annual Income Tax (TDS)
    -- Projected annual taxable gross = (Monthly Gross - PF) * 12
    v_annual_projected_gross := GREATEST(0.00, (gross_salary - pf_deduction) * 12);
    v_annual_tax := calculate_tax(v_annual_projected_gross, '2025-2026', 'NEW');
    v_monthly_tds := ROUND(v_annual_tax / 12.0, 2);
    tax_deduction := v_monthly_tds;

    -- Total deductions & Net salary
    total_deductions := ROUND(pf_deduction + tax_deduction + insurance_deduction + lop_deduction + other_deductions, 2);
    net_salary := GREATEST(0.00, gross_salary - total_deductions);

    -- Construct comprehensive immutable JSONB breakdown
    breakdown_json := jsonb_build_object(
        'employee_id', p_employee_id,
        'year', p_year,
        'month', p_month,
        'hourly_rate', ROUND(v_hourly_rate, 2),
        'daily_rate', ROUND(v_daily_rate, 2),
        'earnings', jsonb_build_object(
            'basic', basic_pay,
            'hra', hra,
            'da', da,
            'special_allowance', special_allowance,
            'flexible_allowances', v_struct.flexible_allowances,
            'overtime_pay', overtime_pay
        ),
        'deductions', jsonb_build_object(
            'pf', pf_deduction,
            'tds', tax_deduction,
            'insurance', insurance_deduction,
            'lop', lop_deduction,
            'professional_tax', other_deductions
        ),
        'tax_math', jsonb_build_object(
            'annual_projected_gross', v_annual_projected_gross,
            'annual_tax', v_annual_tax,
            'monthly_tds', v_monthly_tds
        )
    );

    RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION calculate_employee_salary IS 'Evaluates complete salary components, overtime, LOP, and TDS snapshot for an employee';

-- ============================================================================
-- 5. BATCH PAYROLL STORED PROCEDURE (process_monthly_payroll)
-- Advanced ADBMS Concepts:
-- 1. Explicit PL/pgSQL CURSOR streaming through eligible employees
-- 2. SAVEPOINTs ensuring row-level fault isolation without aborting the batch
-- 3. Automatic insertion into declaratively partitioned `payslips` table
-- 4. Rollback and exception auditing
-- ============================================================================
CREATE OR REPLACE PROCEDURE process_monthly_payroll(
    p_year INT,
    p_month INT,
    p_processed_by INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id INT;
    v_cal RECORD;
    v_emp RECORD;
    v_sal RECORD;
    v_batch_cursor CURSOR FOR
        SELECT employee_id, emp_code, first_name, last_name 
        FROM employees 
        WHERE status = 'ACTIVE'
          AND joining_date <= (make_date(p_year, p_month, 1) + INTERVAL '1 month - 1 day')::DATE
        ORDER BY employee_id;

    v_emp_count INT := 0;
    v_tot_gross NUMERIC(14,2) := 0.00;
    v_tot_ded NUMERIC(14,2) := 0.00;
    v_tot_net NUMERIC(14,2) := 0.00;
    v_error_msg TEXT;
BEGIN
    -- Validate month calendar
    SELECT * INTO v_cal FROM get_month_calendar_info(p_year, p_month);

    -- Check if payroll run already exists for this period
    SELECT payroll_run_id INTO v_run_id
    FROM payroll_runs
    WHERE payroll_year = p_year AND payroll_month = p_month;

    IF FOUND THEN
        -- If it exists and already PAID, abort to prevent overwriting financial disbursement!
        IF (SELECT status FROM payroll_runs WHERE payroll_run_id = v_run_id) = 'PAID' THEN
            RAISE EXCEPTION 'Payroll for %-% has already been PAID and is immutable', p_year, p_month;
        END IF;

        -- Update status to PROCESSING and clear previous draft payslips
        UPDATE payroll_runs
        SET status = 'PROCESSING', run_date = CURRENT_TIMESTAMP, processed_by = p_processed_by
        WHERE payroll_run_id = v_run_id;

        DELETE FROM payslips 
        WHERE payroll_run_id = v_run_id AND payroll_year = p_year;
    ELSE
        -- Insert new batch control header in DRAFT/PROCESSING status
        INSERT INTO payroll_runs (payroll_year, payroll_month, status, processed_by)
        VALUES (p_year, p_month, 'PROCESSING', p_processed_by)
        RETURNING payroll_run_id INTO v_run_id;
    END IF;

    -- Open CURSOR and stream employee records
    OPEN v_batch_cursor;
    LOOP
        FETCH v_batch_cursor INTO v_emp;
        EXIT WHEN NOT FOUND;

        -- Sub-transaction with SAVEPOINT to isolate individual employee payroll computation errors
        BEGIN
            -- Compute full salary metrics
            SELECT * INTO v_sal 
            FROM calculate_employee_salary(v_emp.employee_id, p_year, p_month);

            -- Insert calculated snapshot into partitioned `payslips` table
            INSERT INTO payslips (
                payroll_year,
                employee_id,
                payroll_run_id,
                payroll_month,
                pay_period_start,
                pay_period_end,
                total_working_days,
                days_present,
                paid_leaves,
                loss_of_pay_days,
                overtime_hours,
                basic_pay,
                hra,
                da,
                special_allowance,
                flexible_allowances_total,
                overtime_pay,
                gross_salary,
                pf_deduction,
                tax_deduction,
                insurance_deduction,
                lop_deduction,
                total_deductions,
                net_salary,
                salary_breakdown_json,
                payment_status
            ) VALUES (
                p_year,
                v_emp.employee_id,
                v_run_id,
                p_month,
                v_cal.period_start,
                v_cal.period_end,
                v_sal.total_working_days,
                v_sal.days_present,
                v_sal.paid_leaves,
                v_sal.loss_of_pay_days,
                v_sal.overtime_hours,
                v_sal.basic_pay,
                v_sal.hra,
                v_sal.da,
                v_sal.special_allowance,
                v_sal.flexible_allowances_total,
                v_sal.overtime_pay,
                v_sal.gross_salary,
                v_sal.pf_deduction,
                v_sal.tax_deduction,
                v_sal.insurance_deduction,
                v_sal.lop_deduction,
                v_sal.total_deductions,
                v_sal.net_salary,
                v_sal.breakdown_json,
                'PENDING'
            );

            -- Accumulate batch totals
            v_emp_count := v_emp_count + 1;
            v_tot_gross := v_tot_gross + v_sal.gross_salary;
            v_tot_ded := v_tot_ded + v_sal.total_deductions;
            v_tot_net := v_tot_net + v_sal.net_salary;

        EXCEPTION WHEN OTHERS THEN
            -- In case of employee-level issue (e.g. missing structure), log warning and continue
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'Skipping employee % (%) due to error: %', 
                v_emp.employee_id, v_emp.emp_code, v_error_msg;
        END;
    END LOOP;
    CLOSE v_batch_cursor;

    -- Update batch control header with final totals and advance state to PROCESSED
    UPDATE payroll_runs
    SET status = 'PROCESSED',
        total_employees = v_emp_count,
        total_gross_pay = v_tot_gross,
        total_deductions = v_tot_ded,
        total_net_pay = v_tot_net
    WHERE payroll_run_id = v_run_id;

    RAISE NOTICE 'Batch Payroll run % completed successfully for %-%: % employees processed. Total Net Payout: ₹%',
        v_run_id, p_year, p_month, v_emp_count, v_tot_net;
END;
$$;

COMMENT ON PROCEDURE process_monthly_payroll IS 'Executes batch payroll with PL/pgSQL cursor, transaction savepoints, and partition insertion';

-- ============================================================================
-- 6. APPROVE & DISBURSE PAYROLL STORED PROCEDURES
-- ============================================================================
CREATE OR REPLACE PROCEDURE approve_payroll_run(p_payroll_run_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE payroll_runs
    SET status = 'APPROVED'
    WHERE payroll_run_id = p_payroll_run_id
      AND status = 'PROCESSED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll run % is not in PROCESSED status', p_payroll_run_id;
    END IF;

    RAISE NOTICE 'Payroll run % has been approved', p_payroll_run_id;
END;
$$;

CREATE OR REPLACE PROCEDURE disburse_payroll(
    p_payroll_run_id INT,
    p_ref_prefix VARCHAR DEFAULT 'TXN-BANK'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_year INT;
    v_month INT;
BEGIN
    SELECT payroll_year, payroll_month INTO v_year, v_month
    FROM payroll_runs
    WHERE payroll_run_id = p_payroll_run_id AND status = 'APPROVED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll run % is not in APPROVED status for disbursement', p_payroll_run_id;
    END IF;

    -- Update payslips to PAID status with simulated transaction references
    UPDATE payslips
    SET payment_status = 'PAID',
        payment_date = CURRENT_DATE,
        payment_reference = p_ref_prefix || '-' || payroll_year || '-' || payroll_month || '-' || payslip_id
    WHERE payroll_run_id = p_payroll_run_id
      AND payroll_year = v_year;

    -- Mark payroll run as PAID
    UPDATE payroll_runs
    SET status = 'PAID'
    WHERE payroll_run_id = p_payroll_run_id;

    RAISE NOTICE 'Payroll run % disbursed and finalized', p_payroll_run_id;
END;
$$;
