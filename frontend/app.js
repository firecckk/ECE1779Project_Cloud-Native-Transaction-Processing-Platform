const API_BASE = "/api";

const statusEl = document.getElementById("status");
const fromInput = document.getElementById("fromDate");
const toInput = document.getElementById("toDate");
const limitInput = document.getElementById("merchantLimit");
const bucketInput = document.getElementById("bucketSize");
const dbLimitInput = document.getElementById("dbLimit");

const dailyEl = document.getElementById("dailyVolume");
const merchantEl = document.getElementById("merchantRanking");
const riskEl = document.getElementById("riskDistribution");
const transactionsTableEl = document.getElementById("transactionsTable");
const auditTableEl = document.getElementById("auditTable");

const reportsPage = document.getElementById("reportsPage");
const databasePage = document.getElementById("databasePage");
const togglePageBtn = document.getElementById("togglePageBtn");

let currentPage = "reports";

let dailyChart;
let riskChart;

function setStatus(message, isError = false) {
  statusEl.textContent = message;
  statusEl.className = isError ? "status error" : "status";
}

function formatDateForInput(date) {
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, "0");
  const d = `${date.getDate()}`.padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function initDefaultDates() {
  const now = new Date();
  const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  fromInput.value = formatDateForInput(oneWeekAgo);
  toInput.value = formatDateForInput(now);
}

function renderTable(container, rows) {
  if (!rows || rows.length === 0) {
    container.innerHTML = '<div class="empty">No data in selected date range.</div>';
    return;
  }

  const headers = Object.keys(rows[0]);
  const head = `<tr>${headers.map((h) => `<th>${h}</th>`).join("")}</tr>`;
  const body = rows
    .map((row) => `<tr>${headers.map((h) => `<td>${row[h] ?? ""}</td>`).join("")}</tr>`)
    .join("");

  container.innerHTML = `<table><thead>${head}</thead><tbody>${body}</tbody></table>`;
}

function renderMerchantTable(container, rows) {
  if (!rows || rows.length === 0) {
    container.innerHTML = '<div class="empty">No data in selected date range.</div>';
    return;
  }

  const enhancedRows = rows.map((row) => ({
    ...row,
    average_risk_score: `${row.average_risk_score ?? 0} (max 100)`
  }));

  renderTable(container, enhancedRows);
}

function renderDailyChart(rows) {
  const canvas = document.getElementById("dailyVolumeChart");
  if (!canvas) {
    return;
  }

  const labels = [...rows].reverse().map((r) => String(r.date).slice(0, 10));
  const totals = [...rows].reverse().map((r) => Number(r.total_amount));

  if (dailyChart) {
    dailyChart.destroy();
  }

  dailyChart = new Chart(canvas, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "Total Amount",
          data: totals,
          borderColor: "#176087",
          backgroundColor: "rgba(23, 96, 135, 0.15)",
          fill: true,
          tension: 0.3,
          pointRadius: 3
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: { beginAtZero: true }
      }
    }
  });
}

function renderRiskChart(rows) {
  const canvas = document.getElementById("riskDistributionChart");
  if (!canvas) {
    return;
  }

  const labels = rows.map((r) => r.risk_bucket);
  const counts = rows.map((r) => Number(r.transaction_count));

  if (riskChart) {
    riskChart.destroy();
  }

  riskChart = new Chart(canvas, {
    type: "bar",
    data: {
      labels,
      datasets: [
        {
          label: "Transaction Count",
          data: counts,
          backgroundColor: "rgba(18, 77, 109, 0.8)",
          borderColor: "#124d6d",
          borderWidth: 1
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: { beginAtZero: true }
      }
    }
  });
}

function switchPage(target) {
  const showReports = target === "reports";
  currentPage = showReports ? "reports" : "database";
  reportsPage.classList.toggle("active", showReports);
  databasePage.classList.toggle("active", !showReports);
  togglePageBtn.textContent = showReports ? "Database" : "Reports";

  if (!showReports) {
    loadDatabaseTables();
  }
}

async function fetchReport(path, params = {}) {
  const url = new URL(`${API_BASE}${path}`, window.location.origin);
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== "") {
      url.searchParams.set(k, v);
    }
  });

  const res = await fetch(url);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API ${path} failed (${res.status}): ${text}`);
  }

  return res.json();
}

async function queryAllReports() {
  const from = fromInput.value;
  const to = toInput.value;
  const limit = limitInput.value || "10";
  const bucket = bucketInput.value || "20";
  const fromIso = from ? `${from}T00:00:00Z` : "";
  const toIso = to ? `${to}T23:59:59Z` : "";

  if (from && to && new Date(from) > new Date(to)) {
    setStatus("From date must be earlier than or equal to To date.", true);
    return;
  }

  setStatus("Loading reports...");

  try {
    const [daily, merchants, risk] = await Promise.all([
      fetchReport("/reports/daily-volume", { from: fromIso, to: toIso }),
      fetchReport("/reports/merchant-ranking", { from: fromIso, to: toIso, limit }),
      fetchReport("/reports/risk-distribution", { from: fromIso, to: toIso, bucket_size: bucket })
    ]);

    renderTable(dailyEl, daily.rows);
    renderMerchantTable(merchantEl, merchants.rows);
    renderTable(riskEl, risk.rows);
    renderDailyChart(daily.rows || []);
    renderRiskChart(risk.rows || []);
    setStatus("Reports loaded successfully.");
  } catch (error) {
    setStatus(error.message, true);
  }
}

async function loadDatabaseTables() {
  const limit = dbLimitInput.value || "20";
  setStatus("Loading database tables...");

  try {
    const [transactions, audits] = await Promise.all([
      fetchReport("/reports/transactions-table", { limit }),
      fetchReport("/reports/status-audit-table", { limit })
    ]);

    renderTable(transactionsTableEl, transactions.rows);
    renderTable(auditTableEl, audits.rows);
    setStatus("Database tables loaded successfully.");
  } catch (error) {
    setStatus(error.message, true);
  }
}

function clearAll() {
  dailyEl.innerHTML = "";
  merchantEl.innerHTML = "";
  riskEl.innerHTML = "";
  if (dailyChart) {
    dailyChart.destroy();
    dailyChart = null;
  }
  if (riskChart) {
    riskChart.destroy();
    riskChart = null;
  }
  setStatus("Cleared.");
}

document.getElementById("queryAllBtn").addEventListener("click", queryAllReports);
document.getElementById("clearBtn").addEventListener("click", clearAll);
document.getElementById("refreshDbBtn").addEventListener("click", loadDatabaseTables);
togglePageBtn.addEventListener("click", () => {
  switchPage(currentPage === "reports" ? "database" : "reports");
});

initDefaultDates();
queryAllReports();
