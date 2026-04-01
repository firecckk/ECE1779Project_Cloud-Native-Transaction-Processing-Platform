const express = require("express");
const reportsRouter = require("./service/reporting/routes/reports");
const transactionsRouter = require("./service/ingestion/routes/transactions");
const validationRouter = require("./service/validation/routes/validation");
const db = require("../../shared/src/db");

const ROUTES_BY_SERVICE = {
  all: [
    ["/transactions", transactionsRouter],
    ["/reports", reportsRouter],
    ["/validation", validationRouter],
  ],
  ingestion: [["/transactions", transactionsRouter]],
  reporting: [["/reports", reportsRouter]],
  validation: [["/validation", validationRouter]],
};

function createApp(serviceName = "all") {
  const routes = ROUTES_BY_SERVICE[serviceName];

  if (!routes) {
    throw new Error(`Unsupported service name: ${serviceName}`);
  }

  const app = express();

  app.use(express.json());

  app.use((req, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (req.method === "OPTIONS") {
      return res.sendStatus(204);
    }

    return next();
  });

  app.get("/health", async (req, res) => {
    try {
      await db.healthCheck();
      res.json({ status: "ok", service: serviceName });
    } catch (error) {
      res.status(503).json({
        status: "degraded",
        service: serviceName,
        error: "database unavailable",
      });
    }
  });

  routes.forEach(([path, router]) => {
    app.use(path, router);
  });

  app.use((req, res) => {
    res.status(404).json({ error: "Not found" });
  });

  app.use((err, req, res, next) => {
    console.error(`[${serviceName}-service-error]`, err);
    res.status(500).json({ error: "Internal server error" });
  });

  return app;
}

module.exports = createApp;