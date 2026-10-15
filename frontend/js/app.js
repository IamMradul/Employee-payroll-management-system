// ============================================================================
// ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
// System: Employee Payroll Management System (EPMS)
// Application UI Controller & Interactive Handlers
// ============================================================================

document.addEventListener("DOMContentLoaded", () => {
    initNavigation();
    initRoleSwitcher();
    loadDashboard();
    initModals();
    initAdbmsConsole();
});

// ============================================================================
// 1. NAVIGATION & TAB SWITCHING
// ============================================================================
function initNavigation() {
    const navItems = document.querySelectorAll(".nav-item");
    const tabPanes = document.querySelectorAll(".tab-pane");

    navItems.forEach(item => {
        item.addEventListener("click", () => {
            const targetTab = item.getAttribute("data-tab");
            
            navItems.forEach(n => n.classList.remove("active"));
            tabPanes.forEach(p => p.classList.remove("active"));

            item.classList.add("active");
            const activePane = document.getElementById(targetTab);
            if (activePane) {
                activePane.classList.add("active");
                loadTabContent(targetTab);
            }
        });
    });
}

function loadTabContent(tab) {
    if (tab === "dashboard") loadDashboard();
    if (tab === "employees") loadEmployees();
    if (tab === "hierarchy") loadHierarchy();
    if (tab === "attendance") loadAttendance();
    if (tab === "payroll") loadPayrollRuns();
    if (tab === "payslips") loadPayslips();
    if (tab === "reports") loadReports();
}

// ============================================================================
// 2. ROLE SWITCHER & ROW-LEVEL SECURITY CONTEXT
// ============================================================================
function initRoleSwitcher() {
    const roleSelect = document.getElementById("roleSelect");
    const userRoleBadge = document.getElementById("userRoleBadge");
    const userNameLabel = document.getElementById("userNameLabel");

    if (roleSelect) {
        roleSelect.value = state.currentRole;
        roleSelect.addEventListener("change", (e) => {
            state.currentRole = e.target.value;
            localStorage.setItem("epms_role", state.currentRole);

            // Automatically adapt employee ID context
            if (state.currentRole === "EMPLOYEE") {
                state.currentEmployeeId = 12; // Arjun Reddy (Senior Engineer)
                state.currentUsername = "emp12";
            } else if (state.currentRole === "HR") {
                state.currentEmployeeId = 3;  // Priya Sundaram (HR Lead)
                state.currentUsername = "hr_lead";
            } else if (state.currentRole === "ACCOUNTANT") {
                state.currentEmployeeId = 4;  // Rajesh Nambiar (Finance)
                state.currentUsername = "accountant";
            } else {
                state.currentEmployeeId = 1;  // Vikram Aditya (CEO/Admin)
                state.currentUsername = "admin";
            }

            localStorage.setItem("epms_emp_id", state.currentEmployeeId);
            localStorage.setItem("epms_user", state.currentUsername);

            updateRoleUI();
            
            // Reload currently visible tab
            const activeTab = document.querySelector(".nav-item.active")?.getAttribute("data-tab") || "dashboard";
            loadTabContent(activeTab);
            showToast(`Role switched to ${state.currentRole}. RLS policies updated.`);
        });
    }
    updateRoleUI();
}

function updateRoleUI() {
    const userRoleBadge = document.getElementById("userRoleBadge");
    const userNameLabel = document.getElementById("userNameLabel");
    if (userRoleBadge) userRoleBadge.textContent = state.currentRole;
    if (userNameLabel) {
        const names = {
            ADMIN: "Vikram Aditya (Admin/CEO)",
            HR: "Priya Sundaram (HR Lead)",
            ACCOUNTANT: "Rajesh Nambiar (Accountant)",
            EMPLOYEE: "Arjun Reddy (Emp #12)"
        };
        userNameLabel.textContent = names[state.currentRole] || state.currentUsername;
    }
}

