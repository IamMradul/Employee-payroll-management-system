-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Script 05: Standard Views, Recursive CTEs & Materialized Views
-- Engine: PostgreSQL 15+
-- ============================================================================

-- ============================================================================
-- 1. STANDARD VIEW: DETAILED EMPLOYEE DIRECTORY
-- Flattens department, designation, user accounts, and self-referencing manager details
-- ============================================================================
CREATE OR REPLACE VIEW vw_employee_directory AS
SELECT 
    e.employee_id,
    e.emp_code,
    e.first_name || ' ' || e.last_name AS full_name,
    e.email,
    e.phone,
    e.gender,
    e.status AS employment_status,
    e.joining_date,
    d.dept_code,
    d.dept_name,
    d.location AS department_location,
    des.designation_code,
    des.designation_title,
    des.pay_grade,
    m.emp_code AS manager_code,
    m.first_name || ' ' || m.last_name AS manager_name,
    u.username,
    u.role AS user_role,
    u.is_active AS user_is_active
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN designations des ON e.designation_id = des.designation_id
LEFT JOIN employees m ON e.manager_id = m.employee_id
LEFT JOIN users u ON e.user_id = u.user_id;

COMMENT ON VIEW vw_employee_directory IS 'Consolidated employee view resolving department, designation, manager and user joins';

-- ============================================================================
-- 2. RECURSIVE CTE VIEW: ORGANIZATIONAL REPORTING HIERARCHY
-- Advanced ADBMS Feature: Evaluates unbounded hierarchical tree structures
-- ============================================================================
CREATE OR REPLACE VIEW vw_organization_hierarchy AS
WITH RECURSIVE org_tree AS (
    -- Anchor member: Top-level executives (manager_id IS NULL)
    SELECT 
        e.employee_id,
        e.emp_code,
        e.first_name || ' ' || e.last_name AS employee_name,
        des.designation_title,
        d.dept_name,
        e.manager_id,
        NULL::TEXT AS manager_name,
        1 AS hierarchy_level,
        (e.first_name || ' ' || e.last_name)::TEXT AS reporting_path
    FROM employees e
    JOIN designations des ON e.designation_id = des.designation_id
    JOIN departments d ON e.department_id = d.department_id
    WHERE e.manager_id IS NULL AND e.status = 'ACTIVE'

    UNION ALL

    -- Recursive member: Subordinates reporting to employees resolved in prior step
    SELECT 
        sub.employee_id,
        sub.emp_code,
        sub.first_name || ' ' || sub.last_name AS employee_name,
        des.designation_title,
        d.dept_name,
        sub.manager_id,
        mgr.employee_name AS manager_name,
        mgr.hierarchy_level + 1 AS hierarchy_level,
        (mgr.reporting_path || ' -> ' || sub.first_name || ' ' || sub.last_name)::TEXT AS reporting_path
    FROM employees sub
    JOIN designations des ON sub.designation_id = des.designation_id
    JOIN departments d ON sub.department_id = d.department_id
    JOIN org_tree mgr ON sub.manager_id = mgr.employee_id
    WHERE sub.status = 'ACTIVE'
)
SELECT 
    employee_id,
    emp_code,
    employee_name,
    designation_title,
    dept_name,
    manager_name,
    hierarchy_level,
    reporting_path
FROM org_tree
ORDER BY hierarchy_level, dept_name;

COMMENT ON VIEW vw_organization_hierarchy IS 'Recursive organizational chart traversing self-referencing manager relationships';

-- ============================================================================
-- 3. ANALYTICAL VIEW: DEPARTMENT-WISE PAYROLL EXPENDITURE & BUDGET UTILIZATION
-- ============================================================================
CREATE OR REPLACE VIEW vw_department_payroll_cost AS
SELECT 
    d.department_id,
    d.dept_code,
    d.dept_name,
    d.annual_budget,
    ROUND(d.annual_budget / 12.0, 2) AS monthly_budget_allocation,
    p.payroll_year,
    p.payroll_month,
    COUNT(DISTINCT p.employee_id) AS paid_headcount,
    SUM(p.basic_pay) AS total_basic_expenditure,
    SUM(p.overtime_pay) AS total_overtime_cost,
    SUM(p.gross_salary) AS total_gross_payroll,
    SUM(p.total_deductions) AS total_statutory_deductions,
    SUM(p.net_salary) AS total_net_disbursed,
    -- Percentage of monthly budget consumed by actual gross payroll
    ROUND((SUM(p.gross_salary) / NULLIF((d.annual_budget / 12.0), 0) * 100), 2) AS budget_utilization_pct
