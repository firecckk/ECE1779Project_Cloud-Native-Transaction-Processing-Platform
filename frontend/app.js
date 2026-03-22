const API_BASE = window.location.hostname === "localhost"
  ? "http://localhost:8080"
  : "http://backend:8080";

const statusEl = document.getElementById("status");
const fromInput = document.getElementById("fromDate");
const toInput = document.getElementById("toDate");
const limitInput = document.getElementById("merchantLimit");
const bucketInput = document.getElementById("bucketSize");

const dailyEl = document.getElementById("dailyVolume");
const merchantEl = document.getElementById("merchantRanking");
const riskEl = document.getElementById("riskDistribution");

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

async function fetchReport(path, params = {}) {
  const url = new URL(`${API_BASE}${path}`);
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

  if (from && to && new Date(from) > new Date(to)) {
    setStatus("From date must be earlier than or equal to To date.", true);
    return;
  }

  setStatus("Loading reports...");

  try {
    const [daily, merchants, risk] = await Promise.all([
      fetchReport("/reports/daily-volume", { from, to }),
      fetchReport("/reports/merchant-ranking", { from, to, limit }),
      fetchReport("/reports/risk-distribution", { from, to, bucket_size: bucket })
    ]);

    renderTable(dailyEl, daily.rows);
    renderTable(merchantEl, merchants.rows);
    renderTable(riskEl, risk.rows);
    setStatus("Reports loaded successfully.");
  } catch (error) {
    setStatus(error.message, true);
  }
}

function clearAll() {
  dailyEl.innerHTML = "";
  merchantEl.innerHTML = "";
  riskEl.innerHTML = "";
  setStatus("Cleared.");
}

document.getElementById("queryAllBtn").addEventListener("click", queryAllReports);
document.getElementById("clearBtn").addEventListener("click", clearAll);

initDefaultDates();
