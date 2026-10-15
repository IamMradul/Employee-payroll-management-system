# Employee Payroll Management System (EPMS)
### Advanced Database Management Systems (ADBMS) Course Project

[![PostgreSQL 15+](https://img.shields.io/badge/PostgreSQL-15%2B-blue.svg)](https://www.postgresql.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100%2B-green.svg)](https://fastapi.tiangolo.com/)
[![psycopg2](https://img.shields.io/badge/Driver-psycopg2-orange.svg)](https://www.psycopg.org/)
[![Status](https://img.shields.io/badge/Status-Complete-emerald.svg)]()

EPMS is an enterprise-grade payroll processing system engineered specifically for an **Advanced Database Management Systems (ADBMS)** course. Rather than treating PostgreSQL as a dumb storage store with heavy ORMs, EPMS moves critical business logic, financial snapshots, constraint enforcement, and audit automation directly into the database engine.

---

## 🌟 Advanced DBMS Concepts Demonstrated

1. **Declarative Range Partitioning**: `payslips` partitioned by `payroll_year` with automatic **partition pruning** by the PostgreSQL query planner.
2. **GiST Exclusion Constraints (`btree_gist`)**: Temporal validity enforcement preventing overlapping salary structures for the same employee.
3. **Row-Level Security (RLS)**: Transaction-scoped tenant isolation (`SET LOCAL app.current_role` / `SET LOCAL app.current_employee_id`) tailored specifically for web connection pooling.
4. **PL/pgSQL Procedures & Cursors**: Memory-efficient batch cursor processing in `process_monthly_payroll` with row-level transaction `SAVEPOINT` fault tolerance.
5. **DML Automation Triggers**:
   - `trg_validate_employee_age`: Enforces age $\ge 18$ at employment safely across `pg_restore` cycles.
   - `trg_audit_salary_changes`: Automatically writes full before/after JSONB deltas to `salary_change_audit`.
   - `trg_prevent_negative_salary`: Guarantees deductions never exceed gross pay.
   - `trg_manage_leave_balance`: Real-time deduction and rollback of leave quota upon approval.
6. **Materialized Views with Concurrent Refresh**: Pre-computed department metrics in `mv_department_payroll_analytics` refreshed without table locks using `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
7. **Recursive Common Table Expressions (CTE)**: Traverses the self-referencing managerial tree to resolve the organization reporting hierarchy.
8. **Window Functions**: `DENSE_RANK()`, `SUM() OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`, `NTILE(4)`, `LAG()`, and `LEAD()`.
9. **Semi-Structured Storage (JSONB & GIN)**: `flexible_allowances` and `salary_breakdown_json` indexed with `jsonb_path_ops`.
10. **Partial Indexes**: Low-footprint indexes for active employees and pending leave workflows.

---

## 📂 Project Directory Structure

```
employee-payroll-management-system/
├── database/
│   ├── 01_schema.sql         # Extensions, ENUMs, sequences, partitioned tables, btree_gist
│   ├── 02_indexes.sql        # B-tree FKs, composite, partial, GIN indexes, EXPLAIN ANALYZE
│   ├── 03_functions.sql      # PL/pgSQL: calculate_tax, calculate_employee_salary, cursors
│   ├── 04_triggers.sql       # Age validation, salary audit, negative blocker, leave balance sync
│   ├── 05_views.sql          # Recursive hierarchy CTE, department costs, Materialized View
│   ├── 06_roles.sql          # DB Roles, grants, Row-Level Security policies with SET LOCAL
│   ├── 07_seed_data.sql      # 28 employees, 6 months attendance & 6 months payroll ledger
│   ├── 08_sample_queries.sql # 16 advanced ADBMS queries (CTEs, Window, JSONB, Pruning)
│   └── setup_all.sql         # Master runner executing all SQL migration scripts in order
├── backend/
│   ├── config.py             # Connection settings & environment variables
│   ├── db.py                 # psycopg2 ThreadedConnectionPool with SET LOCAL RLS injection
│   ├── main.py               # FastAPI entrypoint, CORS, static frontend mount
│   ├── requirements.txt      # fastapi, uvicorn, psycopg2-binary, reportlab
│   └── routes/
│       ├── auth.py           # Login, demo users & role context
│       ├── employees.py      # Employee CRUD, departments, recursive CTE hierarchy endpoint
│       ├── attendance.py     # Attendance logs, leave quotas, leave approval triggers
│       ├── payroll.py        # Procedure trigger, approval, payout, payslip PDF generator
│       └── reports.py        # Department costs, materialized view refresh, live query console
├── frontend/
│   ├── index.html            # Single page dashboard with role switcher & 8 tab panels
│   ├── css/
│   │   └── styles.css        # Glassmorphic dark theme, responsive tables, badge pills
│   └── js/
│       ├── api.js            # Fetch wrapper injecting dynamic x-role & x-employee-id headers
│       ├── app.js            # Tab navigation, modals, batch runs, ADBMS live query runner
│       └── charts.js         # Chart.js department breakdown & 6-month payroll spend trends
├── docs/
│   ├── test_plan.md          # 13 verified test cases with queries & expected outputs
│   └── viva_guide.md         # Architecture defense & 15 tough examiner questions with answers
└── README.md                 # Setup guide, PostgreSQL commands & quickstart
```

---

## 🚀 Setup & Execution Guide

### 1. PostgreSQL Database Setup
Open PowerShell or your terminal and create the project database:

```bash
# Create database
createdb -U postgres payroll_db

# Run the master setup script to execute all 7 SQL files in order:
psql -U postgres -d payroll_db -f database/setup_all.sql
```

*(Alternatively, you can run `psql -U postgres -d payroll_db` and execute `\i database/setup_all.sql`).*

---

### 2. Backend Setup (FastAPI & psycopg2)

Navigate to the `backend` folder:

```bash
cd backend

# Create and activate Python virtual environment
python -m venv venv

# Windows PowerShell:
.\venv\Scripts\Activate.ps1
# (or Linux / macOS: source venv/bin/activate)

# Install dependencies
pip install -r requirements.txt

# Start the FastAPI server (serves API and Frontend simultaneously)
python main.py
# or: uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

---

### 3. Accessing the Application
Open your web browser and navigate to:
👉 **`http://127.0.0.1:8000/`**

The user interface features a live **Role Switcher** in the top navigation bar to test permissions and Row-Level Security:
- **ADMIN**: Vikram Aditya (CEO / Full Access)
- **HR**: Priya Sundaram (Head of People / Leaves & Directory)
- **ACCOUNTANT**: Rajesh Nambiar (CFO / Payroll Runs & Disbursements)
- **EMPLOYEE**: Arjun Reddy (Emp #12 / RLS Restricted to Self Only)

*(Default test password for all demo accounts: `Password@123`)*

---

## 💾 Database Backup & Restore Commands (For Evaluation)

Examiners often request backup and restore commands:

### Backup (pg_dump)
```bash
# Create custom compressed archive backup:
pg_dump -U postgres -F c -b -v -f payroll_backup.dump payroll_db

# Create plain SQL script backup:
pg_dump -U postgres -F p -v -f payroll_backup.sql payroll_db
```

### Restore (pg_restore)
```bash
# Restore to a fresh database:
createdb -U postgres payroll_db_restored
pg_restore -U postgres -d payroll_db_restored -v payroll_backup.dump
```
*(Because we avoided non-immutable functions in table constraints, this database restores with zero errors!)*

---

## 🧪 Documentation Links
- **[Test Plan & Test Cases](docs/test_plan.md)**: 13 concrete tests covering GiST exclusion, RLS isolation, triggers, and cursors.
- **[Viva & Defense Guide](docs/viva_guide.md)**: 15 deep examiner questions with comprehensive theoretical and architectural answers.
