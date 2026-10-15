// ============================================================================
// ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
// System: Employee Payroll Management System (EPMS)
// Frontend API Client with Dynamic RLS Header Injection
// ============================================================================

const API_BASE = "http://127.0.0.1:8000/api";

const state = {
    currentRole: localStorage.getItem("epms_role") || "ADMIN",
    currentEmployeeId: localStorage.getItem("epms_emp_id") || "1",
    currentUsername: localStorage.getItem("epms_user") || "admin"
};

function getHeaders() {
    return {
        "Content-Type": "application/json",
        "x-role": state.currentRole,
        "x-employee-id": state.currentEmployeeId ? String(state.currentEmployeeId) : ""
    };
}

async function apiRequest(endpoint, options = {}) {
    const url = `${API_BASE}${endpoint}`;
    const config = {
        ...options,
        headers: {
            ...getHeaders(),
            ...(options.headers || {})
        }
    };

    try {
        const response = await fetch(url, config);
        if (!response.ok) {
            const errData = await response.json().catch(() => ({}));
            throw new Error(errData.detail || `HTTP Error ${response.status}`);
        }
        return await response.json();
    } catch (err) {
        console.error(`API Error on ${endpoint}:`, err);
        throw err;
    }
}

const api = {
    // Auth & Demo
    getDemoUsers: () => apiRequest("/auth/demo-users"),
    login: (username, password) => apiRequest("/auth/login", {
        method: "POST",
        body: JSON.stringify({ username, password })
    }),

    // Employees
    getEmployees: (params = "") => apiRequest(`/employees${params}`),
    getEmployeeDetail: (id) => apiRequest(`/employees/${id}`),
    getHierarchy: () => apiRequest("/organization/hierarchy"),
    getDepartments: () => apiRequest("/departments"),

    // Attendance & Leaves
    getAttendance: (params = "") => apiRequest(`/attendance${params}`),
    getLeaveBalances: (empId, year = 2026) => apiRequest(`/leaves/balances?employee_id=${empId}&year=${year}`),
    getLeaveApplications: () => apiRequest("/leaves/applications"),
    applyLeave: (data) => apiRequest("/leaves/applications", {
        method: "POST",
        body: JSON.stringify(data)
    }),
    updateLeaveStatus: (leaveId, status) => apiRequest(`/leaves/applications/${leaveId}/status`, {
        method: "PUT",
        body: JSON.stringify({ status })
    }),

    // Payroll
    getPayrollRuns: () => apiRequest("/payroll/runs"),
    processPayroll: (year, month) => apiRequest("/payroll/process", {
        method: "POST",
        body: JSON.stringify({ year, month })
    }),
    approvePayroll: (runId) => apiRequest(`/payroll/approve/${runId}`, { method: "POST" }),
    disbursePayroll: (runId) => apiRequest(`/payroll/disburse/${runId}`, { method: "POST" }),
    getPayslips: (params = "") => apiRequest(`/payroll/payslips${params}`),
    getPayslipDetail: (id, year) => apiRequest(`/payroll/payslips/${id}${year ? `?year=${year}` : ""}`),
    getPdfUrl: (id, year) => `${API_BASE}/payroll/payslips/${id}/pdf${year ? `?year=${year}` : ""}`,

    // Reports & ADBMS
    getDepartmentCosts: (year = 2026, month = 2) => apiRequest(`/reports/department-cost?year=${year}&month=${month}`),
    getTopEarners: (year = 2026, month = 2) => apiRequest(`/reports/top-earners?year=${year}&month=${month}`),
    getMaterializedView: () => apiRequest("/reports/materialized-view"),
    refreshMaterializedView: () => apiRequest("/reports/materialized-view/refresh", { method: "POST" }),
    getAdbmsQueries: () => apiRequest("/reports/adbms-queries"),
    executeAdbmsQuery: (queryId) => apiRequest("/reports/execute-adbms-query", {
        method: "POST",
        body: JSON.stringify({ query_id: queryId })
    })
};
