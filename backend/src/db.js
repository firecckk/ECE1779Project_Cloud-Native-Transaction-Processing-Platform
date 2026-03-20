const { Pool } = require("pg");
const config = require("./config");

// Reuse connections via a shared pool for better performance under load.
const pool = new Pool({
  connectionString: config.databaseUrl
});

// Thin wrapper to keep SQL execution consistent across routes.
async function query(text, params = []) {
  return pool.query(text, params);
}

// Used by /health to verify DB reachability with a cheap query.
async function healthCheck() {
  await pool.query("SELECT 1");
}

module.exports = {
  pool,
  query,
  healthCheck
};
