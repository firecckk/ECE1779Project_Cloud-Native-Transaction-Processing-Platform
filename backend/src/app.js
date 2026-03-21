const express = require("express");
const reportsRouter = require("./routes/reports");
const transactionsRouter = require("./routes/transactions");
const db = require("./db");

const app = express();

app.use(express.json());

// Service-level health endpoint used by Docker/K8s probes.
app.get("/health", async (req, res) => {
  try {
    await db.healthCheck();
    res.json({ status: "ok" });
  } catch (error) {
    res.status(503).json({ status: "degraded", error: "database unavailable" });
  }
});

// All reporting APIs are grouped under /reports.
app.use("/transactions", transactionsRouter);
app.use("/reports", reportsRouter);

// Fallback for unknown routes.
app.use((req, res) => {
  res.status(404).json({ error: "Not found" });
});

// Centralized error handler so route handlers can call next(error).
app.use((err, req, res, next) => {
  console.error("[ReportingServiceError]", err);
  res.status(500).json({ error: "Internal server error" });
});

module.exports = app;
