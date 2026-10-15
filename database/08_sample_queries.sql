-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Script 08: 16 Advanced Analytical Queries (CTEs, Window Functions, JSONB, RLS)
-- Engine: PostgreSQL 15+
-- ============================================================================

-- ============================================================================
-- QUERY 1: RECURSIVE CTE - ORGANIZATIONAL REPORTING HIERARCHY WITH SUBORDINATE COUNT
-- Concepts: Recursive CTE, Anchor & Recursive Members, String Concatenation, Tree Depth
-- Purpose: Evaluates corporate hierarchy depth and prints complete chain of command.
-- ============================================================================
WITH RECURSIVE employee_hierarchy AS (
    -- Anchor: Top executive(s) with no manager
    SELECT 
        e.employee_id,
        e.emp_code,
        e.first_name || ' ' || e.last_name AS employee_name,
        des.designation_title,
        d.dept_name,
        e.manager_id,
        1 AS level,
        (e.first_name || ' ' || e.last_name)::TEXT AS management_chain
    FROM employees e
    JOIN designations des ON e.designation_id = des.designation_id
    JOIN departments d ON e.department_id = d.department_id
    WHERE e.manager_id IS NULL AND e.status = 'ACTIVE'

    UNION ALL

    -- Recursive Step: Subordinates reporting to resolved managers
    SELECT 
        sub.employee_id,
        sub.emp_code,
        sub.first_name || ' ' || sub.last_name AS employee_name,
        des.designation_title,
        d.dept_name,
        sub.manager_id,
        eh.level + 1 AS level,
        (eh.management_chain || ' -> ' || sub.first_name || ' ' || sub.last_name)::TEXT
    FROM employees sub
    JOIN designations des ON sub.designation_id = des.designation_id
    JOIN departments d ON sub.department_id = d.department_id
    JOIN employee_hierarchy eh ON sub.manager_id = eh.employee_id
    WHERE sub.status = 'ACTIVE'
)
SELECT 
    level,
    emp_code,
    employee_name,
    designation_title,
    dept_name,
    management_chain
FROM employee_hierarchy
ORDER BY level, dept_name, employee_name;