FROM payslips p
JOIN employees e ON p.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.department_id, d.dept_code, d.dept_name, d.annual_budget, p.payroll_year, p.payroll_month;

COMMENT ON VIEW vw_department_payroll_cost IS 'Departmental payroll spend versus budgeted financial allocation';

-- ============================================================================
-- 4. WINDOW FUNCTION VIEW: TOP EARNERS PER DEPARTMENT
-- Advanced ADBMS Feature: DENSE_RANK() and PERCENT_RANK() window functions
-- ============================================================================
CREATE OR REPLACE VIEW vw_department_top_earners AS
WITH ranked_payroll AS (
    SELECT 
        p.payroll_year,
        p.payroll_month,
        d.dept_name,
        e.emp_code,
        e.first_name || ' ' || e.last_name AS employee_name,
        des.designation_title,
        p.gross_salary,
        p.net_salary,
        -- Rank within department for that pay cycle
        DENSE_RANK() OVER (
            PARTITION BY p.payroll_year, p.payroll_month, e.department_id 
            ORDER BY p.gross_salary DESC
        ) AS dept_rank,
        -- Running cumulative payroll within the department
        SUM(p.gross_salary) OVER (
            PARTITION BY p.payroll_year, p.payroll_month, e.department_id 
            ORDER BY p.gross_salary DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_dept_spend
    FROM payslips p
    JOIN employees e ON p.employee_id = e.employee_id
    JOIN departments d ON e.department_id = d.department_id
    JOIN designations des ON e.designation_id = des.designation_id
)
SELECT * 
FROM ranked_payroll
WHERE dept_rank <= 3;

COMMENT ON VIEW vw_department_top_earners IS 'Top 3 compensation earners per department computed via DENSE_RANK window function';

-- ============================================================================
-- 5. MATERIALIZED VIEW: PRE-COMPUTED DEPARTMENT ANALYTICS
-- Advanced ADBMS Concept: Heavy analytical aggregations cached physically
-- on disk to serve executive dashboards in sub-millisecond query time.
-- Refreshed CONCURRENTLY using an explicit unique index.
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS mv_department_payroll_analytics CASCADE;

CREATE MATERIALIZED VIEW mv_department_payroll_analytics AS
SELECT 
    d.department_id,
    d.dept_code,
    d.dept_name,
    p.payroll_year,
    p.payroll_month,
    COUNT(p.payslip_id) AS employee_count,
    ROUND(AVG(p.gross_salary), 2) AS avg_gross_salary,
    ROUND(MIN(p.gross_salary), 2) AS min_gross_salary,
    ROUND(MAX(p.gross_salary), 2) AS max_gross_salary,
    SUM(p.gross_salary) AS total_gross_spend,
    SUM(p.pf_deduction) AS total_pf_contribution,
    SUM(p.tax_deduction) AS total_tds_remitted,
    SUM(p.net_salary) AS total_net_disbursed,
    CURRENT_TIMESTAMP AS last_refreshed_at
FROM payslips p
JOIN employees e ON p.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.department_id, d.dept_code, d.dept_name, p.payroll_year, p.payroll_month
WITH DATA;

-- Mandatory UNIQUE INDEX on the materialized view to enable CONCURRENT REFRESH
-- without locking concurrent reader queries!
CREATE UNIQUE INDEX idx_mv_dept_payroll_unique 
    ON mv_department_payroll_analytics (department_id, payroll_year, payroll_month);

-- Stored Procedure to Refresh the Materialized View
CREATE OR REPLACE PROCEDURE refresh_payroll_analytics_mv()
LANGUAGE plpgsql
AS $$
BEGIN
    -- CONCURRENTLY allows SELECT queries against the materialized view while refreshing
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_department_payroll_analytics;
    RAISE NOTICE 'Materialized view mv_department_payroll_analytics refreshed successfully at %', CURRENT_TIMESTAMP;
END;
$$;

COMMENT ON MATERIALIZED VIEW mv_department_payroll_analytics IS 'Physically cached department payroll metrics refreshed concurrently';
