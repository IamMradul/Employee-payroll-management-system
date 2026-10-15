# Employee Payroll Management System (EPMS)
## Comprehensive Database & System Test Plan

This document details the test strategy, test cases, SQL execution commands, and expected vs actual outcomes for verifying all Advanced DBMS concepts and application features in EPMS.

---

## Test Environment Prerequisites
- **DBMS**: PostgreSQL 15 or higher
- **Extensions**: `btree_gist`
- **Application**: Python 3.10+, FastAPI, `psycopg2-binary`, `reportlab`
- **Database Name**: `payroll_db`

---

## Test Cases Matrix

| Test ID | Module / Feature | Concept Tested | Test Type |
|---|---|---|---|
| **TC-01** | Table Constraints | Managerial Self-Reference & Cycle Check | Domain Constraint |
| **TC-02** | Salary Structures | `btree_gist` Exclusion Constraint (Overlapping Dates) | Temporal Integrity |
| **TC-03** | Salary Structures | Partial Unique Index on `is_current = TRUE` | Partial Indexing |
| **TC-04** | Employees Master | Trigger `trg_validate_employee_age` ($\ge 18$ yrs) | DML Validation Trigger |
| **TC-05** | Audit Logging | Trigger `trg_audit_salary_changes` (JSONB Delta) | Automated Auditing |
| **TC-06** | Financial Guard | Trigger `trg_prevent_negative_salary` | Business Rule Trigger |
| **TC-07** | Leave Quota | Trigger `trg_manage_leave_balance` | Referential & Quota Trigger |
| **TC-08** | Batch Payroll | PL/pgSQL Procedure `process_monthly_payroll` (Cursors) | Batch Processing |
| **TC-09** | Payslip Ledger | Declarative Range Partitioning & Pruning | Physical Storage / Optimizer |
| **TC-10** | Analytics | Materialized View `CONCURRENT REFRESH` | Physical Caching |
| **TC-11** | Security | Row-Level Security (RLS) with Connection Pool | Multi-tenant Security |
| **TC-12** | Semi-structured | GIN Index on JSONB Flexible Allowances | Inverted Indexing |
| **TC-13** | Org Chart | Recursive Common Table Expression (CTE) | Graph / Hierarchy Query |

---

## Detailed Test Cases & Execution Scripts

### TC-01: Managerial Self-Reference Prevention
- **Objective**: Verify that an employee cannot be designated as their own direct manager.
- **Test Query**:
  ```sql
  UPDATE employees SET manager_id = 1 WHERE employee_id = 1;
  ```
- **Expected Outcome**:
  ```text
  ERROR: new row for relation "employees" violates check constraint "chk_cannot_manage_self"
  DETAIL: Failing row contains (..., manager_id=1, employee_id=1, ...).
  ```
- **Status**: PASSED

---

### TC-02: Temporal Overlap Prevention (`btree_gist` Exclusion Constraint)
- **Objective**: Prevent overlapping salary validity periods for the same employee.
- **Setup**: Employee 12 currently has an active structure effective from `'2025-01-01'` onwards.
- **Test Query**:
  ```sql
  INSERT INTO salary_structures (
      employee_id, basic_pay, effective_from, effective_to, is_current
  ) VALUES (
      12, 85000.00, '2025-06-01', '2025-12-31', FALSE
  );
  ```
- **Expected Outcome**:
  ```text
  ERROR: conflicting key value violates exclusion constraint "no_overlapping_salary_ranges"
  DETAIL: Key (employee_id, daterange(effective_from, COALESCE(effective_to, 'infinity'::date), '[]'))=(12, [2025-06-01,2025-12-31]) overlaps with existing key (12, [2025-01-01,infinity)).
  ```
- **Status**: PASSED

---

### TC-03: Partial Unique Index on `is_current`
- **Objective**: Ensure at most one salary structure can be marked as `is_current = TRUE` per employee.
- **Test Query**:
  ```sql
  -- Attempt to insert a second 'is_current = TRUE' structure for employee 14
  INSERT INTO salary_structures (
      employee_id, basic_pay, effective_from, effective_to, is_current
  ) VALUES (
      14, 75000.00, '2026-04-01', NULL, TRUE
  );
  ```
- **Expected Outcome**:
  ```text
  ERROR: duplicate key value violates unique constraint "uq_employee_current_salary"
  DETAIL: Key (employee_id)=(14) already exists.
  ```
- **Status**: PASSED

---

### TC-04: Age Validation Trigger (Safe for `pg_restore`)
- **Objective**: Verify that employees under 18 years of age at their joining date are rejected.
- **Test Query**:
  ```sql
  INSERT INTO employees (
      emp_code, first_name, last_name, email, phone, date_of_birth,
      gender, department_id, designation_id, joining_date, bank_account_no,
      bank_name, ifsc_code, pan_number
  ) VALUES (
      'TEST999', 'Underage', 'Applicant', 'underage@test.com', '+919999900000',
      '2010-01-01', 'M', 2, 6, '2025-01-01', '1234567890',
      'HDFC Bank', 'HDFC0001234', 'ZZZZZ9999Z'
  );
  ```
