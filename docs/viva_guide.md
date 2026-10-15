# Employee Payroll Management System (EPMS)
## ADBMS Comprehensive Viva & Defense Guide

This guide is designed to help you ace your **Advanced Database Management Systems (ADBMS)** project evaluation. It explains the design decisions, architectural trade-offs, and provides high-scoring answers to the toughest questions examiners typically ask.

---

## 1. Quick Summary of Advanced DBMS Concepts Demonstrated

1. **Declarative Range Partitioning**: `payslips` table partitioned by `payroll_year` (`payslips_2025`, `payslips_2026`, `payslips_future`) enabling automated partition pruning by the query optimizer.
2. **GiST Exclusion Constraints (`btree_gist`)**: Temporal validity protection in `salary_structures` mathematically eliminating overlapping compensation date ranges.
3. **Row-Level Security (RLS)**: Transaction-scoped tenant/employee isolation (`SET LOCAL app.current_role` & `SET LOCAL app.current_employee_id`) designed specifically for connection pools.
4. **PL/pgSQL Programmability & Cursors**: Memory-efficient batch cursor processing in `process_monthly_payroll` with row-level `SAVEPOINT` fault isolation.
5. **DML Automation Triggers**: Real-time auditing to `salary_change_audit` in JSONB, age validation without non-immutable dump bugs, negative salary blockers, and leave balance quota sync.
6. **Materialized Views with Concurrent Refresh**: Disk-cached pre-computed analytics in `mv_department_payroll_analytics` with unique indexing enabling `REFRESH CONCURRENTLY`.
7. **Recursive Common Table Expressions (CTE)**: Arbitrary-depth graph traversal over the self-referencing `manager_id` foreign key.
8. **Window Functions**: `DENSE_RANK()`, `SUM() OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`, `NTILE(4)`, `LAG()`, and `LEAD()`.
9. **Semi-Structured Storage (JSONB & GIN)**: `flexible_allowances` and `salary_breakdown_json` indexed with `jsonb_path_ops`.
10. **Partial Indexes**: `WHERE status = 'ACTIVE'`, `WHERE status = 'PENDING'`, and `WHERE payment_status = 'PENDING'` for minimum disk page footprint.

---

## 2. Likely Examiner Questions & Model Answers

### Q1: Why does `payslips` contain `payroll_year` and `payroll_month` when `payroll_run_id` already identifies the pay cycle? Isn't this redundant (violating 3NF)?
**Model Answer**:
> "Yes, in pure classical relational theory, this is a **controlled, deliberate denormalization**. 
> 
> There are two vital database engineering reasons for this:
> 1. **PostgreSQL Partitioning Requirement**: PostgreSQL requires that any column used as the declarative partition key must be physically present in the table's composite primary key (`payslip_id, payroll_year`). Because `payroll_year` is the partition key, it must exist directly on `payslips`.
> 2. **Partition Pruning Performance**: When a user queries `WHERE payroll_year = 2026`, the query planner uses constraint exclusion to prune all other partition tables (e.g. `payslips_2025`) at planning time. If `payroll_year` resided only in `payroll_runs`, the planner would have to perform a nested loop or hash join against `payroll_runs` before it could even determine which partition to scan, degrading partition pruning into a runtime filter."

---

### Q2: Why did you store calculated salary figures in `payslips` rather than computing them dynamically through a View?
**Model Answer**:
> "This is the **Temporal Financial Snapshot Pattern**, which is standard across enterprise accounting and labor compliance:
> 1. **Immutability of Financial Contracts**: A payslip is a historical legal ledger. If an employee receives a salary raise or a tax slab changes in 2026, a dynamically computed view would inadvertently recalculate their 2024 and 2025 past payslips, producing incorrect historical records and violating statutory auditing laws.
> 2. **Deterministic Reproducibility**: Freezing the calculated components (`basic_pay`, `pf_deduction`, `tax_deduction`, `net_salary`) and storing a JSONB snapshot of the exact calculation inputs ensures that a payslip generated today will produce identical figures 10 years into the future regardless of dimension changes.
> 3. **Query Latency**: Analytical queries over hundreds of thousands of historical payslips avoid complex multi-table joins across salary structures, attendance logs, and leave tables."

---

### Q3: Why did you use an Exclusion Constraint with `btree_gist` instead of a simple CHECK constraint or trigger for salary date ranges?
**Model Answer**:
> "A `CHECK` constraint can only inspect the row currently being evaluated (e.g., `effective_to >= effective_from`); it cannot compare the new row against existing rows in the table. 
> 
> A trigger could do a `SELECT` check, but triggers are susceptible to **race conditions** under concurrent transactions: two simultaneous transactions can both check that no overlapping record exists, pass the trigger check, and both commit overlapping records (write skew).
> 
> An **Exclusion Constraint** (`EXCLUDE USING gist`) uses a Generalized Search Tree index to mathematically guarantee that no two rows for the same `employee_id` have overlapping `daterange` intervals (`&&` operator). It is enforced at the storage engine level with immediate index locking, making it 100% concurrent-safe."

---

