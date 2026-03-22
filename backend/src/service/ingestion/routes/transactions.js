const express = require("express");
const db = require("../../../../../shared/src/db");
const { runValidationOnce } = require("../../validation/worker");

const router = express.Router();

const ISO_CURRENCY_REGEX = /^[A-Z]{3}$/;
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const VALID_TRANSACTION_TYPES = new Set(["PAYMENT", "TRANSFER", "REFUND"]);
const VALID_CHANNELS = new Set(["WEB", "MOBILE", "API"]);

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function validateTransactionPayload(payload) {
  const errors = [];

  if (!isPlainObject(payload)) {
    return ["Request body must be a JSON object"];
  }

  if (!isNonEmptyString(payload.transaction_id) || !UUID_REGEX.test(payload.transaction_id)) {
    errors.push("transaction_id must be a valid UUID");
  }

  if (!isNonEmptyString(payload.idempotency_key) || payload.idempotency_key.length > 128) {
    errors.push("idempotency_key must be a non-empty string up to 128 characters");
  }

  const eventDate = new Date(payload.event_timestamp);
  if (!isNonEmptyString(payload.event_timestamp) || Number.isNaN(eventDate.getTime())) {
    errors.push("event_timestamp must be a valid ISO-8601 timestamp");
  }

  if (!isNonEmptyString(payload.sender_account) || payload.sender_account.length > 64) {
    errors.push("sender_account must be a non-empty string up to 64 characters");
  }

  if (!isNonEmptyString(payload.receiver_account) || payload.receiver_account.length > 64) {
    errors.push("receiver_account must be a non-empty string up to 64 characters");
  }

  if (!isNonEmptyString(payload.merchant_id) || payload.merchant_id.length > 64) {
    errors.push("merchant_id must be a non-empty string up to 64 characters");
  }

  if (typeof payload.amount !== "number" || !Number.isFinite(payload.amount) || payload.amount <= 0) {
    errors.push("amount must be a positive number");
  }

  if (!isNonEmptyString(payload.currency) || !ISO_CURRENCY_REGEX.test(payload.currency)) {
    errors.push("currency must be a 3-letter uppercase code");
  }

  if (
    !isNonEmptyString(payload.transaction_type) ||
    !VALID_TRANSACTION_TYPES.has(payload.transaction_type)
  ) {
    errors.push("transaction_type must be one of PAYMENT, TRANSFER, REFUND");
  }

  if (payload.channel !== undefined) {
    if (!isNonEmptyString(payload.channel) || !VALID_CHANNELS.has(payload.channel)) {
      errors.push("channel must be one of WEB, MOBILE, API");
    }
  }

  if (payload.metadata !== undefined && !isPlainObject(payload.metadata)) {
    errors.push("metadata must be a JSON object");
  }

  return errors;
}

function normalizeTransactionPayload(payload) {
  return {
    transaction_id: payload.transaction_id,
    idempotency_key: payload.idempotency_key,
    event_timestamp: new Date(payload.event_timestamp).toISOString(),
    sender_account: payload.sender_account.trim(),
    receiver_account: payload.receiver_account.trim(),
    merchant_id: payload.merchant_id.trim(),
    amount: Number(payload.amount.toFixed(2)),
    currency: payload.currency.trim().toUpperCase(),
    transaction_type: payload.transaction_type.trim().toUpperCase(),
    channel: payload.channel ? payload.channel.trim().toUpperCase() : "WEB",
    metadata: payload.metadata || {},
  };
}

async function insertTransaction(transaction) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const insertResult = await client.query(
      `
        INSERT INTO transactions (
          transaction_id,
          idempotency_key,
          event_timestamp,
          sender_account,
          receiver_account,
          merchant_id,
          amount,
          currency,
          transaction_type,
          channel,
          status,
          metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'RECEIVED', $11::jsonb)
        RETURNING
          id,
          transaction_id,
          idempotency_key,
          event_timestamp,
          sender_account,
          receiver_account,
          merchant_id,
          amount,
          currency,
          transaction_type,
          channel,
          status,
          metadata,
          created_at;
      `,
      [
        transaction.transaction_id,
        transaction.idempotency_key,
        transaction.event_timestamp,
        transaction.sender_account,
        transaction.receiver_account,
        transaction.merchant_id,
        transaction.amount,
        transaction.currency,
        transaction.transaction_type,
        transaction.channel,
        JSON.stringify(transaction.metadata),
      ],
    );

    await client.query(
      `
        INSERT INTO transaction_status_audit (
          transaction_id,
          old_status,
          new_status,
          reason,
          changed_by
        )
        VALUES ($1, NULL, 'RECEIVED', 'INGESTED', 'ingestion-service');
      `,
      [transaction.transaction_id],
    );

    await client.query("COMMIT");
    return insertResult.rows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

function triggerValidationAsync(limit = 1) {
  // Fire-and-forget: ingestion success should not fail if validation worker errors.
  setImmediate(async () => {
    try {
      await runValidationOnce(limit);
    } catch (error) {
      console.error("[ValidationAutoTriggerError]", error);
    }
  });
}

router.post("/", async (req, res, next) => {
  try {
    const validationErrors = validateTransactionPayload(req.body);

    if (validationErrors.length > 0) {
      return res.status(400).json({
        error: "SCHEMA_INVALID",
        details: validationErrors,
      });
    }

    const transaction = normalizeTransactionPayload(req.body);
    const inserted = await insertTransaction(transaction);

    // Process newly received transactions as soon as possible.
    triggerValidationAsync(10);

    return res.status(201).json({
      message: "Transaction accepted",
      transaction: inserted,
    });
  } catch (error) {
    if (error.code === "23505") {
      return res.status(409).json({
        error: "CONFLICT_DUPLICATE",
        details: "transaction_id or idempotency_key already exists",
      });
    }

    return next(error);
  }
});

module.exports = router;
