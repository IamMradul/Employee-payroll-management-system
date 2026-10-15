# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Analytics, Materialized Views & Interactive ADBMS Query Console
# ============================================================================

import time
from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional
from db import get_db_cursor

router = APIRouter(prefix="/api/reports", tags=["Reports & ADBMS Analytics"])

class QueryExecutionRequest(BaseModel):
    query_id: int

# Catalog of the 16 Advanced ADBMS queries from 08_sample_queries.sql
ADBMS_QUERY_CATALOG = {
    1: {
        "title": "Recursive CTE: Organizational Hierarchy",
        "concept": "Recursive CTE with anchor & recursive members, tree path tracking",
        "sql": """
            WITH RECURSIVE employee_hierarchy AS (
                SELECT e.employee_id, e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
                       des.designation_title, d.dept_name, e.manager_id, 1 AS level,
                       (e.first_name || ' ' || e.last_name)::TEXT AS management_chain
                FROM employees e
                JOIN designations des ON e.designation_id = des.designation_id
                JOIN departments d ON e.department_id = d.department_id
                WHERE e.manager_id IS NULL AND e.status = 'ACTIVE'
                UNION ALL
                SELECT sub.employee_id, sub.emp_code, sub.first_name || ' ' || sub.last_name AS employee_name,
                       des.designation_title, d.dept_name, sub.manager_id, eh.level + 1 AS level,
                       (eh.management_chain || ' -> ' || sub.first_name || ' ' || sub.last_name)::TEXT
                FROM employees sub
                JOIN designations des ON sub.designation_id = des.designation_id
                JOIN departments d ON sub.department_id = d.department_id
                JOIN employee_hierarchy eh ON sub.manager_id = eh.employee_id
                WHERE sub.status = 'ACTIVE'
            )
            SELECT level, emp_code, employee_name, designation_title, dept_name, management_chain
            FROM employee_hierarchy
            ORDER BY level, dept_name, employee_name;
        """
    },
    2: {
        "title": "Window Function: Running Cumulative Payroll Cost",
        "concept": "SUM() OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)",
        "sql": """
            SELECT d.dept_name, e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
                   p.gross_salary,
                   SUM(p.gross_salary) OVER (
                       PARTITION BY e.department_id 
                       ORDER BY p.gross_salary DESC
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                   ) AS running_dept_spend,
                   SUM(p.gross_salary) OVER (PARTITION BY e.department_id) AS total_dept_gross,
                   ROUND((p.gross_salary / SUM(p.gross_salary) OVER (PARTITION BY e.department_id) * 100), 2) AS pct_of_dept
            FROM payslips p
            JOIN employees e ON p.employee_id = e.employee_id
            JOIN departments d ON e.department_id = d.department_id
            WHERE p.payroll_year = 2026 AND p.payroll_month = 2
            ORDER BY d.dept_name, p.gross_salary DESC;
        """
    },
    3: {
        "title": "Window Function: Salary Quartiles & Percentiles",
        "concept": "NTILE(4), PERCENT_RANK(), DENSE_RANK()",
        "sql": """
            SELECT e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
                   des.designation_title, d.dept_name, s.basic_pay,
                   NTILE(4) OVER (ORDER BY s.basic_pay) AS quartile,
                   ROUND((PERCENT_RANK() OVER (ORDER BY s.basic_pay))::NUMERIC, 3) AS percentile,
                   DENSE_RANK() OVER (ORDER BY s.basic_pay DESC) AS company_rank
            FROM employees e
            JOIN salary_structures s ON e.employee_id = s.employee_id AND s.is_current = TRUE
            JOIN designations des ON e.designation_id = des.designation_id
            JOIN departments d ON e.department_id = d.department_id
            WHERE e.status = 'ACTIVE'
            ORDER BY s.basic_pay DESC;
        """
    },
    4: {
        "title": "Window Function: Peer Offsets using LAG() and LEAD()",
        "concept": "LAG(), LEAD(), Partitioned peer delta comparison",
        "sql": """
            SELECT d.dept_name, e.first_name || ' ' || e.last_name AS employee_name,
                   des.designation_title, s.basic_pay,
                   LAG(s.basic_pay, 1) OVER (PARTITION BY e.department_id ORDER BY s.basic_pay DESC) AS higher_peer_salary,
                   LEAD(s.basic_pay, 1) OVER (PARTITION BY e.department_id ORDER BY s.basic_pay DESC) AS lower_peer_salary,
                   ROUND(s.basic_pay - AVG(s.basic_pay) OVER (PARTITION BY e.department_id), 2) AS delta_from_avg
            FROM employees e
            JOIN salary_structures s ON e.employee_id = s.employee_id AND s.is_current = TRUE
            JOIN designations des ON e.designation_id = des.designation_id
            JOIN departments d ON e.department_id = d.department_id
            WHERE e.status = 'ACTIVE'
            ORDER BY d.dept_name, s.basic_pay DESC;
        """
    },
    5: {
        "title": "Semi-Structured Data: JSONB Containment & Flexible Allowances",
        "concept": "JSONB Operators (@>, ->>) & GIN Index query",
        "sql": """
            SELECT e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
                   d.dept_name,
                   s.flexible_allowances->>'broadband' AS broadband,
                   s.flexible_allowances->>'wellness' AS wellness,
                   s.flexible_allowances->>'fuel' AS fuel,
                   s.flexible_allowances
            FROM salary_structures s
            JOIN employees e ON s.employee_id = e.employee_id
            JOIN departments d ON e.department_id = d.department_id
            WHERE s.is_current = TRUE
              AND s.flexible_allowances ? 'broadband'
            ORDER BY e.emp_code;
        """
    },
    6: {
        "title": "Correlated Subquery: Above Department Average Earners",
        "concept": "Correlated Subquery referencing outer relation",
        "sql": """
            SELECT e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
                   d.dept_name, s.basic_pay,
                   (
                       SELECT ROUND(AVG(s2.basic_pay), 2)
                       FROM employees e2
                       JOIN salary_structures s2 ON e2.employee_id = s2.employee_id AND s2.is_current = TRUE
                       WHERE e2.department_id = e.department_id AND e2.status = 'ACTIVE'
                   ) AS dept_average_basic
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
        """
    },
    7: {
        "title": "Attendance Matrix via Conditional Aggregation",
        "concept": "COUNT(*) FILTER (WHERE ...) and Status Pivot",
        "sql": """
            SELECT e.emp_code, e.first_name || ' ' || e.last_name AS employee_name, d.dept_code,
                   COUNT(*) FILTER (WHERE a.status = 'PRESENT') AS days_present,
                   COUNT(*) FILTER (WHERE a.status = 'HALF_DAY') AS days_half_day,
                   COUNT(*) FILTER (WHERE a.status = 'ON_LEAVE') AS days_leave,
                   COUNT(*) FILTER (WHERE a.status = 'ABSENT') AS days_absent,
                   SUM(a.overtime_hours) AS overtime_hours
            FROM attendance a
            JOIN employees e ON a.employee_id = e.employee_id
            JOIN departments d ON e.department_id = d.department_id
            WHERE a.attendance_date BETWEEN '2026-02-01' AND '2026-02-28'
            GROUP BY e.employee_id, e.emp_code, e.first_name, e.last_name, d.dept_code
            ORDER BY d.dept_code, e.emp_code;
        """
    },
    8: {
        "title": "Materialized View Analytics (Cached Instant Metrics)",
        "concept": "Pre-computed Materialized View with CONCURRENT REFRESH",
        "sql": """
            SELECT dept_code, dept_name, payroll_year, payroll_month,
                   employee_count, avg_gross_salary, total_gross_spend,
                   total_net_disbursed, last_refreshed_at
            FROM mv_department_payroll_analytics
            ORDER BY payroll_year DESC, payroll_month DESC, dept_code;
        """
    }
}

