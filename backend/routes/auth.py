# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Auth Routes (User Verification & Role Context)
# ============================================================================

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
import hashlib
from db import get_db_cursor

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

class LoginRequest(BaseModel):
    username: str
    password: str

class SwitchRoleRequest(BaseModel):
    role: str
    employee_id: int = None

def hash_password(pwd: str) -> str:
    return hashlib.sha256(pwd.encode()).hexdigest()

@router.post("/login")
def login(req: LoginRequest):
    pwd_hash = hash_password(req.password)
    
    # Raw SQL lookup on users joined with employees
    sql = """
        SELECT u.user_id, u.username, u.role, u.is_active, 
               e.employee_id, e.emp_code, e.first_name, e.last_name, e.email
        FROM users u
        LEFT JOIN employees e ON u.user_id = e.user_id
        WHERE u.username = %s AND u.password_hash = %s AND u.is_active = TRUE;
    """
    
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql, (req.username, pwd_hash))
        user = cur.fetchone()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid username or password")

    return {
        "status": "success",
        "user": {
            "user_id": user["user_id"],
            "username": user["username"],
            "role": user["role"],
            "employee_id": user["employee_id"],
            "emp_code": user["emp_code"],
            "full_name": f"{user['first_name']} {user['last_name']}" if user["first_name"] else user["username"],
            "email": user["email"]
        }
    }

@router.get("/demo-users")
def get_demo_users():
    """Returns sample logins across all 4 roles for easy viva and grading evaluation."""
    sql = """
        SELECT u.username, u.role, e.employee_id, e.emp_code, 
               e.first_name || ' ' || e.last_name AS employee_name,
               des.designation_title
        FROM users u
        LEFT JOIN employees e ON u.user_id = e.user_id
        LEFT JOIN designations des ON e.designation_id = des.designation_id
        WHERE u.username IN ('admin', 'hr_lead', 'accountant', 'emp01', 'emp12', 'emp18')
        ORDER BY u.user_id;
    """
    with get_db_cursor(role="ADMIN") as cur:
        cur.execute(sql)
        users = cur.fetchall()

    return {"demo_users": users, "default_password": "Password@123"}
