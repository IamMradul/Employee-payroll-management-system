# ============================================================================
# ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
# System: Employee Payroll Management System (EPMS)
# Database Driver & RLS Connection Pool Manager
# ============================================================================

import logging
from contextlib import contextmanager
import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_MIN_CONN, DB_MAX_CONN

logger = logging.getLogger("epms.db")
logging.basicConfig(level=logging.INFO)

# Global Threaded Connection Pool
_pool = None

def init_db_pool():
    global _pool
    if _pool is None:
        try:
            _pool = pool.ThreadedConnectionPool(
                minconn=DB_MIN_CONN,
                maxconn=DB_MAX_CONN,
                host=DB_HOST,
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD
            )
            logger.info("PostgreSQL Threaded Connection Pool initialized successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize PostgreSQL Connection Pool: {e}")
            raise e

def close_db_pool():
    global _pool
    if _pool is not None:
        _pool.closeall()
        logger.info("PostgreSQL Connection Pool closed.")
        _pool = None

@contextmanager
def get_db_cursor(role: str = "ADMIN", employee_id: int = None, commit: bool = True):
    """
    Context manager that yields a dictionary-based cursor from the pool.
    Critically, it injects transaction-scoped session parameters (SET LOCAL)
    so Row-Level Security (RLS) dynamically applies per HTTP request
    without connection leakage across pooled connections.
    """
    global _pool
    if _pool is None:
        init_db_pool()

    conn = _pool.getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Set transaction-scoped RLS session variables (immune to reserved keyword parsing)
            cur.execute("SELECT set_config('app.current_role', %s, true);", (role,))
            cur.execute("SELECT set_config('app.current_employee_id', %s, true);", (str(employee_id) if employee_id is not None else '',))

            yield cur

        if commit:
            conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(f"Database transaction error: {e}")
        raise e
    finally:
        _pool.putconn(conn)
