# Development Guide

## 1. Development Environment Setup

### Prerequisites
- Docker Desktop (or Docker Engine + Docker Compose)
- Node.js 18+ (optional, only needed for running scripts directly outside containers)
- Git
- PowerShell (Windows) or Bash (Linux/macOS)

### Clone and Start
```bash
git clone <your-repo-url>
cd ECE1779Project_Cloud-Native-Transaction-Processing-Platform
docker-compose up -d --build
```

### Service Endpoints (Local)
- Backend API: `http://localhost:8080`
- Frontend: `http://localhost:3000`
- PostgreSQL: `localhost:5432`

## 2. Environment Configuration

Backend runtime configuration is read from environment variables:
- `PORT` (default: `8080`)
- `DATABASE_URL` (default: `postgresql://transaction_user:transaction_password@localhost:5432/transaction_platform`)
- `LOG_LEVEL` (default: `INFO`)

Docker Compose defaults:
- `DATABASE_URL=postgresql://transaction_user:transaction_password@postgres:5432/transaction_platform`
- `PORT=8080`
- `LOG_LEVEL=INFO`
- `POSTGRES_USER=transaction_user`
- `POSTGRES_PASSWORD=transaction_password`
- `POSTGRES_DB=transaction_platform`
- `TZ=UTC`

## 3. Database and Storage

### Database Engine
- PostgreSQL 15 (containerized)

### Schema Initialization
- `database/schema.sql` is mounted to `/docker-entrypoint-initdb.d`
- Schema and base tables are initialized on first startup

### Stateful Storage
- Persistent volume: `postgres_data`
- Purpose: retain database state across container restarts

### Data Persistence Behavior
- `docker-compose stop` or `docker-compose down` keeps data
- `docker-compose down -v` removes volumes and resets database

## 4. Local Testing Workflow

### Step 1: Health Check
```bash
curl http://localhost:8080/health
```
Expected:
```json
{"status":"ok"}
```

### Step 2: Ingest a Transaction
```bash
curl -X POST http://localhost:8080/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id":"550e8400-e29b-41d4-a716-446655440000",
    "idempotency_key":"dev-test-001",
    "event_timestamp":"2026-03-31T12:00:00Z",
    "sender_account":"acct_1001",
    "receiver_account":"acct_2002",
    "merchant_id":"merchant_01",
    "amount":1500.25,
    "currency":"USD",
    "transaction_type":"PAYMENT",
    "channel":"WEB",
    "metadata":{"source":"dev-guide"}
  }'
```

### Step 3: Validation Execution
Validation supports both modes:
- Automatic: triggered asynchronously after each successful `POST /transactions`
- Manual (recovery/testing):
```bash
curl -X POST http://localhost:8080/validation/run-once \
  -H "Content-Type: application/json" \
  -d '{"limit":20}'
```

### Step 4: Reporting API Tests
```bash
curl "http://localhost:8080/reports/daily-volume?from=2026-03-01T00:00:00Z&to=2026-03-31T23:59:59Z"
curl "http://localhost:8080/reports/merchant-ranking?limit=10"
curl "http://localhost:8080/reports/risk-distribution?bucket_size=20"
```

## 5. Test Data Generation (Optional)

```bash
node scripts/transaction-generator.js \
  --mode http \
  --url http://localhost:8080/transactions \
  --count 100 \
  --rate 10
```

Useful options:
- `--start-date`, `--end-date`
- `--high-risk-ratio`
- `--duplicate-ratio`
- `--frequency-burst-ratio`

## 6. Debugging and Verification

```bash
docker-compose ps
docker-compose logs -f backend
docker-compose logs -f postgres
```

```bash
docker-compose exec postgres psql -U transaction_user -d transaction_platform -c "SELECT status, COUNT(*) FROM transactions GROUP BY status;"
docker-compose exec postgres psql -U transaction_user -d transaction_platform -c "SELECT transaction_id, old_status, new_status, changed_at FROM transaction_status_audit ORDER BY changed_at DESC LIMIT 20;"
```
