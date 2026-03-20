-- schema.sql
-- Purpose: Initial PostgreSQL schema for transaction processing platform.
-- Notes:
-- 1) Use UTC timestamps (timestamptz).
-- 2) Amount uses NUMERIC to avoid floating-point precision issues.
-- 3) Keep transaction_id and idempotency_key unique for deduplication.

BEGIN;

-- Optional extension for UUID generation if service-side IDs are needed.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Transaction status enum keeps state transitions constrained.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_status') THEN
    CREATE TYPE transaction_status AS ENUM ('RECEIVED', 'VALID', 'REJECTED');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Client-visible immutable transaction id.
  transaction_id UUID NOT NULL UNIQUE,

  -- Required for safe retries from clients.
  idempotency_key VARCHAR(128) NOT NULL UNIQUE,

  event_timestamp TIMESTAMPTZ NOT NULL,
  sender_account VARCHAR(64) NOT NULL,
  receiver_account VARCHAR(64) NOT NULL,
  merchant_id VARCHAR(64) NOT NULL,

  -- Numeric precision is adjustable; this is enough for typical demo use.
  amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
  currency CHAR(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  transaction_type VARCHAR(32) NOT NULL,
  channel VARCHAR(32) NOT NULL DEFAULT 'WEB',

  status transaction_status NOT NULL DEFAULT 'RECEIVED',
  risk_score INT CHECK (risk_score BETWEEN 0 AND 100),
  reject_reason VARCHAR(128),

  -- metadata can store non-critical context (ip, device_id, etc).
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  validated_at TIMESTAMPTZ,

  -- Optional optimistic concurrency control for updates.
  version INT NOT NULL DEFAULT 0
);

-- Audit table for status transitions (recommended for debugging and demos).
CREATE TABLE IF NOT EXISTS transaction_status_audit (
  id BIGSERIAL PRIMARY KEY,
  transaction_id UUID NOT NULL,
  old_status transaction_status,
  new_status transaction_status NOT NULL,
  reason VARCHAR(128),
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  changed_by VARCHAR(64) NOT NULL DEFAULT 'system'
);

-- Core access patterns:
-- 1) Validation workers fetch RECEIVED transactions ordered by created_at.
CREATE INDEX IF NOT EXISTS idx_transactions_status_created_at
  ON transactions (status, created_at);

-- 2) Reporting by merchant and time range.
CREATE INDEX IF NOT EXISTS idx_transactions_merchant_created_at
  ON transactions (merchant_id, created_at);

-- 3) Time-bounded reporting.
CREATE INDEX IF NOT EXISTS idx_transactions_event_timestamp
  ON transactions (event_timestamp);

-- 4) Query by state transitions / finalized records.
CREATE INDEX IF NOT EXISTS idx_transactions_status_validated_at
  ON transactions (status, validated_at);

-- 5) JSON metadata key lookups (optional but useful for analysis).
CREATE INDEX IF NOT EXISTS idx_transactions_metadata_gin
  ON transactions USING GIN (metadata);

-- Convenience view for reporting service.
CREATE OR REPLACE VIEW v_transaction_summary AS
SELECT
  transaction_id,
  merchant_id,
  amount,
  currency,
  status,
  risk_score,
  event_timestamp,
  created_at,
  validated_at
FROM transactions;

COMMIT;

-- Example worker query pattern (reference only):
-- SELECT id, transaction_id
-- FROM transactions
-- WHERE status = 'RECEIVED'
-- ORDER BY created_at
-- FOR UPDATE SKIP LOCKED
-- LIMIT 100;