### Q4: How does Row-Level Security (RLS) work when the application uses a connection pool?
**Model Answer**:
> "In web applications, creating a separate PostgreSQL operating role for every physical employee is impossible because applications use connection pooling (e.g., FastAPI with `ThreadedConnectionPool`) connecting under a single service role (such as `epms_app_user`).
> 
> To enforce RLS with connection pools, we use **transaction-scoped session configuration parameters**:
> ```sql
> BEGIN;
> SET LOCAL app.current_role = 'EMPLOYEE';
> SET LOCAL app.current_employee_id = '12';
> SELECT * FROM payslips; -- Evaluates RLS policies using current_setting()
> COMMIT;
> ```
> Using `SET LOCAL` (rather than `SET`) is critical: `SET LOCAL` is valid **only for the duration of the transaction**. Once the transaction commits or rolls back, PostgreSQL automatically clears the session setting. This completely eliminates session leakage when the connection returns to the pool for reuse by another user."

---

### Q5: What is the difference between `EXPLAIN` and `EXPLAIN ANALYZE`?
**Model Answer**:
> "`EXPLAIN` displays the **execution plan** generated by the PostgreSQL cost-based query optimizer using table statistics (`pg_statistic` / `ANALYZE`). It estimates the startup cost, total cost, number of rows, and width without actually running the query.
> 
> `EXPLAIN ANALYZE` actually **executes the query**, measuring the real-time execution duration in milliseconds, actual loop counts, and rows removed by filters. It reveals whether optimizer estimates were accurate and proves whether an index scan or partition pruning was utilized."

---

### Q6: Why did you use `REFRESH MATERIALIZED VIEW CONCURRENTLY` and what constraint does it require?
**Model Answer**:
> "A standard `REFRESH MATERIALIZED VIEW` takes an **exclusive lock (`ACCESS EXCLUSIVE`)** on the materialized view, blocking all concurrent `SELECT` queries from users until the refresh completes.
> 
> By specifying `CONCURRENTLY`, PostgreSQL refreshes the view without locking out read queries. 
> 
> **Requirement**: `REFRESH MATERIALIZED VIEW CONCURRENTLY` requires that the materialized view has at least one **`UNIQUE INDEX`** covering all rows with no `WHERE` clause. In EPMS, we created `CREATE UNIQUE INDEX idx_mv_dept_payroll_unique ON mv_department_payroll_analytics (department_id, payroll_year, payroll_month);` specifically to satisfy this engine requirement."

---

### Q7: Why did you remove `CURRENT_DATE` from the `CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '18 years')` constraint?
**Model Answer**:
> "In PostgreSQL, expressions in `CHECK` constraints are required to be **immutable** (always returning the same value given the same tuple data). 
> 
> Functions like `CURRENT_DATE`, `NOW()`, or `CURRENT_TIMESTAMP` are **stable**, not immutable. If you create a `CHECK` constraint using `CURRENT_DATE`, tools like `pg_dump` and `pg_restore` can fail or reject valid historical backups upon restoration. 
> 
> In EPMS, we replaced this with a `BEFORE INSERT OR UPDATE` trigger `trg_validate_employee_age` that compares `date_of_birth` against `joining_date`, both of which are immutable scalar attributes of the tuple."

---

### Q8: What is the advantage of using a PL/pgSQL CURSOR in `process_monthly_payroll`?
**Model Answer**:
> "Instead of executing a massive `INSERT ... SELECT` statement that loads the entire employee population and attendance logs into server RAM simultaneously, a **cursor** allows streaming records sequentially.
> 
> Furthermore, combining a cursor loop with a `BEGIN ... EXCEPTION ... END` block creates an implicit **savepoint**. If calculation for one employee fails (e.g., corrupt tax slab or unassigned structure), the error is caught, the savepoint rolls back only that employee's sub-transaction, and the cursor proceeds to process the remaining 99% of employees without aborting the entire monthly batch."

---

### Q9: Why did you create explicit B-tree indexes on Foreign Key columns?
**Model Answer**:
> "Many developers assume DBMSs automatically index foreign keys. While MySQL InnoDB does, **PostgreSQL does NOT automatically create indexes on foreign keys**.
> 
> Without explicit indexes on foreign keys:
> 1. Any query joining the child table to the parent table requires a full sequential scan (`Seq Scan`).
> 2. When a row in the parent table is deleted or updated (`ON DELETE CASCADE` or `RESTRICT`), PostgreSQL must sequentially scan the entire child table to check for referencing rows, causing severe lock contention.
> 
> In EPMS, all FKs (`department_id`, `designation_id`, `manager_id`, `employee_id`, `payroll_run_id`) are explicitly indexed."

---

### Q10: How does your Recursive CTE calculate organizational depth?
**Model Answer**:
> "A recursive Common Table Expression consists of two parts connected by `UNION ALL`:
> 1. **Anchor Member**: Selects the root of the hierarchy—in our case, the CEO where `manager_id IS NULL`, setting `level = 1` and `path = employee_name`.
> 2. **Recursive Member**: Joins the `employees` table with the result of the previous iteration (`sub.manager_id = eh.employee_id`), incrementing `level + 1` and appending to the reporting path.
> 
> PostgreSQL repeatedly executes the recursive member until an iteration produces zero new rows (the base case where no subordinates exist), naturally resolving arbitrary hierarchical depth."
