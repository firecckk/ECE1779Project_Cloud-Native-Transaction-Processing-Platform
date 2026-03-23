const { runValidationOnce } = require("./worker");

const DEFAULT_BATCH_SIZE = 100;
const DEFAULT_POLL_INTERVAL_MS = 5000;

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function sleep(milliseconds) {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

function startValidationLoop() {
  const batchSize = parsePositiveInteger(process.env.VALIDATION_BATCH_SIZE, DEFAULT_BATCH_SIZE);
  const pollIntervalMs = parsePositiveInteger(
    process.env.VALIDATION_POLL_INTERVAL_MS,
    DEFAULT_POLL_INTERVAL_MS,
  );

  let stopped = false;

  const stopLoop = () => {
    stopped = true;
  };

  process.once("SIGTERM", stopLoop);
  process.once("SIGINT", stopLoop);

  const run = async () => {
    while (!stopped) {
      try {
        const result = await runValidationOnce(batchSize);

        if (result.processed_count > 0) {
          console.log(
            `[validation-worker] processed=${result.processed_count} valid=${result.valid_count} rejected=${result.rejected_count}`,
          );
          continue;
        }
      } catch (error) {
        console.error("[validation-worker-loop-error]", error);
      }

      await sleep(pollIntervalMs);
    }
  };

  run().catch((error) => {
    console.error("[validation-worker-fatal-error]", error);
    process.exitCode = 1;
  });
}

module.exports = {
  startValidationLoop,
};