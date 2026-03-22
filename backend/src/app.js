const express = require("express");
const reportsRouter = require("./service/reporting/routes/reports");
const transactionsRouter = require("./service/ingestion/routes/transactions");
const validationRouter = require("./service/validation/routes/validation");
const db = require("../../shared/src/db");

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
app.use("/validation", validationRouter);

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