-- ============================================================================
-- QUERY 2: WINDOW FUNCTION - RUNNING TOTAL OF PAYROLL COST BY DEPARTMENT
-- Concepts: SUM() OVER with unbounded preceding window frames
-- Purpose: Shows cumulative expenditure progression as employees are accounted for.
-- ============================================================================
SELECT 
    d.dept_name,
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    p.gross_salary,
    -- Running cumulative sum of gross salary within the department
    SUM(p.gross_salary) OVER (
        PARTITION BY e.department_id 
        ORDER BY p.gross_salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_dept_gross_spend,
    -- Total department spend for percentage calculation
    SUM(p.gross_salary) OVER (PARTITION BY e.department_id) AS total_dept_gross,
    -- Individual salary as percentage of department total
    ROUND((p.gross_salary / SUM(p.gross_salary) OVER (PARTITION BY e.department_id) * 100), 2) AS pct_of_dept_spend
FROM payslips p
JOIN employees e ON p.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
WHERE p.payroll_year = 2026 AND p.payroll_month = 2
ORDER BY d.dept_name, p.gross_salary DESC;

-- ============================================================================
-- QUERY 3: WINDOW FUNCTION - SALARY QUARTILES & PERCENTILE RANKING
-- Concepts: NTILE(4), PERCENT_RANK(), DENSE_RANK()
-- Purpose: Classifies enterprise compensation into quartiles for equity review.
-- ============================================================================
SELECT 
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    des.designation_title,
    d.dept_name,
    s.basic_pay,
    NTILE(4) OVER (ORDER BY s.basic_pay) AS salary_quartile,
    ROUND((PERCENT_RANK() OVER (ORDER BY s.basic_pay))::NUMERIC, 3) AS salary_percentile,
    DENSE_RANK() OVER (ORDER BY s.basic_pay DESC) AS company_wide_rank
FROM employees e
JOIN salary_structures s ON e.employee_id = s.employee_id AND s.is_current = TRUE
JOIN designations des ON e.designation_id = des.designation_id
JOIN departments d ON e.department_id = d.department_id
WHERE e.status = 'ACTIVE'
ORDER BY s.basic_pay DESC;

-- ============================================================================
-- QUERY 4: WINDOW FUNCTION - PEER SALARY COMPARISON USING LAG() AND LEAD()
-- Concepts: LAG(), LEAD(), Inter-row offset comparison within department partition
-- Purpose: Analyzes compensation deltas between adjacent pay grades in a department.
-- ============================================================================
SELECT 
    d.dept_name,
    e.first_name || ' ' || e.last_name AS employee_name,
    des.designation_title,
    s.basic_pay,
    LAG(s.basic_pay, 1) OVER (PARTITION BY e.department_id ORDER BY s.basic_pay DESC) AS higher_peer_salary,
    LEAD(s.basic_pay, 1) OVER (PARTITION BY e.department_id ORDER BY s.basic_pay DESC) AS lower_peer_salary,
    ROUND(s.basic_pay - AVG(s.basic_pay) OVER (PARTITION BY e.department_id), 2) AS delta_from_dept_avg
FROM employees e
JOIN salary_structures s ON e.employee_id = s.employee_id AND s.is_current = TRUE
JOIN designations des ON e.designation_id = des.designation_id
JOIN departments d ON e.department_id = d.department_id
WHERE e.status = 'ACTIVE'
ORDER BY d.dept_name, s.basic_pay DESC;

-- ============================================================================
-- QUERY 5: PARTITION PRUNING DEMONSTRATION WITH EXPLAIN
-- Concepts: Declarative partition constraint exclusion in PostgreSQL optimizer
-- Purpose: Proves the query engine only accesses the target year partition table.
-- ============================================================================
EXPLAIN ANALYZE
SELECT 
    p.payslip_id,
    p.employee_id,
    p.payroll_year,
    p.payroll_month,
    p.net_salary,
    p.payment_status
FROM payslips p
WHERE p.payroll_year = 2026 AND p.payroll_month = 1;

-- ============================================================================
-- QUERY 6: JSONB OPERATORS - QUERYING UNSTRUCTURED FLEXIBLE ALLOWANCES
-- Concepts: JSONB path operators (->, ->>), containment (@>), JSON aggregation
-- Purpose: Extracts specific remote/broadband allowances across employees.
-- ============================================================================
SELECT 
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.dept_name,
    s.flexible_allowances->>'broadband' AS broadband_allowance,
    s.flexible_allowances->>'wellness' AS wellness_allowance,
    s.flexible_allowances->>'fuel' AS fuel_allowance,
    s.flexible_allowances
FROM salary_structures s
JOIN employees e ON s.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
WHERE s.is_current = TRUE
  AND s.flexible_allowances @> '{"broadband": 2000}'::jsonb
ORDER BY e.emp_code;

-- ============================================================================
-- QUERY 7: CORRELATED SUBQUERY - EMPLOYEES EARNING ABOVE DEPARTMENT AVERAGE
-- Concepts: Correlated Subquery with outer table reference
-- Purpose: Flags potential compensation outliers requiring HR compensation review.
-- ============================================================================
SELECT 
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.dept_name,
    s.basic_pay,
    (
        SELECT ROUND(AVG(s2.basic_pay), 2)
        FROM employees e2
        JOIN salary_structures s2 ON e2.employee_id = s2.employee_id AND s2.is_current = TRUE
        WHERE e2.department_id = e.department_id AND e2.status = 'ACTIVE'
    ) AS department_average_basic
FROM employees e
JOIN salary_structures s ON e.employee_id = s.employee_id AND s.is_current = TRUE
JOIN departments d ON e.department_id = d.department_id
WHERE e.status = 'ACTIVE'
  AND s.basic_pay > (
      SELECT AVG(s2.basic_pay)
      FROM employees e2
      JOIN salary_structures s2 ON e2.employee_id = s2.employee_id AND s2.is_current = TRUE
      WHERE e2.department_id = e.department_id AND e2.status = 'ACTIVE'
  )
ORDER BY d.dept_name, s.basic_pay DESC;

-- ============================================================================
-- QUERY 8: ADVANCED CONDITIONAL AGGREGATION - MONTHLY ATTENDANCE MATRIX
-- Concepts: FILTER (WHERE ...), Conditional COUNT, Overtime summation
-- Purpose: Pivots attendance statuses into tabular monthly reporting in a single pass.
-- ============================================================================
SELECT 
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.dept_code,
    COUNT(*) FILTER (WHERE a.status = 'PRESENT') AS days_present,
    COUNT(*) FILTER (WHERE a.status = 'HALF_DAY') AS days_half_day,
    COUNT(*) FILTER (WHERE a.status = 'ON_LEAVE') AS days_leave,
    COUNT(*) FILTER (WHERE a.status = 'ABSENT') AS days_unexcused_absent,
    COUNT(*) FILTER (WHERE a.status = 'HOLIDAY') AS company_holidays,
    SUM(a.overtime_hours) AS total_overtime_hours
FROM attendance a
JOIN employees e ON a.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
WHERE a.attendance_date BETWEEN '2026-02-01' AND '2026-02-28'
GROUP BY e.employee_id, e.emp_code, e.first_name, e.last_name, d.dept_code
ORDER BY d.dept_code, e.emp_code;

-- ============================================================================
-- QUERY 9: LOSS OF PAY (LOP) FINANCIAL IMPACT ANALYSIS
-- Concepts: Complex Multi-Table JOIN, Mathematical Deduction Aggregation
-- Purpose: Pinpoints absenteeism cost burden per department.
-- ============================================================================
SELECT 
    d.dept_name,
    COUNT(p.payslip_id) AS total_payslips_audited,
    SUM(p.loss_of_pay_days) AS total_lop_days_incurred,
    SUM(p.lop_deduction) AS total_salary_lost_to_lop,
    ROUND(AVG(p.lop_deduction), 2) AS avg_lop_loss_per_employee
FROM payslips p
JOIN employees e ON p.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
WHERE p.payroll_year = 2026
GROUP BY d.department_id, d.dept_name
ORDER BY total_salary_lost_to_lop DESC;

-- ============================================================================
-- QUERY 10: BUDGET VARIANCE ANALYSIS WITH CASE EXPRESSIONS
-- Concepts: CASE WHEN, Annualized Run-Rate Projections, Budget Overrun Alerts
-- Purpose: Executive finance report comparing actual vs annual budget.
-- ============================================================================
WITH dept_burn_rate AS (
    SELECT 
        d.department_id,
        d.dept_name,
        d.annual_budget,
        -- Average monthly gross spend across recorded payroll periods
        AVG(dept_monthly_gross) AS avg_monthly_burn
    FROM (
        SELECT e.department_id, p.payroll_year, p.payroll_month, SUM(p.gross_salary) AS dept_monthly_gross
        FROM payslips p
        JOIN employees e ON p.employee_id = e.employee_id
        GROUP BY e.department_id, p.payroll_year, p.payroll_month
    ) monthly_agg
    JOIN departments d ON monthly_agg.department_id = d.department_id
    GROUP BY d.department_id, d.dept_name, d.annual_budget
)
SELECT 
    dept_name,
    annual_budget,
    ROUND(avg_monthly_burn, 2) AS avg_monthly_spend,
    ROUND(avg_monthly_burn * 12.0, 2) AS projected_annual_expenditure,
    ROUND((avg_monthly_burn * 12.0) - annual_budget, 2) AS variance_amount,
    ROUND(((avg_monthly_burn * 12.0) / NULLIF(annual_budget, 0) * 100), 2) AS budget_utilization_pct,
    CASE 
        WHEN (avg_monthly_burn * 12.0) > annual_budget THEN 'CRITICAL: BUDGET DEFICIT'
        WHEN (avg_monthly_burn * 12.0) >= (annual_budget * 0.90) THEN 'WARNING: NEAR THRESHOLD'
        ELSE 'HEALTHY'
    END AS financial_health_status
FROM dept_burn_rate
ORDER BY budget_utilization_pct DESC;

-- ============================================================================
-- QUERY 11: SALARY CHANGE AUDIT TRAIL QUERY
-- Concepts: Audit log traversal, JSONB inspection of modified compensation fields
-- Purpose: Demonstrates trigger-captured historical compensation modifications.
-- ============================================================================
SELECT 
    a.audit_id,
    a.employee_id,
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    a.action_type,
    a.old_values->>'basic_pay' AS previous_basic,
    a.new_values->>'basic_pay' AS updated_basic,
    (a.new_values->>'basic_pay')::NUMERIC - (a.old_values->>'basic_pay')::NUMERIC AS basic_pay_increment,
    a.changed_by,
    a.changed_at
FROM salary_change_audit a
JOIN employees e ON a.employee_id = e.employee_id
ORDER BY a.changed_at DESC;

-- ============================================================================
-- QUERY 12: YEAR-TO-DATE (YTD) CUMULATIVE SALARY & TDS REMITTANCE
-- Concepts: Cumulative Window Function, Fiscal Year Ledger Analysis
-- Purpose: Forms statutory input for Form 16 and annual tax return filings.
-- ============================================================================
SELECT 
    p.employee_id,
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    p.payroll_year,
    p.payroll_month,
    p.gross_salary,
    p.tax_deduction AS monthly_tds,
    SUM(p.gross_salary) OVER (
        PARTITION BY p.employee_id 
        ORDER BY p.payroll_year, p.payroll_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ytd_cumulative_gross,
    SUM(p.tax_deduction) OVER (
        PARTITION BY p.employee_id 
        ORDER BY p.payroll_year, p.payroll_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ytd_cumulative_tds
FROM payslips p
JOIN employees e ON p.employee_id = e.employee_id
WHERE e.employee_id = 12
ORDER BY p.payroll_year, p.payroll_month;

-- ============================================================================
-- QUERY 13: SPAN OF CONTROL - MANAGER DIRECT & INDIRECT REPORT COUNTS
-- Concepts: Recursive CTE with Self-Referencing Join & Aggregation
-- Purpose: Identifies managerial bandwidth and organizational depth.
-- ============================================================================
WITH RECURSIVE reports_cte AS (
    SELECT 
        manager_id AS root_manager_id,
        employee_id AS subordinate_id
    FROM employees 
    WHERE manager_id IS NOT NULL AND status = 'ACTIVE'

    UNION ALL

    SELECT 
        r.root_manager_id,
        e.employee_id AS subordinate_id
    FROM employees e
    JOIN reports_cte r ON e.manager_id = r.subordinate_id
    WHERE e.status = 'ACTIVE'
)
SELECT 
    m.employee_id AS manager_id,
    m.emp_code AS manager_code,
    m.first_name || ' ' || m.last_name AS manager_name,
    des.designation_title,
    COUNT(DISTINCT r.subordinate_id) AS total_organization_span
FROM reports_cte r
JOIN employees m ON r.root_manager_id = m.employee_id
JOIN designations des ON m.designation_id = des.designation_id
GROUP BY m.employee_id, m.emp_code, m.first_name, m.last_name, des.designation_title
ORDER BY total_organization_span DESC;

-- ============================================================================
-- QUERY 14: MATERIALIZED VIEW QUERY VS LIVE QUERY BENCHMARK
-- Concepts: Performance comparison between cached pre-aggregation and raw query
-- Purpose: Demonstrates performance gain from materialized view during viva.
-- ============================================================================
-- Live Aggregation (computes sums on the fly):
EXPLAIN ANALYZE
SELECT 
    d.dept_code, 
    p.payroll_year, 
    p.payroll_month, 
    SUM(p.gross_salary) AS total_gross
FROM payslips p
JOIN employees e ON p.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.dept_code, p.payroll_year, p.payroll_month;

-- Materialized View Scan (instantaneous index/heap lookup):
EXPLAIN ANALYZE
SELECT dept_code, payroll_year, payroll_month, total_gross_spend
FROM mv_department_payroll_analytics;

-- ============================================================================
-- QUERY 15: ROW-LEVEL SECURITY (RLS) ENFORCEMENT DEMONSTRATION
-- Concepts: SET LOCAL session settings, dynamic security policies
-- Purpose: Verifies an employee cannot inspect peer records or corporate totals.
-- ============================================================================
-- Step A: Set session context as Employee 15
SELECT set_config('app.current_role', 'EMPLOYEE', true);
SELECT set_config('app.current_employee_id', '15', true);

-- Result: Only rows belonging to employee 15 will be returned!
SELECT payslip_id, employee_id, payroll_year, payroll_month, gross_salary, net_salary
FROM payslips;

-- Step B: Switch session to HR role
SELECT set_config('app.current_role', 'HR', true);

-- Result: All employees' payslips become visible!
SELECT COUNT(*) AS total_visible_payslips FROM payslips;

-- ============================================================================
-- QUERY 16: TOP EARNER PER DEPARTMENT USING DISTINCT ON
-- Concepts: DISTINCT ON (PostgreSQL specific high-performance alternative to window functions)
-- Purpose: Rapidly retrieves the single highest-paid employee per department.
-- ============================================================================
SELECT DISTINCT ON (e.department_id)
    d.dept_name,
    e.emp_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    des.designation_title,
    s.basic_pay
FROM employees e
JOIN salary_structures s ON e.employee_id = s.employee_id AND s.is_current = TRUE
JOIN departments d ON e.department_id = d.department_id
JOIN designations des ON e.designation_id = des.designation_id
WHERE e.status = 'ACTIVE'
ORDER BY e.department_id, s.basic_pay DESC;
