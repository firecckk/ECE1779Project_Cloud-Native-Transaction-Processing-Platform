# Backend Reporting Service README

## Overview
This folder contains a Node.js reporting service for transaction analytics.
It reads from PostgreSQL and exposes reporting APIs used by frontend/dashboard.

## File Guide
- `package.json`
  Node.js project manifest. Defines dependencies (`express`, `pg`) and start scripts.

- `Dockerfile`
  Backend container build steps: install dependencies, copy source, expose `8080`, start service.

- `.dockerignore`
  Excludes unnecessary files from Docker build context.

- `src/config.js`
  Centralized runtime config (port, `DATABASE_URL`, log level).

- `src/db.js`
  PostgreSQL connection pool and helper methods:
  - `query(sql, params)` for SQL execution
  - `healthCheck()` for liveness/readiness checks

- `src/app.js`
  Express app composition:
  - JSON middleware
  - `GET /health`
  - Mount reporting routes under `/reports`
  - 404 handler and global error handler

- `src/server.js`
  Process entrypoint. Starts Express on configured port.

- `src/routes/reports.js`
  Reporting APIs and SQL logic:
  - `GET /reports/daily-volume`
  - `GET /reports/merchant-ranking`
  - `GET /reports/risk-distribution`

## API Endpoints

### 1) Health Check
- URL: `GET /health`
- Purpose: Verify service and DB connectivity.

Example:
```bash
curl -s http://localhost:8080/health
```

Expected response sample:
```json
{
  "status": "ok"
}
```

### 2) Ingest Transaction
- URL: `POST /transactions`
- Purpose: Validate ingestion payload, persist transaction with `status = RECEIVED`, and append an audit row.

Example:
```bash
curl -s -X POST http://localhost:8080/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "550e8400-e29b-41d4-a716-446655440000",
    "idempotency_key": "ingest-demo-001",
    "event_timestamp": "2026-03-01T15:00:00Z",
    "sender_account": "acct_1001",
    "receiver_account": "acct_2002",
    "merchant_id": "merchant_01",
    "amount": 259.99,
    "currency": "CAD",
    "transaction_type": "PAYMENT",
    "channel": "WEB",
    "metadata": {
      "device_id": "device_123",
      "location": "Toronto"
    }
  }'
```

Expected response sample:
```json
{
  "message": "Transaction accepted",
  "transaction": {
    "transaction_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "RECEIVED"
  }
}
```

### 3) Daily Volume
- URL: `GET /reports/daily-volume?from=<ISO_DATE>&to=<ISO_DATE>`
- Purpose: Daily transaction count, amount, avg amount, and status breakdown.

Example:
```bash
curl -s "http://localhost:8080/reports/daily-volume?from=2026-03-01T00:00:00Z&to=2026-03-31T23:59:59Z"
```

Expected response sample:
```json
{
  "from": "2026-03-01T00:00:00Z",
  "to": "2026-03-31T23:59:59Z",
  "rows": [
    {
      "date": "2026-03-20T00:00:00.000Z",
      "transaction_count": 3,
      "total_amount": "560.49",
      "average_amount": "186.83",
      "valid_count": 2,
      "rejected_count": 1
    }
  ]
}
```

### 4) Merchant Ranking
- URL: `GET /reports/merchant-ranking?limit=<N>&from=<ISO_DATE>&to=<ISO_DATE>`
- Purpose: Rank merchants by transaction amount/volume with risk summary.

Example:
```bash
curl -s "http://localhost:8080/reports/merchant-ranking?limit=5"
```

Expected response sample:
```json
{
  "from": null,
  "to": null,
  "limit": 5,
  "rows": [
    {
      "merchant_id": "m-001",
      "transaction_count": 2,
      "total_amount": "460.50",
      "average_amount": "230.25",
      "average_risk_score": "53.50",
      "valid_rate": "0.5000"
    },
    {
      "merchant_id": "m-002",
      "transaction_count": 1,
      "total_amount": "99.99",
      "average_amount": "99.99",
      "average_risk_score": "12.00",
      "valid_rate": "1.0000"
    }
  ]
}
```

### 5) Risk Distribution
- URL: `GET /reports/risk-distribution?bucket_size=<1-100>&from=<ISO_DATE>&to=<ISO_DATE>`
- Purpose: Build histogram-style bucket counts for risk scores.

Example:
```bash
curl -s "http://localhost:8080/reports/risk-distribution?bucket_size=20"
```

Expected response sample:
```json
{
  "from": null,
  "to": null,
  "bucket_size": 20,
  "rows": [
    {
      "risk_bucket": "0-19",
      "transaction_count": 1,
      "valid_count": 1,
      "rejected_count": 0
    },
    {
      "risk_bucket": "20-39",
      "transaction_count": 1,
      "valid_count": 1,
      "rejected_count": 0
    },
    {
      "risk_bucket": "80-99",
      "transaction_count": 1,
      "valid_count": 0,
      "rejected_count": 1
    }
  ]
}
```

## SQL Performance Notes (Mapped to Indexes)
- Daily volume query
  Uses time filter on `event_timestamp`.
  Related index: `idx_transactions_event_timestamp`.

- Merchant ranking query
  Uses time filter and `GROUP BY merchant_id`.
  Related indexes: `idx_transactions_event_timestamp`, `idx_transactions_merchant_created_at` (useful for merchant/time patterns).

- Risk distribution query
  Uses time filter plus computed bucketing expression on `risk_score`.
  Related index: `idx_transactions_event_timestamp` for range filtering.
  Note: bucket expression itself is computed at runtime and not directly index-backed.

## Run with Docker Compose
From repo root:

```bash
docker-compose up -d --build backend
```

Check service:

```bash
docker-compose ps
```
