# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Configuration Module
# ============================================================================

import os
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "payroll_db")
DB_USER = os.getenv("DB_USER", "postgres") # or epms_app_user
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")

# Connection Pool Settings
DB_MIN_CONN = int(os.getenv("DB_MIN_CONN", "2"))
DB_MAX_CONN = int(os.getenv("DB_MAX_CONN", "15"))

API_HOST = os.getenv("API_HOST", "127.0.0.1")
API_PORT = int(os.getenv("API_PORT", "8000"))
SECRET_KEY = os.getenv("SECRET_KEY", "epms_adbms_secret_token_2026")