// ============================================================================
// 3. DASHBOARD TAB
// ============================================================================
async function loadDashboard() {
    try {
        const [empRes, runsRes, costsRes] = await Promise.all([
            api.getEmployees(),
            api.getPayrollRuns(),
            api.getDepartmentCosts(2026, 2)
        ]);

        // Update KPI Cards
        document.getElementById("kpiHeadcount").textContent = empRes.count || 28;
        
        const latestRun = runsRes.runs[0] || {};
        document.getElementById("kpiPayrollSpend").textContent = latestRun.total_net_pay 
            ? "₹" + Number(latestRun.total_net_pay).toLocaleString('en-IN') 
            : "₹0.00";
        document.getElementById("kpiActiveRun").textContent = `${latestRun.payroll_year || 2026}-${String(latestRun.payroll_month || 2).padStart(2, '0')}`;
        document.getElementById("kpiRunStatus").textContent = latestRun.status || "DRAFT";

        // Render Charts
        if (costsRes.department_costs) {
            renderDepartmentChart("deptChart", costsRes.department_costs);
        }
        if (runsRes.runs) {
            renderPayrollTrendChart("trendChart", runsRes.runs);
        }

        // Recent Payroll Runs preview table
        const tbody = document.getElementById("recentRunsTableBody");
        if (tbody) {
            tbody.innerHTML = runsRes.runs.slice(0, 5).map(r => `
                <tr>
                    <td><strong>${r.payroll_year}-${String(r.payroll_month).padStart(2, '0')}</strong></td>
                    <td>${r.total_employees}</td>
                    <td>₹${Number(r.total_gross_pay).toLocaleString('en-IN')}</td>
                    <td>₹${Number(r.total_deductions).toLocaleString('en-IN')}</td>
                    <td><strong style="color:var(--accent-green)">₹${Number(r.total_net_pay).toLocaleString('en-IN')}</strong></td>
                    <td><span class="badge ${r.status.toLowerCase()}">${r.status}</span></td>
                    <td>${r.run_date ? r.run_date.substring(0, 10) : '-'}</td>
                </tr>
            `).join('');
        }
    } catch (err) {
        console.error("Dashboard load failed:", err);
    }
}

// ============================================================================
// 4. EMPLOYEE DIRECTORY
// ============================================================================
async function loadEmployees() {
    const tbody = document.getElementById("employeeTableBody");
    if (!tbody) return;
    tbody.innerHTML = `<tr><td colspan="7" style="text-align:center;">Loading employee records...</td></tr>`;

    try {
        const res = await api.getEmployees();
        tbody.innerHTML = res.employees.map(e => `
            <tr>
                <td><strong>${e.emp_code}</strong></td>
                <td>${e.full_name}</td>
                <td>${e.dept_name}</td>
                <td>${e.designation_title}</td>
                <td>${e.manager_name || '<span style="color:var(--text-muted)">Top Executive</span>'}</td>
                <td><span class="badge ${e.employment_status.toLowerCase()}">${e.employment_status}</span></td>
                <td>
                    <button class="btn btn-secondary btn-sm" onclick="viewEmployeeDetail(${e.employee_id})">View Profile</button>
                </td>
            </tr>
        `).join('');
    } catch (err) {
        tbody.innerHTML = `<tr><td colspan="7" style="color:var(--accent-rose);text-align:center;">Failed to load employees: ${err.message}</td></tr>`;
    }
}