- **Expected Outcome**:
  ```text
  ERROR: Employee age violation: Employee TEST999 must be at least 18 years old upon joining (DOB: 2010-01-01, Joining: 2025-01-01)
  ```
- **Status**: PASSED

---

### TC-05: Salary Change Audit Trigger
- **Objective**: Verify that modifying an employee's salary generates an immutable audit record with old and new values in JSONB.
- **Test Query**:
  ```sql
  -- Set session actor
  SET LOCAL app.current_username = 'hr_auditor';

  UPDATE salary_structures 
  SET basic_pay = basic_pay + 5000.00 
  WHERE employee_id = 18 AND is_current = TRUE;

  -- Inspect audit log
  SELECT audit_id, employee_id, action_type, changed_by, old_values->>'basic_pay' AS old_pay, new_values->>'basic_pay' AS new_pay 
  FROM salary_change_audit 
  WHERE employee_id = 18 
  ORDER BY audit_id DESC LIMIT 1;
  ```
- **Expected Outcome**:
  - A new row is present in `salary_change_audit` with `action_type = 'UPDATE'`, `changed_by = 'hr_auditor'`, and valid JSONB representations.
- **Status**: PASSED

---

### TC-06: Negative Salary Protection Trigger
- **Objective**: Ensure deductions cannot exceed gross pay, preventing negative salary disbursement.
- **Test Query**:
  ```sql
  INSERT INTO payslips (
      payroll_year, employee_id, payroll_run_id, payroll_month,
      pay_period_start, pay_period_end, total_working_days, days_present,
      basic_pay, gross_salary, total_deductions, net_salary
  ) VALUES (
      2026, 12, 1, 4, '2026-04-01', '2026-04-30', 30, 30,
      10000.00, 10000.00, 15000.00, -5000.00
  );
  ```
- **Expected Outcome**:
  ```text
  ERROR: Financial integrity constraint failed: Total deductions (₹15000.00) exceed gross earnings (₹10000.00) for employee ID 12 in period 2026-4
  ```
- **Status**: PASSED

---

### TC-07: Leave Quota Deduction & Insufficient Balance Blocker
- **Objective**: Verify that approving an application automatically decrements remaining quota and blocks approvals when balance is insufficient.
- **Test Query**:
  ```sql
  -- Try to apply and approve 25 days of Casual Leave when balance is only 11 days
  INSERT INTO leave_applications (
      employee_id, leave_type_id, start_date, end_date, days_count, status, reason
  ) VALUES (
      12, 1, '2026-05-01', '2026-05-25', 25.0, 'PENDING', 'Extended vacation'
  ) RETURNING leave_id;

  -- Attempt to approve it
  UPDATE leave_applications SET status = 'APPROVED' WHERE leave_id = (SELECT max(leave_id) FROM leave_applications);
  ```
- **Expected Outcome**:
  ```text
  ERROR: Insufficient leave balance! Requested: 25.0, Remaining available: 11.0
  ```
- **Status**: PASSED

---

### TC-08: Batch Payroll Procedure Execution (`process_monthly_payroll`)
- **Objective**: Test the execution of the PL/pgSQL stored procedure using cursors and savepoints.
- **Test Query**:
  ```sql
  CALL process_monthly_payroll(2026, 3, 1);
  ```
- **Expected Outcome**:
  ```text
  NOTICE: Batch Payroll run 6 completed successfully for 2026-3: 27 employees processed.
  ```
- **Status**: PASSED

---

### TC-09: Partition Pruning on `payslips`
- **Objective**: Verify that the query planner accesses only `payslips_2026` when filtering on `payroll_year = 2026`.
- **Test Query**:
  ```sql
  EXPLAIN SELECT * FROM payslips WHERE payroll_year = 2026 AND payroll_month = 2;
  ```
- **Expected Outcome**:
  - The plan contains only `payslips_2026`. `payslips_2025` and `payslips_future` are excluded from the plan tree.
- **Status**: PASSED

---

### TC-10: Row-Level Security (RLS) Isolation
- **Objective**: Verify that an authenticated employee cannot view any other employee's payslips.
- **Test Query**:
  ```sql
  BEGIN;
  SET LOCAL app.current_role = 'EMPLOYEE';
  SET LOCAL app.current_employee_id = '12';

  SELECT COUNT(*) FROM payslips; -- Should return 6 (only employee 12's payslips)
  SELECT DISTINCT employee_id FROM payslips; -- Should return ONLY 12
  COMMIT;
  ```
- **Expected Outcome**:
  - Output count equals 6, and `DISTINCT employee_id` yields exactly `12`. Peer records remain completely invisible.
- **Status**: PASSED
