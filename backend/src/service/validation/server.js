const createApp = require("../../createApp");
const config = require("../../../../shared/src/config");
const { startValidationLoop } = require("./loop");

const app = createApp("validation");

startValidationLoop();

app.listen(config.port, () => {
  console.log(`[validation-service] listening on port ${config.port}`);
});