const db = require("../../../../shared/src/db");

const HIGH_AMOUNT_MEDIUM_THRESHOLD = 1000;
const HIGH_AMOUNT_CRITICAL_THRESHOLD = 5000;
const HIGH_AMOUNT_LIMIT = 10000;
const DUPLICATE_LOOKBACK_HOURS = 24;
const FREQUENCY_LOOKBACK_MINUTES = 10;
const FREQUENCY_ANOMALY_THRESHOLD = 5;
const FREQUENCY_CRITICAL_THRESHOLD = 10;
const REJECT_RISK_THRESHOLD = 70;

// Claim a small batch of RECEIVED transactions for validation.
// Uses FOR UPDATE SKIP LOCKED to allow multiple workers safely.
async function claimReceivedTransactions(limit = 100) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const result = await client.query(
      `
        SELECT id, transaction_id, amount, merchant_id, event_timestamp, created_at
        FROM transactions
        WHERE status = 'RECEIVED'
        ORDER BY created_at
        FOR UPDATE SKIP LOCKED
        LIMIT $1;
      `,
      [limit]
    );

    await client.query("COMMIT");
    return result.rows;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Evaluate all validation rules for a transaction and return the decision details.
async function evaluateRules(client, transaction) {
  let riskScore = 0;
  const reasons = [];

  if (Number(transaction.amount) >= HIGH_AMOUNT_LIMIT) {
    riskScore = 100;
    reasons.push("HIGH_AMOUNT_LIMIT");
  } else if (Number(transaction.amount) >= HIGH_AMOUNT_CRITICAL_THRESHOLD) {
    riskScore += 60;
    reasons.push("HIGH_AMOUNT_CRITICAL");
  } else if (Number(transaction.amount) >= HIGH_AMOUNT_MEDIUM_THRESHOLD) {
    riskScore += 30;
    reasons.push("HIGH_AMOUNT_MEDIUM");
  }

  const duplicateResult = await client.query(
    `
      SELECT COUNT(*)::int AS duplicate_count
      FROM transactions
      WHERE id <> $1
        AND sender_account = $2
        AND receiver_account = $3
        AND merchant_id = $4
        AND amount = $5
        AND event_timestamp >= ($6::timestamptz - ($7 || ' hours')::interval)
        AND status IN ('VALID', 'REJECTED');
    `,
    [
      transaction.id,
      transaction.sender_account,
      transaction.receiver_account,
      transaction.merchant_id,
      transaction.amount,
      transaction.event_timestamp,
      DUPLICATE_LOOKBACK_HOURS
    ]
  );

  const duplicateCount = duplicateResult.rows[0].duplicate_count;
  const hasDuplicatePattern = duplicateCount > 0;
  if (hasDuplicatePattern) {
    riskScore += 40;
    reasons.push("DUPLICATE_PATTERN");
  }

  const frequencyResult = await client.query(
    `
      SELECT COUNT(*)::int AS recent_sender_count
      FROM transactions
      WHERE id <> $1
        AND sender_account = $2
        AND event_timestamp >= ($3::timestamptz - ($4 || ' minutes')::interval)
        AND status IN ('RECEIVED', 'VALID', 'REJECTED');
    `,
    [transaction.id, transaction.sender_account, transaction.event_timestamp, FREQUENCY_LOOKBACK_MINUTES]
  );

  const recentSenderCount = frequencyResult.rows[0].recent_sender_count;
  const hasFrequencyAnomaly = recentSenderCount >= FREQUENCY_ANOMALY_THRESHOLD;
  const hasCriticalFrequency = recentSenderCount >= FREQUENCY_CRITICAL_THRESHOLD;
  if (hasFrequencyAnomaly) {
    riskScore += 30;
    reasons.push("FREQUENCY_ANOMALY");
  }

  riskScore = Math.min(riskScore, 100);

  const rejected = hasDuplicatePattern || hasCriticalFrequency || riskScore >= REJECT_RISK_THRESHOLD;
  const newStatus = rejected ? "REJECTED" : "VALID";
  const rejectReason = rejected ? reasons.join("|") : null;

  return {
    newStatus,
    riskScore,
    rejectReason,
    reasons,
    duplicateCount,
    recentSenderCount
  };
}

async function applyValidationDecision(client, transaction, decision) {
  const updateResult = await client.query(
    `
      UPDATE transactions
      SET
        status = $2,
        risk_score = $3,
        reject_reason = $4,
        validated_at = NOW(),
        version = version + 1
      WHERE id = $1
        AND status = 'RECEIVED'
      RETURNING transaction_id, status, risk_score, reject_reason, validated_at;
    `,
    [transaction.id, decision.newStatus, decision.riskScore, decision.rejectReason]
  );

  if (updateResult.rowCount === 0) {
    return null;
  }

  await client.query(
    `
      INSERT INTO transaction_status_audit (
        transaction_id,
        old_status,
        new_status,
        reason,
        changed_by
      )
      VALUES ($1, 'RECEIVED', $2, $3, 'validation-service');
    `,
    [
      transaction.transaction_id,
      decision.newStatus,
      decision.reasons.length > 0 ? decision.reasons.join("|") : "VALIDATION_PASSED"
    ]
  );

  return {
    transaction_id: updateResult.rows[0].transaction_id,
    status: updateResult.rows[0].status,
    risk_score: updateResult.rows[0].risk_score,
    reject_reason: updateResult.rows[0].reject_reason,
    duplicate_count: decision.duplicateCount,
    recent_sender_count: decision.recentSenderCount
  };
}

// Run one validation pass in a single transaction, safely locking rows while processing.
async function runValidationOnce(limit = 100) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const claimResult = await client.query(
      `
        SELECT
          id,
          transaction_id,
          amount,
          merchant_id,
          sender_account,
          receiver_account,
          event_timestamp,
          created_at
        FROM transactions
        WHERE status = 'RECEIVED'
        ORDER BY created_at
        FOR UPDATE SKIP LOCKED
        LIMIT $1;
      `,
      [limit]
    );

    const claimed = claimResult.rows;
    const processed = [];

    for (const transaction of claimed) {
      const decision = await evaluateRules(client, transaction);
      const updateResult = await applyValidationDecision(client, transaction, decision);

      if (updateResult) {
        processed.push(updateResult);
      }
    }

    await client.query("COMMIT");

    return {
      claimed_count: claimed.length,
      processed_count: processed.length,
      valid_count: processed.filter((row) => row.status === "VALID").length,
      rejected_count: processed.filter((row) => row.status === "REJECTED").length,
      rows: processed
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = {
  claimReceivedTransactions,
  runValidationOnce
};
