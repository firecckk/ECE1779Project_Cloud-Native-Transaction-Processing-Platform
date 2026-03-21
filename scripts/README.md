# Scripts

## Transaction Generator

`transaction-generator.js` creates transaction payloads that match the ingestion input schema, not the full database row.

Example commands:

```bash
node scripts/transaction-generator.js --mode stdout --count 5
node scripts/transaction-generator.js --mode stdout --count 100 --start-date 2026-01-01T00:00:00Z --end-date 2026-03-31T23:59:59Z
node scripts/transaction-generator.js --mode http --count 100 --rate 20 --url http://localhost:8080/transactions
```

Default event timestamps are generated inside `2026-01-01T00:00:00Z` to `2026-03-31T23:59:59Z`, which is intended to support reporting queries over a visible historical range.

Generated fields:

- `transaction_id`
- `idempotency_key`
- `event_timestamp`
- `sender_account`
- `receiver_account`
- `merchant_id`
- `amount`
- `currency`
- `transaction_type`
- `channel`
- `metadata`

System-managed database fields such as `status`, `risk_score`, `created_at`, and `validated_at` are intentionally omitted.
