# state-machine.md

## Purpose
Define transaction lifecycle transitions, validation rules, and concurrency behavior.

## States
- `RECEIVED`: Transaction accepted by ingestion service and persisted.
- `VALID`: Transaction passed validation and risk checks.
- `REJECTED`: Transaction failed one or more validation/risk rules.

## Allowed State Transitions
- `RECEIVED -> VALID`
- `RECEIVED -> REJECTED`

## Forbidden State Transitions
- `VALID -> RECEIVED`
- `REJECTED -> RECEIVED`
- `VALID -> REJECTED` (unless business decides to support re-review workflow)
- `REJECTED -> VALID` (same note as above)

## Transition Rules

### 1) Ingestion
- Entry point: `POST /transactions`
- Preconditions:
  - Payload schema valid.
  - `transaction_id` not already present.
  - `Idempotency-Key` not already used with a different payload.
- Action:
  - Insert row with `status = RECEIVED`.
- Postconditions:
  - `created_at` populated.

### 2) Validation and Risk
- Trigger:
  - Worker polls rows where `status = RECEIVED`.
- Concurrency:
  - Use `FOR UPDATE SKIP LOCKED` to avoid duplicate processing.
- Decision:
  - If rules pass -> set `status = VALID`, set `risk_score`, set `validated_at`.
  - If rules fail -> set `status = REJECTED`, set `risk_score`, `reject_reason`, `validated_at`.

## Baseline Validation/Risk Rules
- High amount rule:
  - Example: `amount > 10000` adds risk points.
- Duplicate pattern rule:
  - Same sender/receiver/amount within short window adds risk points or rejects.
- Frequency anomaly rule:
  - Sender has more than N transactions in M minutes -> add risk or reject.

## Risk Score Convention
- Score range: `0-100`.
- Suggested policy:
  - `0-69`: pass (`VALID`)
  - `70-100`: reject (`REJECTED`)

## Reject Reason Codes
- `SCHEMA_INVALID`
- `DUPLICATE_TXN`
- `HIGH_RISK_AMOUNT`
- `FREQUENCY_ANOMALY`
- `BUSINESS_RULE_VIOLATION`

## Idempotency Rules
- Client must provide `Idempotency-Key` on write requests.
- Same key + same payload: return same logical result.
- Same key + different payload: return `409 CONFLICT_DUPLICATE`.

## Failure and Retry Rules
- Validation worker transient DB error:
  - Retry with exponential backoff (e.g., 1s, 2s, 4s).
- Max retries reached:
  - Keep `RECEIVED` and emit alert/log for manual inspection.

## Audit Requirements
- Each status change should be inserted into `transaction_status_audit`.
- Include `old_status`, `new_status`, `reason`, and `changed_at`.

## Sequence (High Level)
1. Client submits transaction.
2. Ingestion validates schema and writes `RECEIVED`.
3. Validation worker locks a batch and computes risk.
4. Worker writes `VALID` or `REJECTED`.
5. Reporting service reads finalized data for analytics.
