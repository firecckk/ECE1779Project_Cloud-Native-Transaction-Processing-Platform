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

## DOKS Scripts

- `doks-deploy.sh`
	Builds and pushes the backend image to DigitalOcean Container Registry, applies the DOKS overlay, and prints the public service endpoint.

- `doks-delete.sh`
	Deletes the configured DOKS cluster. By default it also removes associated load balancers, volumes, and volume snapshots.

- `doks-verify.sh`
	Runs a curl-based smoke test against the deployed DOKS backend.

- `doks-scale-nodes.sh`
	Scales the current DOKS node pool to the requested node count.

Examples:

```bash
./scripts/doks-delete.sh
DELETE_ASSOCIATED_RESOURCES=0 ./scripts/doks-delete.sh k8s-ece1779-transcation-platform
./scripts/doks-scale-nodes.sh 2
./scripts/doks-scale-nodes.sh 3 pool-2h5y79uc1
```
