#!/usr/bin/env node

const { randomUUID } = require("crypto");

const DEFAULTS = {
  mode: "stdout",
  count: 10,
  rate: 1,
  url: "http://localhost:8080/transactions",
  timeoutMs: 5000,
  startDate: "2026-01-01T00:00:00Z",
  endDate: "2026-03-31T23:59:59Z",
  highRiskRatio: 0.1,
  duplicateRatio: 0.05,
  frequencyBurstRatio: 0.15,
};

const CURRENCIES = ["CAD", "USD", "EUR"];
const TRANSACTION_TYPES = ["PAYMENT", "TRANSFER", "REFUND"];
const CHANNELS = ["WEB", "MOBILE", "API"];
const LOCATIONS = ["Toronto", "Montreal", "Vancouver", "Halifax", "Calgary"];

function parseArgs(argv) {
  const options = { ...DEFAULTS };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (!arg.startsWith("--")) {
      throw new Error(`Unexpected argument: ${arg}`);
    }

    const [rawKey, inlineValue] = arg.slice(2).split("=", 2);
    const key = rawKey.trim();
    const value = inlineValue !== undefined ? inlineValue : argv[++i];

    if (value === undefined) {
      throw new Error(`Missing value for --${key}`);
    }

    switch (key) {
      case "mode":
        if (!["stdout", "http"].includes(value)) {
          throw new Error("--mode must be stdout or http");
        }
        options.mode = value;
        break;
      case "count":
        options.count = toPositiveInt(value, "--count");
        break;
      case "rate":
        options.rate = toPositiveInt(value, "--rate");
        break;
      case "url":
        options.url = value;
        break;
      case "timeout-ms":
        options.timeoutMs = toPositiveInt(value, "--timeout-ms");
        break;
      case "start-date":
        options.startDate = toIsoDate(value, "--start-date");
        break;
      case "end-date":
        options.endDate = toIsoDate(value, "--end-date");
        break;
      case "high-risk-ratio":
        options.highRiskRatio = toRatio(value, "--high-risk-ratio");
        break;
      case "duplicate-ratio":
        options.duplicateRatio = toRatio(value, "--duplicate-ratio");
        break;
      case "frequency-burst-ratio":
        options.frequencyBurstRatio = toRatio(value, "--frequency-burst-ratio");
        break;
      default:
        throw new Error(`Unknown option: --${key}`);
    }
  }

  return options;
}

