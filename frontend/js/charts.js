// ============================================================================
// ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
// System: Employee Payroll Management System (EPMS)
// Chart.js Visualizations (Professional Light Enterprise Theme)
// ============================================================================

let deptChart = null;
let trendChart = null;

function renderDepartmentChart(canvasId, deptCosts) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    if (deptChart) {
        deptChart.destroy();
    }

    const labels = deptCosts.map(d => d.dept_name);
    const data = deptCosts.map(d => parseFloat(d.total_gross_payroll));

    deptChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: data,
                backgroundColor: [
                    '#1E40AF', '#0D9488', '#0284C7', '#6366F1', '#D97706', '#64748B'
                ],
                borderWidth: 2,
                borderColor: '#FFFFFF'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: { color: '#475569', font: { size: 11, family: 'Inter' }, padding: 12 }
                }
            },
            cutout: '70%'
        }
    });
}

function renderPayrollTrendChart(canvasId, runs) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    if (trendChart) {
        trendChart.destroy();
    }

    // Sort chronologically ascending
    const sorted = [...runs].reverse();
    const labels = sorted.map(r => `${r.payroll_year}-${String(r.payroll_month).padStart(2, '0')}`);
    const grossData = sorted.map(r => parseFloat(r.total_gross_pay));
    const netData = sorted.map(r => parseFloat(r.total_net_pay));

    trendChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Gross Payroll (₹)',
                    data: grossData,
                    backgroundColor: '#2563EB',
                    borderRadius: 4,
                    barPercentage: 0.6
                },
                {
                    label: 'Net Disbursed (₹)',
                    data: netData,
                    backgroundColor: '#059669',
                    borderRadius: 4,
                    barPercentage: 0.6
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    grid: { display: false },
                    ticks: { color: '#64748B', font: { family: 'Inter', size: 11 } }
                },
                y: {
                    grid: { color: '#E2E8F0' },
                    ticks: {
                        color: '#64748B',
                        font: { family: 'Inter', size: 11 },
                        callback: val => '₹' + (val / 100000).toFixed(1) + 'L'
                    }
                }
            },
            plugins: {
                legend: {
                    position: 'top',
                    labels: { color: '#475569', font: { family: 'Inter', size: 12 } }
                }
            }
        }
    });
}
