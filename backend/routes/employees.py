# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Employee Master & Organizational Hierarchy Routes
# ============================================================================

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional, List
from db import get_db_cursor

router = APIRouter(prefix="/api", tags=["Employees & Organization"])

class EmployeeCreateRequest(BaseModel):
    emp_code: str
    first_name: str
    last_name: str
    email: str
    phone: str
    date_of_birth: str # YYYY-MM-DD
    gender: str
    department_id: int
    designation_id: int
    manager_id: Optional[int] = None
    joining_date: str
    status: str = "ACTIVE"
    bank_account_no: str
    bank_name: str
    ifsc_code: str
    pan_number: str

def get_auth_context(x_role: str = Header("ADMIN"), x_employee_id: Optional[str] = Header(None)):
    emp_id = int(x_employee_id) if x_employee_id and x_employee_id.isdigit() else None
    return x_role.upper(), emp_id

@router.get("/employees")
def list_employees(
    department_id: Optional[int] = None,
    status: Optional[str] = None,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, emp_id = get_auth_context(x_role, x_employee_id)

    # Raw SQL using the pre-defined vw_employee_directory
    sql = """
        SELECT 
            employee_id, emp_code, full_name, email, phone, gender,
            employment_status, joining_date, dept_code, dept_name,
            designation_title, pay_grade, manager_code, manager_name
        FROM vw_employee_directory
        WHERE 1=1
    """
    params = []

    if department_id:
        sql += " AND dept_code = (SELECT dept_code FROM departments WHERE department_id = %s)"
        params.append(department_id)
    if status:
        sql += " AND employment_status = %s"
        params.append(status)

    sql += " ORDER BY employee_id;"

    with get_db_cursor(role=role, employee_id=emp_id) as cur:
        cur.execute(sql, tuple(params))
        employees = cur.fetchall()

    return {"count": len(employees), "employees": employees}

@router.get("/employees/{emp_id}")
def get_employee_details(
    emp_id: int,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)

    sql = """
        SELECT e.*, d.dept_name, d.dept_code, des.designation_title, des.pay_grade,
               m.first_name || ' ' || m.last_name AS manager_name
        FROM employees e
        JOIN departments d ON e.department_id = d.department_id
        JOIN designations des ON e.designation_id = des.designation_id
        LEFT JOIN employees m ON e.manager_id = m.employee_id
        WHERE e.employee_id = %s;
    """

    salary_sql = """
        SELECT * FROM salary_structures
        WHERE employee_id = %s AND is_current = TRUE;
    """

    with get_db_cursor(role=role, employee_id=current_emp) as cur:
        cur.execute(sql, (emp_id,))
        emp = cur.fetchone()
        if not emp:
            raise HTTPException(status_code=404, detail="Employee not found")

        cur.execute(salary_sql, (emp_id,))
        salary = cur.fetchone()

    return {"employee": emp, "salary_structure": salary}

@router.post("/employees")
def create_employee(
    emp: EmployeeCreateRequest,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)
    if role not in ["ADMIN", "HR"]:
        raise HTTPException(status_code=403, detail="Only HR or Admin can register employees")

    sql = """
        INSERT INTO employees (
            emp_code, first_name, last_name, email, phone, date_of_birth,
            gender, department_id, designation_id, manager_id, joining_date,
            status, bank_account_no, bank_name, ifsc_code, pan_number
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) RETURNING employee_id;
    """

    try:
        with get_db_cursor(role=role, employee_id=current_emp) as cur:
            cur.execute(sql, (
                emp.emp_code, emp.first_name, emp.last_name, emp.email, emp.phone,
                emp.date_of_birth, emp.gender, emp.department_id, emp.designation_id,
                emp.manager_id, emp.joining_date, emp.status, emp.bank_account_no,
                emp.bank_name, emp.ifsc_code, emp.pan_number
            ))
            new_id = cur.fetchone()["employee_id"]
        return {"status": "success", "employee_id": new_id, "message": "Employee created successfully"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/departments")
def list_departments():
    sql = """
        SELECT d.*, COUNT(e.employee_id) AS employee_count
        FROM departments d
        LEFT JOIN employees e ON d.department_id = e.department_id AND e.status = 'ACTIVE'
        GROUP BY d.department_id
        ORDER BY d.department_id;
    """
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql)
        departments = cur.fetchall()
    return {"departments": departments}

@router.get("/designations")
def list_designations():
    sql = "SELECT * FROM designations ORDER BY pay_grade DESC, designation_id;"
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql)
        designations = cur.fetchall()
    return {"designations": designations}

@router.get("/organization/hierarchy")
def get_organization_hierarchy():
    """Demonstrates Recursive CTE traversal of the managerial chain."""
    sql = "SELECT * FROM vw_organization_hierarchy;"
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql)
        hierarchy = cur.fetchall()
    return {"hierarchy": hierarchy}