window.viewEmployeeDetail = async function(empId) {
    try {
        const res = await api.getEmployeeDetail(empId);
        const emp = res.employee;
        const sal = res.salary_structure || {};

        let modalContent = `
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:16px; margin-bottom:20px;">
                <div>
                    <p style="color:var(--text-muted); font-size:11px;">EMP CODE</p>
                    <p><strong>${emp.emp_code}</strong></p>
                </div>
                <div>
                    <p style="color:var(--text-muted); font-size:11px;">FULL NAME</p>
                    <p><strong>${emp.first_name} ${emp.last_name}</strong></p>
                </div>
                <div>
                    <p style="color:var(--text-muted); font-size:11px;">DEPARTMENT & ROLE</p>
                    <p>${emp.dept_name} - ${emp.designation_title}</p>
                </div>
                <div>
                    <p style="color:var(--text-muted); font-size:11px;">REPORTING MANAGER</p>
                    <p>${emp.manager_name || 'None (Board/CEO)'}</p>
                </div>
                <div>
                    <p style="color:var(--text-muted); font-size:11px;">CONTACT & EMAIL</p>
                    <p>${emp.email} | ${emp.phone}</p>
                </div>
                <div>
                    <p style="color:var(--text-muted); font-size:11px;">BANK ACCOUNT & PAN</p>
                    <p>${emp.bank_name} (${emp.bank_account_no}) | PAN: ${emp.pan_number}</p>
                </div>
            </div>

            <h4 style="font-size:13px; font-weight:600; margin-bottom:12px; color:var(--text-primary);">Active Salary Structure</h4>
            <div style="background:#F8FAFC; padding:16px; border-radius:8px; border:1px solid var(--border-color);">
                <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; font-size:13px;">
                    <div>Basic Pay: <strong>₹${Number(sal.basic_pay || 0).toLocaleString('en-IN')}</strong></div>
                    <div>HRA: <strong>₹${Number(sal.hra || 0).toLocaleString('en-IN')}</strong></div>
                    <div>DA: <strong>₹${Number(sal.da || 0).toLocaleString('en-IN')}</strong></div>
                    <div>Special Allowance: <strong>₹${Number(sal.special_allowance || 0).toLocaleString('en-IN')}</strong></div>
                    <div>PF Contribution: <strong>${sal.pf_percentage || 12}%</strong></div>
                    <div>Insurance Deduction: <strong>₹${sal.insurance_deduction || 0}</strong></div>
                </div>
                <div style="margin-top:12px; font-size:12px;">
                    <p style="color:var(--text-muted); margin-bottom:4px; font-weight:500;">Flexible JSONB Allowances:</p>
                    <pre style="background:#0F172A; padding:10px; border-radius:6px; color:#7DD3FC; font-family:var(--font-mono); font-size:11px;">${JSON.stringify(sal.flexible_allowances || {}, null, 2)}</pre>
                </div>
            </div>
        `;

        document.getElementById("modalBody").innerHTML = modalContent;
        document.getElementById("modalTitle").textContent = `Employee Profile: ${emp.first_name} ${emp.last_name}`;
        openModal();
    } catch (err) {
        showToast(`Failed to load employee details: ${err.message}`, "error");
    }
};

// ============================================================================
// 5. ORGANIZATIONAL HIERARCHY (RECURSIVE CTE VISUALIZER)
// ============================================================================
async function loadHierarchy() {
    const container = document.getElementById("hierarchyTreeContainer");
    if (!container) return;
    container.innerHTML = `<p style="color:var(--text-muted)">Querying recursive CTE (vw_organization_hierarchy)...</p>`;

    try {
        const res = await api.getHierarchy();
        container.innerHTML = `
            <div style="display:flex; flex-direction:column; gap:10px;">
                ${res.hierarchy.map(node => `
                    <div style="background:#FFFFFF; border:1px solid #E2E8F0; border-radius:6px; padding:12px 16px; margin-left:${(node.hierarchy_level - 1) * 24}px; border-left:3px solid ${getLevelColor(node.hierarchy_level)}; box-shadow:0 1px 2px rgba(0,0,0,0.04);">
                        <div style="display:flex; align-items:center; justify-content:space-between;">
                            <div>
                                <span class="badge" style="background:#F1F5F9; color:#475569; margin-right:8px; font-weight:600;">Level ${node.hierarchy_level}</span>
                                <strong style="color:#0F172A;">${node.employee_name}</strong> <span style="color:#64748B;">(${node.emp_code})</span> — <span style="color:#1E40AF; font-weight:500;">${node.designation_title}</span>
                            </div>
                            <span style="font-size:12px; color:#64748B;">${node.dept_name}</span>
                        </div>
                        <div style="font-size:11px; color:#64748B; margin-top:4px;">
                            Chain: ${node.reporting_path}
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    } catch (err) {
        container.innerHTML = `<p style="color:var(--danger-text)">Failed to load org hierarchy: ${err.message}</p>`;
    }
}

function getLevelColor(level) {
    const colors = ['#1E40AF', '#0D9488', '#0284C7', '#6366F1', '#D97706'];
    return colors[(level - 1) % colors.length];
}

