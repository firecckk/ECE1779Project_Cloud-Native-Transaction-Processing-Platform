const express = require("express");
const db = require("../../../../../shared/src/db");

const router = express.Router();

// Parse positive integer query params like limit and bucket_size.
function parsePositiveInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

// Accept ISO-like date inputs and normalize invalid values to null.
function parseDate(value) {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

// Keep SQL params typed as timestamptz-friendly values.
function toIsoOrNull(date) {
  return date ? date.toISOString() : null;
}

// Daily aggregation: count and amount metrics, plus status breakdown.
router.get("/daily-volume", async (req, res, next) => {
  try {
    const fromDate = parseDate(req.query.from);
    const toDate = parseDate(req.query.to);

    if (req.query.from && !fromDate) {
      return res.status(400).json({ error: "Invalid from date" });
    }

    if (req.query.to && !toDate) {
      return res.status(400).json({ error: "Invalid to date" });
    }

    // Performance notes:
    // 1) Time filter on event_timestamp is index-backed by idx_transactions_event_timestamp.
    // 2) Aggregation by DATE(event_timestamp) is CPU-heavy on large ranges; keep date window bounded.
    // 3) status FILTER counts are computed in one pass to avoid multiple scans.
    const sql = `
      SELECT
        DATE(event_timestamp) AS date,
        COUNT(*)::int AS transaction_count,
        COALESCE(SUM(amount), 0)::numeric(18,2) AS total_amount,
        COALESCE(AVG(amount), 0)::numeric(18,2) AS average_amount,
        COUNT(*) FILTER (WHERE status = 'VALID')::int AS valid_count,
        COUNT(*) FILTER (WHERE status = 'REJECTED')::int AS rejected_count
      FROM transactions
      WHERE ($1::timestamptz IS NULL OR event_timestamp >= $1::timestamptz)
        AND ($2::timestamptz IS NULL OR event_timestamp <= $2::timestamptz)
      GROUP BY DATE(event_timestamp)
      ORDER BY date DESC;
    `;

    const result = await db.query(sql, [toIsoOrNull(fromDate), toIsoOrNull(toDate)]);

    return res.json({
      from: req.query.from || null,
      to: req.query.to || null,
      rows: result.rows
    });
  } catch (error) {
    return next(error);
  }
});

// Merchant ranking sorted by total amount, then by transaction volume.
router.get("/merchant-ranking", async (req, res, next) => {
  try {
    const fromDate = parseDate(req.query.from);
    const toDate = parseDate(req.query.to);
    const limit = parsePositiveInt(req.query.limit, 10);

    if (req.query.from && !fromDate) {
      return res.status(400).json({ error: "Invalid from date" });
    }

    if (req.query.to && !toDate) {
      return res.status(400).json({ error: "Invalid to date" });
    }

    // Performance notes:
    // 1) Time filter can use idx_transactions_event_timestamp.
    // 2) GROUP BY merchant_id + ORDER BY total_amount is aggregation-heavy; for large data,
    //    consider a materialized daily summary table to reduce query cost.
    // 3) LIMIT keeps result set small even if source table is large.
    const sql = `
      SELECT
        merchant_id,
        COUNT(*)::int AS transaction_count,
        COALESCE(SUM(amount), 0)::numeric(18,2) AS total_amount,
        COALESCE(AVG(amount), 0)::numeric(18,2) AS average_amount,
        COALESCE(AVG(risk_score), 0)::numeric(10,2) AS average_risk_score,
        (
          COUNT(*) FILTER (WHERE status = 'VALID')::numeric
          / NULLIF(COUNT(*), 0)
        )::numeric(10,4) AS valid_rate
      FROM transactions
      WHERE ($1::timestamptz IS NULL OR event_timestamp >= $1::timestamptz)
        AND ($2::timestamptz IS NULL OR event_timestamp <= $2::timestamptz)
      GROUP BY merchant_id
      ORDER BY total_amount DESC, transaction_count DESC
      LIMIT $3;
    `;

    const result = await db.query(sql, [
      toIsoOrNull(fromDate),
      toIsoOrNull(toDate),
      limit
    ]);

    return res.json({
      from: req.query.from || null,
      to: req.query.to || null,
      limit,
      rows: result.rows
    });
  } catch (error) {
    return next(error);
  }
});

// Risk distribution groups records into score buckets (for charts/histograms).
router.get("/risk-distribution", async (req, res, next) => {
  try {
    const fromDate = parseDate(req.query.from);
    const toDate = parseDate(req.query.to);
    const bucketSize = parsePositiveInt(req.query.bucket_size, 20);

    if (bucketSize > 100) {
      return res.status(400).json({ error: "bucket_size must be between 1 and 100" });
    }

    if (req.query.from && !fromDate) {
      return res.status(400).json({ error: "Invalid from date" });
    }

    if (req.query.to && !toDate) {
      return res.status(400).json({ error: "Invalid to date" });
    }

    // Performance notes:
    // 1) Time filter can use idx_transactions_event_timestamp.
    // 2) Bucketing is computed expression logic, so Postgres cannot use a direct index for the bucket.
    // 3) For high throughput analytics, precompute bucket counts in a periodic job/materialized view.
    const sql = `
      WITH bucketed AS (
        SELECT
          CASE
            WHEN risk_score IS NULL THEN 'UNKNOWN'
            ELSE CONCAT(
              FLOOR(risk_score / $3::numeric) * $3::int,
              '-',
              LEAST((FLOOR(risk_score / $3::numeric) + 1) * $3::int - 1, 100)
            )
          END AS risk_bucket,
          status
        FROM transactions
        WHERE ($1::timestamptz IS NULL OR event_timestamp >= $1::timestamptz)
          AND ($2::timestamptz IS NULL OR event_timestamp <= $2::timestamptz)
      )
      SELECT
        risk_bucket,
        COUNT(*)::int AS transaction_count,
        COUNT(*) FILTER (WHERE status = 'VALID')::int AS valid_count,
        COUNT(*) FILTER (WHERE status = 'REJECTED')::int AS rejected_count
      FROM bucketed
      GROUP BY risk_bucket
      ORDER BY CASE WHEN risk_bucket = 'UNKNOWN' THEN 1 ELSE 0 END, risk_bucket;
    `;

    const result = await db.query(sql, [
      toIsoOrNull(fromDate),
      toIsoOrNull(toDate),
      bucketSize
    ]);

    return res.json({
      from: req.query.from || null,
      to: req.query.to || null,
      bucket_size: bucketSize,
      rows: result.rows
    });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
