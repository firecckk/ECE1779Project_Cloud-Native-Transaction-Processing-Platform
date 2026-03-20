const DEFAULT_PORT = 8080;

// Parse numeric env values safely and fallback to defaults.
function toNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

// Centralized runtime configuration for all modules.
module.exports = {
  port: toNumber(process.env.PORT, DEFAULT_PORT),
  databaseUrl:
    process.env.DATABASE_URL ||
    "postgresql://transaction_user:transaction_password@localhost:5432/transaction_platform",
  logLevel: process.env.LOG_LEVEL || "INFO"
};
