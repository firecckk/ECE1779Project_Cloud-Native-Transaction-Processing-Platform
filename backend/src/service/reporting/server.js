const createApp = require("../../createApp");
const config = require("../../../../shared/src/config");

const app = createApp("reporting");

app.listen(config.port, () => {
  console.log(`[reporting-service] listening on port ${config.port}`);
});