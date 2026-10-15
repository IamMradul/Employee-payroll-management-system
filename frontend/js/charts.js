// ============================================================================
// ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
// System: Employee Payroll Management System (EPMS)
// Chart.js Visualizations (Department Breakdown & Historical Payroll Trends)
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
                    '#38BDF8', '#818CF8', '#34D399', '#FBBF24', '#FB7185', '#C084FC'
                ],
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: { color: '#94A3B8', font: { size: 11 } }
                }
            },
            cutout: '65%'
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
    const monthNames = ["", "Oct '25", "Nov '25", "Dec '25", "Jan '26", "Feb '26", "Mar '26"];
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
                    backgroundColor: 'rgba(56, 189, 248, 0.7)',
                    borderRadius: 4
                },
                {
                    label: 'Net Disbursed (₹)',
                    data: netData,
                    backgroundColor: 'rgba(52, 211, 153, 0.7)',
                    borderRadius: 4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    grid: { display: false },
                    ticks: { color: '#94A3B8' }
                },
                y: {
                    grid: { color: 'rgba(255, 255, 255, 0.05)' },
                    ticks: {
                        color: '#94A3B8',
                        callback: val => '₹' + (val / 100000).toFixed(1) + 'L'
                    }
                }
            },
            plugins: {
                legend: {
                    position: 'top',
                    labels: { color: '#94A3B8' }
                }
            }
        }
    });
}