// ============================================================================
// 6. ATTENDANCE & LEAVES
// ============================================================================
async function loadAttendance() {
    try {
        // Attendance records
        const attRes = await api.getAttendance();
        const tbody = document.getElementById("attendanceTableBody");
        if (tbody) {
            tbody.innerHTML = attRes.attendance.map(a => `
                <tr>
                    <td>${a.attendance_date}</td>
                    <td><strong>${a.emp_code}</strong></td>
                    <td>${a.employee_name}</td>
                    <td>${a.check_in || '-'}</td>
                    <td>${a.check_out || '-'}</td>
                    <td><span class="badge ${a.status.toLowerCase()}">${a.status}</span></td>
                    <td>${a.overtime_hours > 0 ? `${a.overtime_hours} hrs` : '-'}</td>
                </tr>
            `).join('');
        }

        // Leave balances
        const targetEmp = (state.currentRole === "EMPLOYEE") ? state.currentEmployeeId : 12;
        const balRes = await api.getLeaveBalances(targetEmp, 2026);
        const balContainer = document.getElementById("leaveBalancesContainer");
        if (balContainer) {
            balContainer.innerHTML = balRes.balances.map(b => `
                <div style="background:var(--bg-secondary); border:1px solid var(--border-color); border-radius:10px; padding:14px;">
                    <div style="display:flex; justify-content:space-between; margin-bottom:8px;">
                        <strong>${b.leave_name} (${b.leave_code})</strong>
                        <span class="badge" style="background:rgba(56,189,248,0.1); color:var(--accent-blue);">${b.is_paid ? 'PAID' : 'LWP'}</span>
                    </div>
                    <div style="font-size:20px; font-weight:700; color:var(--accent-green); margin-bottom:4px;">
                        ${b.leaves_remaining} <span style="font-size:12px; color:var(--text-muted); font-weight:normal;">/ ${b.total_allocated} days left</span>
                    </div>
                    <div style="font-size:11px; color:var(--text-muted)">Used: ${b.leaves_used} days in 2026</div>
                </div>
            `).join('');
        }

        // Leave Applications
        const appRes = await api.getLeaveApplications();
        const appTbody = document.getElementById("leaveAppsTableBody");
        if (appTbody) {
            appTbody.innerHTML = appRes.applications.map(la => `
                <tr>
                    <td><strong>${la.emp_code}</strong> - ${la.employee_name}</td>
                    <td>${la.leave_name}</td>
                    <td>${la.start_date} to ${la.end_date} (${la.days_count} d)</td>
                    <td><span class="badge ${la.status.toLowerCase()}">${la.status}</span></td>
                    <td>${la.reason}</td>
                    <td>
                        ${(la.status === 'PENDING' && (state.currentRole === 'ADMIN' || state.currentRole === 'HR')) ? `
                            <button class="btn btn-success btn-sm" onclick="handleLeaveStatus(${la.leave_id}, 'APPROVED')">Approve</button>
                            <button class="btn btn-secondary btn-sm" style="color:var(--accent-rose)" onclick="handleLeaveStatus(${la.leave_id}, 'REJECTED')">Reject</button>
                        ` : (la.approver_name ? `By ${la.approver_name}` : '-')}
                    </td>
                </tr>
            `).join('');
        }
    } catch (err) {
        console.error("Attendance/Leaves load failed:", err);
    }
}

window.handleLeaveStatus = async function(leaveId, status) {
    try {
        await api.updateLeaveStatus(leaveId, status);
        showToast(`Leave application #${leaveId} marked as ${status}. Quota updated by trigger.`);
        loadAttendance();
    } catch (err) {
        showToast(`Leave action failed: ${err.message}`, "error");
    }
};

