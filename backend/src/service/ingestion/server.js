const createApp = require("../../createApp");
const config = require("../../../../shared/src/config");

const app = createApp("ingestion");

app.listen(config.port, () => {
  console.log(`[ingestion-service] listening on port ${config.port}`);
});