@router.get("/department-cost")
def get_department_cost(year: int = 2026, month: int = 2):
    sql = """
        SELECT * FROM vw_department_payroll_cost
        WHERE payroll_year = %s AND payroll_month = %s
        ORDER BY total_gross_payroll DESC;
    """
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql, (year, month))
        costs = cur.fetchall()
    return {"department_costs": costs}

@router.get("/top-earners")
def get_top_earners(year: int = 2026, month: int = 2):
    sql = """
        SELECT * FROM vw_department_top_earners
        WHERE payroll_year = %s AND payroll_month = %s
        ORDER BY dept_name, dept_rank;
    """
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql, (year, month))
        earners = cur.fetchall()
    return {"top_earners": earners}

@router.get("/materialized-view")
def get_materialized_view_data():
    sql = "SELECT * FROM mv_department_payroll_analytics ORDER BY payroll_year DESC, payroll_month DESC, dept_code;"
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql)
        data = cur.fetchall()
    return {"materialized_view_data": data}

@router.post("/materialized-view/refresh")
def refresh_materialized_view():
    try:
        with get_db_cursor(role="ADMIN") as cur:
            cur.execute("CALL refresh_payroll_analytics_mv();")
        return {"status": "success", "message": "Materialized View refreshed concurrently"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/adbms-queries")
def get_adbms_query_list():
    return {
        "queries": [
            {"id": qid, "title": qinfo["title"], "concept": qinfo["concept"]}
            for qid, qinfo in ADBMS_QUERY_CATALOG.items()
        ]
    }

@router.post("/execute-adbms-query")
def execute_adbms_query(req: QueryExecutionRequest):
    if req.query_id not in ADBMS_QUERY_CATALOG:
        raise HTTPException(status_code=404, detail="Query ID not found in ADBMS catalog")

    q = ADBMS_QUERY_CATALOG[req.query_id]
    start_time = time.time()

    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(q["sql"])
        rows = cur.fetchall()
        columns = [desc[0] for desc in cur.description] if cur.description else []

    elapsed_ms = round((time.time() - start_time) * 1000, 2)

    return {
        "query_id": req.query_id,
        "title": q["title"],
        "concept": q["concept"],
        "sql": q["sql"].strip(),
        "columns": columns,
        "rows": rows,
        "row_count": len(rows),
        "execution_time_ms": elapsed_ms
    }