// ============================================================================
// 7. PAYROLL PROCESSING
// ============================================================================
async function loadPayrollRuns() {
    try {
        const res = await api.getPayrollRuns();
        const tbody = document.getElementById("payrollRunsTableBody");
        if (!tbody) return;

        tbody.innerHTML = res.runs.map(r => `
            <tr>
                <td><strong>${r.payroll_year}-${String(r.payroll_month).padStart(2, '0')}</strong></td>
                <td>${r.total_employees}</td>
                <td>₹${Number(r.total_gross_pay).toLocaleString('en-IN')}</td>
                <td>₹${Number(r.total_deductions).toLocaleString('en-IN')}</td>
                <td><strong style="color:var(--accent-green)">₹${Number(r.total_net_pay).toLocaleString('en-IN')}</strong></td>
                <td><span class="badge ${r.status.toLowerCase()}">${r.status}</span></td>
                <td>
                    ${r.status === 'PROCESSED' && (state.currentRole === 'ADMIN' || state.currentRole === 'ACCOUNTANT') ? `
                        <button class="btn btn-primary btn-sm" onclick="approvePayrollRun(${r.payroll_run_id})">Approve</button>
                    ` : ''}
                    ${r.status === 'APPROVED' && (state.currentRole === 'ADMIN' || state.currentRole === 'ACCOUNTANT') ? `
                        <button class="btn btn-success btn-sm" onclick="disbursePayrollRun(${r.payroll_run_id})">Disburse Bank Wire</button>
                    ` : ''}
                    ${r.status === 'PAID' ? '<span style="color:var(--accent-green); font-size:12px;">Finalized & Disbursed</span>' : ''}
                </td>
            </tr>
        `).join('');
    } catch (err) {
        console.error("Payroll runs load failed:", err);
    }
}

window.triggerNewPayroll = async function() {
    const year = parseInt(document.getElementById("payrollYearInput").value);
    const month = parseInt(document.getElementById("payrollMonthInput").value);

    try {
        showToast(`Executing PL/pgSQL process_monthly_payroll(${year}, ${month})...`);
        const res = await api.processPayroll(year, month);
        showToast(res.message);
        loadPayrollRuns();
    } catch (err) {
        showToast(`Payroll execution error: ${err.message}`, "error");
    }
};

window.approvePayrollRun = async function(runId) {
    try {
        await api.approvePayroll(runId);
        showToast(`Payroll run #${runId} approved.`);
        loadPayrollRuns();
    } catch (err) {
        showToast(`Approval failed: ${err.message}`, "error");
    }
};

window.disbursePayrollRun = async function(runId) {
    try {
        await api.disbursePayroll(runId);
        showToast(`Payroll run #${runId} successfully disbursed! All payslips marked PAID.`);
        loadPayrollRuns();
    } catch (err) {
        showToast(`Disbursement failed: ${err.message}`, "error");
    }
};

// ============================================================================
// 8. PAYSLIPS & PARTITIONED LEDGER
// ============================================================================
async function loadPayslips() {
    const tbody = document.getElementById("payslipsTableBody");
    if (!tbody) return;
    tbody.innerHTML = `<tr><td colspan="8" style="text-align:center;">Fetching payslip partitions (RLS enforced)...</td></tr>`;

    try {
        const res = await api.getPayslips();
        if (res.payslips.length === 0) {
            tbody.innerHTML = `<tr><td colspan="8" style="text-align:center; color:var(--text-muted);">No payslips found for this access role (RLS active).</td></tr>`;
            return;
        }

        tbody.innerHTML = res.payslips.map(p => `
            <tr>
                <td><strong>${p.payroll_year}-${String(p.payroll_month).padStart(2, '0')}</strong></td>
                <td>${p.emp_code}</td>
                <td>${p.employee_name}</td>
                <td>${p.dept_name}</td>
                <td>₹${Number(p.gross_salary).toLocaleString('en-IN')}</td>
                <td>₹${Number(p.total_deductions).toLocaleString('en-IN')}</td>
                <td><strong style="color:var(--accent-green)">₹${Number(p.net_salary).toLocaleString('en-IN')}</strong></td>
                <td>
                    <button class="btn btn-secondary btn-sm" onclick="viewPayslipModal(${p.payslip_id}, ${p.payroll_year})">View</button>
                    <a href="${api.getPdfUrl(p.payslip_id, p.payroll_year)}" target="_blank" class="btn btn-primary btn-sm">PDF</a>
                </td>
            </tr>
        `).join('');
    } catch (err) {
        tbody.innerHTML = `<tr><td colspan="8" style="color:var(--accent-rose);text-align:center;">Failed to load payslips: ${err.message}</td></tr>`;
    }
}

