# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Main FastAPI Application Entrypoint
# ============================================================================

import os
import sys
from contextlib import asynccontextmanager

# Ensure backend directory is in Python path regardless of execution directory
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from config import API_HOST, API_PORT
from db import init_db_pool, close_db_pool
from routes import auth, employees, attendance, payroll, reports

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize DB Pool
    init_db_pool()
    yield
    # Shutdown: Close DB Pool
    close_db_pool()

app = FastAPI(
    title="Employee Payroll Management System (EPMS)",
    description="Advanced Database Management Systems (ADBMS) Course Project API with PostgreSQL 15+",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for local development and browser testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API routers
app.include_router(auth.router)
app.include_router(employees.router)
app.include_router(attendance.router)
app.include_router(payroll.router)
app.include_router(reports.router)

# Mount frontend static directory if exists
frontend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend"))
if os.path.exists(frontend_dir):
    app.mount("/static", StaticFiles(directory=frontend_dir), name="static")

    @app.get("/")
    def serve_frontend():
        return FileResponse(os.path.join(frontend_dir, "index.html"))

@app.get("/api/health")
def health_check():
    return {
        "status": "healthy",
        "system": "Employee Payroll Management System (EPMS)",
        "database": "PostgreSQL 15+",
        "features": [
            "Declarative Partitioning",
            "GiST Exclusion Constraints",
            "Row-Level Security (RLS)",
            "PL/pgSQL Cursors & Savepoints",
            "Materialized Views Concurrently Refreshed",
            "Recursive CTEs & Window Functions"
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=API_HOST, port=API_PORT, reload=True)
