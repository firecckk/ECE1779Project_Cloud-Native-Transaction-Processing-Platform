const app = require("./app");
const config = require("./config");

// Process entrypoint: boot Express on configured port.
app.listen(config.port, () => {
  console.log(`[reporting-service] listening on port ${config.port}`);
});