window.viewPayslipModal = async function(payslipId, year) {
    try {
        const res = await api.getPayslipDetail(payslipId, year);
        const p = res.payslip;

        let modalContent = `
            <div style="border-bottom:1px solid var(--border-color); padding-bottom:12px; margin-bottom:16px;">
                <div style="display:flex; justify-content:space-between; align-items:center;">
                    <div>
                        <h3 style="font-size:15px; font-weight:600; color:var(--text-primary);">${p.employee_name} (${p.emp_code})</h3>
                        <p style="font-size:12px; color:var(--text-muted);">${p.dept_name} • ${p.designation_title}</p>
                    </div>
                    <span class="badge ${p.payment_status.toLowerCase()}">${p.payment_status}</span>
                </div>
            </div>

            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:16px; margin-bottom:16px;">
                <div style="background:#F8FAFC; border:1px solid #E2E8F0; padding:14px; border-radius:6px;">
                    <h4 style="font-size:12px; font-weight:600; text-transform:uppercase; color:#1E40AF; margin-bottom:10px;">Earnings (₹)</h4>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Basic Salary</span> <strong>₹${Number(p.basic_pay).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>HRA</span> <strong>₹${Number(p.hra).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>DA</span> <strong>₹${Number(p.da).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Special Allowance</span> <strong>₹${Number(p.special_allowance).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Flexible Allowances</span> <strong>₹${Number(p.flexible_allowances_total).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Overtime Pay</span> <strong>₹${Number(p.overtime_pay).toLocaleString('en-IN')}</strong></div>
                    <hr style="border:none; border-top:1px solid #CBD5E1; margin:8px 0;">
                    <div style="display:flex; justify-content:space-between; font-weight:700; font-size:13px;"><span>Gross Salary</span> <strong>₹${Number(p.gross_salary).toLocaleString('en-IN')}</strong></div>
                </div>

                <div style="background:#F8FAFC; border:1px solid #E2E8F0; padding:14px; border-radius:6px;">
                    <h4 style="font-size:12px; font-weight:600; text-transform:uppercase; color:#991B1B; margin-bottom:10px;">Deductions (₹)</h4>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Provident Fund (PF)</span> <strong>₹${Number(p.pf_deduction).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Income Tax (TDS)</span> <strong>₹${Number(p.tax_deduction).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Insurance</span> <strong>₹${Number(p.insurance_deduction).toLocaleString('en-IN')}</strong></div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:13px;"><span>Loss of Pay (LOP)</span> <strong>₹${Number(p.lop_deduction).toLocaleString('en-IN')}</strong></div>
                    <hr style="border:none; border-top:1px solid #CBD5E1; margin:8px 0;">
                    <div style="display:flex; justify-content:space-between; font-weight:700; font-size:13px;"><span>Total Deductions</span> <strong>₹${Number(p.total_deductions).toLocaleString('en-IN')}</strong></div>
                </div>
            </div>

            <div style="background:#F0FDF4; border:1px solid #BBF7D0; border-radius:6px; padding:16px; display:flex; justify-content:space-between; align-items:center;">
                <div>
                    <span style="font-size:11px; text-transform:uppercase; font-weight:600; color:#166534; display:block;">Net Disbursed Take-Home</span>
                    <strong style="font-size:22px; color:#15803D;">₹${Number(p.net_salary).toLocaleString('en-IN')}</strong>
                </div>
                <a href="${api.getPdfUrl(p.payslip_id, p.payroll_year)}" target="_blank" class="btn btn-primary">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>
                    Download Official PDF
                </a>
            </div>
        `;

        document.getElementById("modalBody").innerHTML = modalContent;
        document.getElementById("modalTitle").textContent = `Payslip Snapshot: ${p.payroll_year}-${String(p.payroll_month).padStart(2, '0')}`;
        openModal();
    } catch (err) {
        showToast(`Failed to load payslip: ${err.message}`, "error");
    }
};

