# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Attendance & Leave Management Routes
# ============================================================================

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional
from db import get_db_cursor

router = APIRouter(prefix="/api", tags=["Attendance & Leaves"])

class LeaveApplicationRequest(BaseModel):
    employee_id: int
    leave_type_id: int
    start_date: str # YYYY-MM-DD
    end_date: str   # YYYY-MM-DD
    days_count: float
    reason: str

class LeaveStatusUpdateRequest(BaseModel):
    status: str # 'APPROVED', 'REJECTED', 'CANCELLED'

def get_auth_context(x_role: str = Header("ADMIN"), x_employee_id: Optional[str] = Header(None)):
    emp_id = int(x_employee_id) if x_employee_id and x_employee_id.isdigit() else None
    return x_role.upper(), emp_id

@router.get("/attendance")
def get_attendance(
    employee_id: Optional[int] = None,
    month: Optional[int] = None,
    year: Optional[int] = None,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)

    # If employee role, enforce filtering to own data
    target_emp = current_emp if role == "EMPLOYEE" else employee_id

    sql = """
        SELECT a.attendance_id, a.employee_id, e.emp_code, 
               e.first_name || ' ' || e.last_name AS employee_name,
               a.attendance_date, a.check_in, a.check_out, 
               a.status, a.overtime_hours, a.remarks
        FROM attendance a
        JOIN employees e ON a.employee_id = e.employee_id
        WHERE 1=1
    """
    params = []

    if target_emp:
        sql += " AND a.employee_id = %s"
        params.append(target_emp)
    if year and month:
        sql += " AND EXTRACT(YEAR FROM a.attendance_date) = %s AND EXTRACT(MONTH FROM a.attendance_date) = %s"
        params.extend([year, month])

    sql += " ORDER BY a.attendance_date DESC LIMIT 100;"

    with get_db_cursor(role=role, employee_id=current_emp) as cur:
        cur.execute(sql, tuple(params))
        records = cur.fetchall()

    return {"count": len(records), "attendance": records}

@router.get("/leaves/balances")
def get_leave_balances(
    employee_id: Optional[int] = None,
    year: int = 2026,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)
    target_emp = current_emp if role == "EMPLOYEE" else (employee_id or 1)

    sql = """
        SELECT lb.balance_id, lb.employee_id, lt.leave_code, lt.leave_name,
               lb.year, lb.total_allocated, lb.leaves_used, lb.leaves_remaining,
               lt.is_paid
        FROM leave_balances lb
        JOIN leave_types lt ON lb.leave_type_id = lt.leave_type_id
        WHERE lb.employee_id = %s AND lb.year = %s
        ORDER BY lt.leave_type_id;
    """

    with get_db_cursor(role=role, employee_id=current_emp) as cur:
        cur.execute(sql, (target_emp, year))
        balances = cur.fetchall()

    return {"employee_id": target_emp, "year": year, "balances": balances}

@router.get("/leaves/applications")
def get_leave_applications(
    status: Optional[str] = None,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)

    # Filtered dynamically by RLS on leave_applications!
    sql = """
        SELECT la.leave_id, la.employee_id, e.emp_code, 
               e.first_name || ' ' || e.last_name AS employee_name,
               lt.leave_code, lt.leave_name, la.start_date, la.end_date,
               la.days_count, la.status, la.reason, la.applied_at, la.decided_at,
               m.first_name || ' ' || m.last_name AS approver_name
        FROM leave_applications la
        JOIN employees e ON la.employee_id = e.employee_id
        JOIN leave_types lt ON la.leave_type_id = lt.leave_type_id
        LEFT JOIN employees m ON la.approved_by = m.employee_id
        WHERE 1=1
    """
    params = []
    if status:
        sql += " AND la.status = %s"
        params.append(status)

    sql += " ORDER BY la.applied_at DESC;"

    with get_db_cursor(role=role, employee_id=current_emp) as cur:
        cur.execute(sql, tuple(params))
        apps = cur.fetchall()

    return {"applications": apps}

@router.post("/leaves/applications")
def apply_leave(
    app: LeaveApplicationRequest,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)
    emp_id = current_emp if role == "EMPLOYEE" else app.employee_id

    sql = """
        INSERT INTO leave_applications (
            employee_id, leave_type_id, start_date, end_date, days_count, reason, status
        ) VALUES (
            %s, %s, %s, %s, %s, %s, 'PENDING'
        ) RETURNING leave_id;
    """

    try:
        with get_db_cursor(role=role, employee_id=current_emp) as cur:
            cur.execute(sql, (emp_id, app.leave_type_id, app.start_date, app.end_date, app.days_count, app.reason))
            new_id = cur.fetchone()["leave_id"]
        return {"status": "success", "leave_id": new_id, "message": "Leave application submitted"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/leaves/applications/{leave_id}/status")
def update_leave_status(
    leave_id: int,
    req: LeaveStatusUpdateRequest,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)
    if role not in ["ADMIN", "HR"]:
        raise HTTPException(status_code=403, detail="Only HR or Admin can approve/reject leaves")

    # This UPDATE fires `trg_manage_leave_balance` trigger automatically!
    # If the employee lacks quota, the trigger raises an exception, aborting the transaction!
    sql = """
        UPDATE leave_applications
        SET status = %s,
            approved_by = %s,
            decided_at = CURRENT_TIMESTAMP
        WHERE leave_id = %s
        RETURNING leave_id, status;
    """

    try:
        with get_db_cursor(role=role, employee_id=current_emp) as cur:
            cur.execute(sql, (req.status, current_emp, leave_id))
            res = cur.fetchone()
            if not res:
                raise HTTPException(status_code=404, detail="Leave application not found")
        return {"status": "success", "leave_id": leave_id, "new_status": req.status}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Trigger validation error: {str(e)}")
