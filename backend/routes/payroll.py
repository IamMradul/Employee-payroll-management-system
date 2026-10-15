# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Payroll Batch Operations, Partitioned Payslips & PDF Generation
# ============================================================================

import io
from fastapi import APIRouter, HTTPException, Header, Response
from pydantic import BaseModel
from typing import Optional
from db import get_db_cursor
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from reportlab.lib import colors

router = APIRouter(prefix="/api/payroll", tags=["Payroll & Payslips"])

class ProcessPayrollRequest(BaseModel):
    year: int
    month: int

def get_auth_context(x_role: str = Header("ADMIN"), x_employee_id: Optional[str] = Header(None)):
    emp_id = int(x_employee_id) if x_employee_id and x_employee_id.isdigit() else None
    return x_role.upper(), emp_id

@router.get("/runs")
def list_payroll_runs():
    sql = """
        SELECT pr.*, u.username AS processed_by_username
        FROM payroll_runs pr
        LEFT JOIN users u ON pr.processed_by = u.user_id
        ORDER BY pr.payroll_year DESC, pr.payroll_month DESC;
    """
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql)
        runs = cur.fetchall()
    return {"runs": runs}

@router.post("/process")
def trigger_batch_payroll(
    req: ProcessPayrollRequest,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)
    if role not in ["ADMIN", "ACCOUNTANT"]:
        raise HTTPException(status_code=403, detail="Only Accountant or Admin can process payroll")

    # Invocates the PL/pgSQL Stored Procedure with cursor and transaction savepoints
    call_sql = "CALL process_monthly_payroll(%s, %s, %s);"

    try:
        with get_db_cursor(role=role, employee_id=current_emp) as cur:
            cur.execute(call_sql, (req.year, req.month, current_emp))

        # Retrieve the generated batch run details
        with get_db_cursor(role=role, employee_id=current_emp) as cur:
            cur.execute("SELECT * FROM payroll_runs WHERE payroll_year = %s AND payroll_month = %s;", (req.year, req.month))
            run_info = cur.fetchone()

        return {
            "status": "success",
            "message": f"Payroll batch processed successfully for {req.year}-{req.month:02d}",
            "payroll_run": run_info
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/approve/{run_id}")
def approve_payroll(
    run_id: int,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)
    if role not in ["ADMIN", "ACCOUNTANT"]:
        raise HTTPException(status_code=403, detail="Only Accountant or Admin can approve payroll")

    try:
        with get_db_cursor(role=role, employee_id=current_emp) as cur:
            cur.execute("CALL approve_payroll_run(%s);", (run_id,))
        return {"status": "success", "message": f"Payroll run {run_id} approved"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/disburse/{run_id}")
def disburse_payroll_run(
    run_id: int,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)
    if role not in ["ADMIN", "ACCOUNTANT"]:
        raise HTTPException(status_code=403, detail="Only Accountant or Admin can disburse payroll")

    try:
        with get_db_cursor(role=role, employee_id=current_emp) as cur:
            cur.execute("CALL disburse_payroll(%s);", (run_id,))
        return {"status": "success", "message": f"Payroll run {run_id} disbursed and paid out successfully"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/payslips")
def list_payslips(
    year: Optional[int] = None,
    month: Optional[int] = None,
    employee_id: Optional[int] = None,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)

    # Note: RLS automatically applies to this query!
    # If role='EMPLOYEE', PostgreSQL only returns rows matching current_employee_id.
    sql = """
        SELECT p.payslip_id, p.payroll_year, p.payroll_month, p.employee_id,
               e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
               d.dept_code, d.dept_name, des.designation_title,
               p.total_working_days, p.days_present, p.loss_of_pay_days,
               p.gross_salary, p.total_deductions, p.net_salary,
               p.payment_status, p.payment_date, p.generated_at
        FROM payslips p
        JOIN employees e ON p.employee_id = e.employee_id
        JOIN departments d ON e.department_id = d.department_id
        JOIN designations des ON e.designation_id = des.designation_id
        WHERE 1=1
    """
    params = []

    if year:
        sql += " AND p.payroll_year = %s"
        params.append(year)
    if month:
        sql += " AND p.payroll_month = %s"
        params.append(month)
    if employee_id and role != "EMPLOYEE":
        sql += " AND p.employee_id = %s"
        params.append(employee_id)

    sql += " ORDER BY p.payroll_year DESC, p.payroll_month DESC, e.emp_code LIMIT 100;"

    with get_db_cursor(role=role, employee_id=current_emp) as cur:
        cur.execute(sql, tuple(params))
        payslips = cur.fetchall()

    return {"count": len(payslips), "payslips": payslips}

@router.get("/payslips/{payslip_id}")
def get_payslip_detail(
    payslip_id: int,
    year: Optional[int] = None,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    role, current_emp = get_auth_context(x_role, x_employee_id)

    # If year is provided, partition pruning activates immediately!
    sql = """
        SELECT p.*, e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
               e.email, e.pan_number, e.bank_name, e.bank_account_no, e.ifsc_code,
               d.dept_name, des.designation_title
        FROM payslips p
        JOIN employees e ON p.employee_id = e.employee_id
        JOIN departments d ON e.department_id = d.department_id
        JOIN designations des ON e.designation_id = des.designation_id
        WHERE p.payslip_id = %s
    """
    params = [payslip_id]
    if year:
        sql += " AND p.payroll_year = %s"
        params.append(year)

    with get_db_cursor(role=role, employee_id=current_emp) as cur:
        cur.execute(sql, tuple(params))
        payslip = cur.fetchone()

    if not payslip:
        raise HTTPException(status_code=404, detail="Payslip not found or access denied by RLS policy")

    return {"payslip": payslip}

@router.get("/payslips/{payslip_id}/pdf")
def download_payslip_pdf(
    payslip_id: int,
    year: Optional[int] = None,
    x_role: str = Header("ADMIN"),
    x_employee_id: Optional[str] = Header(None)
):
    """Generates an official PDF payslip on the fly using ReportLab."""
    role, current_emp = get_auth_context(x_role, x_employee_id)

    sql = """
        SELECT p.*, e.emp_code, e.first_name || ' ' || e.last_name AS employee_name,
               e.email, e.pan_number, e.bank_name, e.bank_account_no, e.ifsc_code,
               d.dept_name, des.designation_title
        FROM payslips p
        JOIN employees e ON p.employee_id = e.employee_id
        JOIN departments d ON e.department_id = d.department_id
        JOIN designations des ON e.designation_id = des.designation_id
        WHERE p.payslip_id = %s
    """
    params = [payslip_id]
    if year:
        sql += " AND p.payroll_year = %s"
        params.append(year)

    with get_db_cursor(role=role, employee_id=current_emp) as cur:
        cur.execute(sql, tuple(params))
        p = cur.fetchone()

    if not p:
        raise HTTPException(status_code=404, detail="Payslip not found or access denied")

    # Generate PDF in memory
    buffer = io.BytesIO()
    c = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter

    # Title & Header
    c.setFont("Helvetica-Bold", 16)
    c.drawString(50, height - 50, "ENTERPRISE TECHNOLOGIES LTD.")
    c.setFont("Helvetica", 10)
    c.drawString(50, height - 65, "Corporate Headquarters: Tower A, Tech Park, Bangalore, India")
    c.setStrokeColor(colors.HexColor("#334155"))
    c.setLineWidth(1)
    c.line(50, height - 75, width - 50, height - 75)

    # Sub-header
    c.setFont("Helvetica-Bold", 12)
    month_names = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    period_str = f"{month_names[p['payroll_month']]} {p['payroll_year']}"
    c.drawString(50, height - 95, f"SALARY PAYSLIP - {period_str.upper()}")
    c.setFont("Helvetica", 9)
    c.drawString(width - 200, height - 95, f"Ref: {p['payment_reference'] or 'PENDING'}")

    # Employee Information Grid
    c.setFillColor(colors.HexColor("#F8FAFC"))
    c.rect(50, height - 170, width - 100, 65, fill=1, stroke=1)
    c.setFillColor(colors.black)

    c.setFont("Helvetica-Bold", 9)
    c.drawString(60, height - 120, "Employee ID:")
    c.drawString(60, height - 135, "Employee Name:")
    c.drawString(60, height - 150, "Department:")
    c.drawString(60, height - 165, "Designation:")

    c.setFont("Helvetica", 9)
    c.drawString(150, height - 120, f"{p['emp_code']}")
    c.drawString(150, height - 135, f"{p['employee_name']}")
    c.drawString(150, height - 150, f"{p['dept_name']}")
    c.drawString(150, height - 165, f"{p['designation_title']}")

    c.setFont("Helvetica-Bold", 9)
    c.drawString(330, height - 120, "Bank:")
    c.drawString(330, height - 135, "Account No:")
    c.drawString(330, height - 150, "IFSC / PAN:")
    c.drawString(330, height - 165, "Days Present / LOP:")

    c.setFont("Helvetica", 9)
    c.drawString(420, height - 120, f"{p['bank_name']}")
    c.drawString(420, height - 135, f"XXXX{str(p['bank_account_no'])[-4:]}")
    c.drawString(420, height - 150, f"{p['ifsc_code']} / {p['pan_number']}")
    c.drawString(420, height - 165, f"{p['days_present']} / {p['loss_of_pay_days']}")

    # Earnings & Deductions Tables
    y = height - 200
    c.setFont("Helvetica-Bold", 10)
    c.setFillColor(colors.HexColor("#1E293B"))
    c.drawString(50, y, "EARNINGS (₹)")
    c.drawString(width / 2 + 10, y, "DEDUCTIONS (₹)")
    c.line(50, y - 5, width / 2 - 20, y - 5)
    c.line(width / 2 + 10, y - 5, width - 50, y - 5)

    earnings = [
        ("Basic Salary", f"{p['basic_pay']:,.2f}"),
        ("House Rent Allowance (HRA)", f"{p['hra']:,.2f}"),
        ("Dearness Allowance (DA)", f"{p['da']:,.2f}"),
        ("Special Allowance", f"{p['special_allowance']:,.2f}"),
        ("Flexible Allowances", f"{p['flexible_allowances_total']:,.2f}"),
        ("Overtime Pay", f"{p['overtime_pay']:,.2f}")
    ]

    deductions = [
        ("Provident Fund (PF)", f"{p['pf_deduction']:,.2f}"),
        ("Income Tax (TDS)", f"{p['tax_deduction']:,.2f}"),
        ("Insurance Premium", f"{p['insurance_deduction']:,.2f}"),
        ("Loss of Pay (LOP)", f"{p['lop_deduction']:,.2f}")
    ]

    c.setFont("Helvetica", 9)
    cur_y = y - 25
    for label, val in earnings:
        c.drawString(50, cur_y, label)
        c.drawRightString(width / 2 - 20, cur_y, val)
        cur_y -= 18

    ded_y = y - 25
    for label, val in deductions:
        c.drawString(width / 2 + 10, ded_y, label)
        c.drawRightString(width - 50, ded_y, val)
        ded_y -= 18

    # Totals Section
    total_y = min(cur_y, ded_y) - 15
    c.setLineWidth(1)
    c.line(50, total_y, width - 50, total_y)

    c.setFont("Helvetica-Bold", 10)
    c.drawString(50, total_y - 18, "GROSS EARNINGS:")
    c.drawRightString(width / 2 - 20, total_y - 18, f"₹ {p['gross_salary']:,.2f}")

    c.drawString(width / 2 + 10, total_y - 18, "TOTAL DEDUCTIONS:")
    c.drawRightString(width - 50, total_y - 18, f"₹ {p['total_deductions']:,.2f}")

    # Net Salary Highlight Box
    c.setFillColor(colors.HexColor("#0284C7"))
    c.rect(50, total_y - 65, width - 100, 35, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 12)
    c.drawString(70, total_y - 50, "NET DISBURSED SALARY:")
    c.drawRightString(width - 70, total_y - 50, f"₹ {p['net_salary']:,.2f}")

    # Footer
    c.setFillColor(colors.HexColor("#64748B"))
    c.setFont("Helvetica", 8)
    c.drawString(50, 50, "This is a computer-generated immutable payslip snapshot from PostgreSQL 15+ declarative partitioned EPMS.")
    c.drawRightString(width - 50, 50, f"Status: {p['payment_status']} | Generated: {str(p['generated_at'])[:19]}")

    c.showPage()
    c.save()

    buffer.seek(0)
    pdf_bytes = buffer.getvalue()

    filename = f"payslip_{p['emp_code']}_{p['payroll_year']}_{p['payroll_month']:02d}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