// ============================================================================
// 9. REPORTS & MATERIALIZED VIEWS
// ============================================================================
async function loadReports() {
    try {
        const [costsRes, earnersRes, mvRes] = await Promise.all([
            api.getDepartmentCosts(2026, 2),
            api.getTopEarners(2026, 2),
            api.getMaterializedView()
        ]);

        // Department Budget Utilization table
        const costTbody = document.getElementById("deptCostTableBody");
        if (costTbody) {
            costTbody.innerHTML = costsRes.department_costs.map(c => `
                <tr>
                    <td><strong>${c.dept_name}</strong></td>
                    <td>${c.paid_headcount}</td>
                    <td>₹${Number(c.monthly_budget_allocation).toLocaleString('en-IN')}</td>
                    <td>₹${Number(c.total_gross_payroll).toLocaleString('en-IN')}</td>
                    <td><strong>${c.budget_utilization_pct}%</strong></td>
                </tr>
            `).join('');
        }

        // Top Earners (Window function) table
        const topTbody = document.getElementById("topEarnersTableBody");
        if (topTbody) {
            topTbody.innerHTML = earnersRes.top_earners.map(te => `
                <tr>
                    <td><span class="badge" style="background:rgba(56,189,248,0.1); color:var(--accent-blue);">#${te.dept_rank}</span></td>
                    <td><strong>${te.employee_name}</strong> (${te.emp_code})</td>
                    <td>${te.dept_name}</td>
                    <td>${te.designation_title}</td>
                    <td><strong>₹${Number(te.gross_salary).toLocaleString('en-IN')}</strong></td>
                </tr>
            `).join('');
        }

        // Materialized View table
        const mvTbody = document.getElementById("mvTableBody");
        if (mvTbody) {
            mvTbody.innerHTML = mvRes.materialized_view_data.slice(0, 6).map(m => `
                <tr>
                    <td>${m.dept_name} (${m.dept_code})</td>
                    <td>${m.payroll_year}-${String(m.payroll_month).padStart(2, '0')}</td>
                    <td>${m.employee_count}</td>
                    <td>₹${Number(m.total_gross_spend).toLocaleString('en-IN')}</td>
                    <td>₹${Number(m.total_net_disbursed).toLocaleString('en-IN')}</td>
                    <td style="font-size:11px; color:var(--text-muted);">${m.last_refreshed_at ? m.last_refreshed_at.substring(0, 19) : '-'}</td>
                </tr>
            `).join('');
        }
    } catch (err) {
        console.error("Reports load failed:", err);
    }
}

window.refreshMv = async function() {
    try {
        showToast("Executing REFRESH MATERIALIZED VIEW CONCURRENTLY...");
        await api.refreshMaterializedView();
        showToast("Materialized view successfully refreshed!");
        loadReports();
    } catch (err) {
        showToast(`Refresh error: ${err.message}`, "error");
    }
};

// ============================================================================
// 10. INTERACTIVE ADBMS SQL CONSOLE
// ============================================================================
let adbmsQueriesCatalog = [];

async function initAdbmsConsole() {
    const selector = document.getElementById("adbmsQuerySelect");
    const sqlViewer = document.getElementById("adbmsSqlViewer");
    const metricsDiv = document.getElementById("adbmsQueryMetrics");
    if (!selector) return;

    try {
        const res = await api.getAdbmsQueries();
        adbmsQueriesCatalog = res.queries || [];
        selector.innerHTML = adbmsQueriesCatalog.map(q => `
            <option value="${q.id}">Query #${q.id}: ${q.title}</option>
        `).join('');

        const updateSelectedQueryPreview = () => {
            const selectedId = parseInt(selector.value);
            const found = adbmsQueriesCatalog.find(q => q.id === selectedId);
            if (found && metricsDiv) {
                metricsDiv.innerHTML = `
                    <span style="display:inline-flex; align-items:center; gap:6px; color:var(--primary); background:var(--primary-subtle); border:1px solid var(--primary-border); padding:4px 10px; border-radius:4px; font-size:12px; font-weight:500;">
                        <strong>Key Concept:</strong> ${found.concept}
                    </span>
                `;
            }
            if (sqlViewer) {
                sqlViewer.textContent = "-- Click 'Run Query' to execute this query live against PostgreSQL 17 engine";
            }
        };

        selector.addEventListener("change", updateSelectedQueryPreview);
        updateSelectedQueryPreview();
    } catch (err) {
        console.error("Failed to load query catalog:", err);
    }
}