function toPositiveInt(value, label) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${label} must be a positive integer`);
  }
  return parsed;
}

function toRatio(value, label) {
  const parsed = Number.parseFloat(value);
  if (Number.isNaN(parsed) || parsed < 0 || parsed > 1) {
    throw new Error(`${label} must be between 0 and 1`);
  }
  return parsed;
}

function toIsoDate(value, label) {
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    throw new Error(`${label} must be a valid ISO-8601 timestamp`);
  }

  return new Date(timestamp).toISOString();
}

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomAmount(isHighRisk) {
  if (isHighRisk) {
    return Number((Math.random() * 40000 + 10000).toFixed(2));
  }

  return Number((Math.random() * 1800 + 20).toFixed(2));
}

function createMetadata(index, isBurst) {
  return {
    user_id: `user_${randomInt(1000, 9999)}`,
    device_id: `device_${randomInt(100, 999)}`,
    ip_address: `10.${randomInt(0, 255)}.${randomInt(0, 255)}.${randomInt(1, 254)}`,
    location: pick(LOCATIONS),
    stream_batch: `batch_${Math.floor(index / 50) + 1}`,
    frequency_profile: isBurst ? "burst" : "normal",
  };
}

function createBaseTransaction(index, timestamp) {
  const isHighRisk = Math.random() < state.options.highRiskRatio;
  const isBurst = Math.random() < state.options.frequencyBurstRatio;

  const senderAccount = isBurst
    ? `acct_burst_${randomInt(1, 5)}`
    : `acct_${randomInt(1000, 9999)}`;

  return {
    transaction_id: randomUUID(),
    idempotency_key: randomUUID(),
    event_timestamp: timestamp.toISOString(),
    sender_account: senderAccount,
    receiver_account: `acct_${randomInt(1000, 9999)}`,
    merchant_id: `merchant_${randomInt(1, 30).toString().padStart(2, "0")}`,
    amount: randomAmount(isHighRisk),
    currency: pick(CURRENCIES),
    transaction_type: pick(TRANSACTION_TYPES),
    channel: pick(CHANNELS),
    metadata: createMetadata(index, isBurst),
  };
}

function createDuplicateTransaction(previousTransaction, timestamp) {
  return {
    ...previousTransaction,
    transaction_id: randomUUID(),
    idempotency_key: randomUUID(),
    event_timestamp: timestamp.toISOString(),
    metadata: {
      ...previousTransaction.metadata,
      duplicate_pattern: true,
    },
  };
}

function createTransaction(index) {
  const timestamp = randomTimestampInRange(
    state.startDateMs,
    state.endDateMs,
  );
  const shouldDuplicate =
    state.generated.length > 0 && Math.random() < state.options.duplicateRatio;

  if (shouldDuplicate) {
    const source = state.generated[randomInt(0, state.generated.length - 1)];
    return createDuplicateTransaction(source, timestamp);
  }

  return createBaseTransaction(index, timestamp);
}

function randomTimestampInRange(startMs, endMs) {
  const offset = Math.floor(Math.random() * (endMs - startMs + 1));
  return new Date(startMs + offset);
}

async function postTransaction(url, payload, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "idempotency-key": payload.idempotency_key,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const responseText = await response.text();

    return {
      status: response.status,
      ok: response.ok,
      body: responseText,
    };
  } finally {
    clearTimeout(timer);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function runStdoutMode() {
  const transactions = [];

  for (let i = 0; i < state.options.count; i += 1) {
    const transaction = createTransaction(i);
    state.generated.push(transaction);
    transactions.push(transaction);
  }

  process.stdout.write(`${JSON.stringify(transactions, null, 2)}\n`);
}

async function runHttpMode() {
  const delayMs = Math.max(1, Math.floor(1000 / state.options.rate));

  for (let i = 0; i < state.options.count; i += 1) {
    const transaction = createTransaction(i);
    state.generated.push(transaction);

    try {
      const result = await postTransaction(
        state.options.url,
        transaction,
        state.options.timeoutMs,
      );

      const line = {
        index: i + 1,
        transaction_id: transaction.transaction_id,
        status: result.status,
        ok: result.ok,
      };

      if (!result.ok && result.body) {
        line.response = trimResponse(result.body);
      }

      process.stdout.write(`${JSON.stringify(line)}\n`);
    } catch (error) {
      process.stdout.write(
        `${JSON.stringify({
          index: i + 1,
          transaction_id: transaction.transaction_id,
          error: error.message,
        })}\n`,
      );
    }

    if (i < state.options.count - 1) {
      await sleep(delayMs);
    }
  }
}

function trimResponse(text) {
  return text.length > 200 ? `${text.slice(0, 200)}...` : text;
}

function printUsage() {
  const usage = `
Usage:
  node scripts/transaction-generator.js [options]

Options:
  --mode <stdout|http>           Output JSON locally or POST to an ingestion API
  --count <n>                    Number of transactions to generate
  --rate <n>                     Transactions per second in http mode
  --url <url>                    Ingestion endpoint for http mode
  --timeout-ms <n>               Request timeout in milliseconds
  --start-date <iso>             Inclusive lower bound for event_timestamp
  --end-date <iso>               Inclusive upper bound for event_timestamp
  --high-risk-ratio <0..1>       Ratio of high-value transactions
  --duplicate-ratio <0..1>       Ratio of duplicate-pattern transactions
  --frequency-burst-ratio <0..1> Ratio of bursty sender behavior

Examples:
  node scripts/transaction-generator.js --mode stdout --count 5
  node scripts/transaction-generator.js --mode stdout --count 100 --start-date 2026-01-01T00:00:00Z --end-date 2026-03-31T23:59:59Z
  node scripts/transaction-generator.js --mode http --count 100 --rate 20 --url http://localhost:8080/transactions
`;

  process.stdout.write(usage.trimStart());
}

const state = {
  options: null,
  generated: [],
  startDateMs: null,
  endDateMs: null,
};

async function main() {
  if (process.argv.includes("--help")) {
    printUsage();
    return;
  }

  state.options = parseArgs(process.argv.slice(2));
  state.startDateMs = Date.parse(state.options.startDate);
  state.endDateMs = Date.parse(state.options.endDate);

  if (state.startDateMs > state.endDateMs) {
    throw new Error("--start-date must be earlier than or equal to --end-date");
  }

  if (state.options.mode === "stdout") {
    await runStdoutMode();
    return;
  }

  await runHttpMode();
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