window.runAdbmsQuery = async function() {
    const selector = document.getElementById("adbmsQuerySelect");
    const sqlViewer = document.getElementById("adbmsSqlViewer");
    const metricsDiv = document.getElementById("adbmsQueryMetrics");
    const thead = document.getElementById("adbmsTableHead");
    const tbody = document.getElementById("adbmsTableBody");

    const queryId = parseInt(selector.value);
    sqlViewer.textContent = "-- Executing query live against PostgreSQL 17 engine...";

    try {
        const res = await api.executeAdbmsQuery(queryId);
        sqlViewer.textContent = res.sql;

        metricsDiv.innerHTML = `
            <span style="display:inline-flex; align-items:center; gap:6px; color:#059669; background:#ECFDF5; border:1px solid #A7F3D0; padding:4px 10px; border-radius:4px; font-size:12px; font-weight:600;">
                ✓ Query executed in <strong>${res.execution_time_ms} ms</strong>
            </span>
            <span style="margin: 0 6px; color:#94A3B8;">•</span>
            <span style="color:#475569; font-size:12px;">Returned <strong>${res.row_count} rows</strong></span>
            <span style="margin: 0 6px; color:#94A3B8;">•</span>
            <span style="color:var(--primary); font-size:12px; font-weight:500;"><strong>Concept:</strong> ${res.concept}</span>
        `;

        // Render Dynamic Headers
        thead.innerHTML = `<tr>${res.columns.map(c => `<th>${c}</th>`).join('')}</tr>`;

        // Render Dynamic Rows
        tbody.innerHTML = res.rows.map(row => `
            <tr>${res.columns.map(col => `<td>${formatCellValue(row[col])}</td>`).join('')}</tr>
        `).join('');
    } catch (err) {
        sqlViewer.textContent = `-- Error executing query: ${err.message}`;
    }
};

function formatCellValue(val) {
    if (val === null || val === undefined) return '<span style="color:var(--text-muted)">NULL</span>';
    if (typeof val === 'object') return `<pre style="font-size:11px; margin:0;">${JSON.stringify(val)}</pre>`;
    return String(val);
}

// ============================================================================
// 11. MODAL UTILITIES & TOASTS
// ============================================================================
function initModals() {
    const modal = document.getElementById("mainModal");
    const closeBtn = document.getElementById("closeModalBtn");
    if (closeBtn && modal) {
        closeBtn.addEventListener("click", () => { modal.style.display = "none"; });
        window.addEventListener("click", (e) => {
            if (e.target === modal) modal.style.display = "none";
        });
    }
}

function openModal() {
    const modal = document.getElementById("mainModal");
    if (modal) modal.style.display = "flex";
}

function showToast(msg, type = "success") {
    let toast = document.getElementById("epmsToast");
    if (!toast) {
        toast = document.createElement("div");
        toast.id = "epmsToast";
        toast.style.position = "fixed";
        toast.style.bottom = "24px";
        toast.style.right = "24px";
        toast.style.padding = "12px 20px";
        toast.style.borderRadius = "8px";
        toast.style.fontSize = "13px";
        toast.style.fontWeight = "600";
        toast.style.zIndex = "2000";
        toast.style.boxShadow = "0 10px 25px rgba(0,0,0,0.5)";
        toast.style.transition = "all 0.3s ease";
        document.body.appendChild(toast);
    }

    toast.style.background = (type === "error") ? "#991B1B" : "#0F172A";
    toast.style.color = "#FFFFFF";
    toast.style.border = "1px solid #334155";
    toast.textContent = msg;
    toast.style.display = "block";
    toast.style.opacity = "1";

    setTimeout(() => {
        toast.style.opacity = "0";
        setTimeout(() => { toast.style.display = "none"; }, 300);
    }, 4000);
}
