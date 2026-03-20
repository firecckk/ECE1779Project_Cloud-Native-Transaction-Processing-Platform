# observability.md

## Purpose
Define logs, metrics, and alerts for operating the transaction platform.

## Logging Standard
Use structured JSON logs for all services.

### Required Log Fields
- `timestamp` (ISO-8601 UTC)
- `level` (`DEBUG|INFO|WARN|ERROR`)
- `service` (ingestion/validation/reporting)
- `environment` (dev/staging/prod)
- `request_id`
- `transaction_id` (if available)
- `message`
- `error_code` (if applicable)
- `latency_ms` (for request logs)

### Logging Rules
- Log one summary line per request completion.
- Log validation decisions with reason and risk score.
- Mask sensitive fields (account numbers, tokens).
- Keep log volume bounded; avoid large payload dumps.

## Metrics
Prometheus-style metrics are recommended.

### API Metrics
- `http_requests_total{service,route,method,status}`
- `http_request_duration_ms_bucket{service,route,method}`
- `http_request_duration_ms_count`
- `http_request_duration_ms_sum`

### Business Metrics
- `transactions_received_total`
- `transactions_valid_total`
- `transactions_rejected_total`
- `risk_score_histogram_bucket`
- `validation_backlog_count` (count of RECEIVED rows)

### Infrastructure Metrics
- CPU and memory usage per pod
- Pod restart count
- DB connection usage
- DB query latency (if available)

## Dashboards (Minimum)
- API traffic dashboard:
  - RPS by endpoint
  - P95/P99 latency
  - 4xx/5xx error rates
- Business dashboard:
  - Received/Valid/Rejected over time
  - Risk score distribution
  - Top merchants by volume
- Infra dashboard:
  - Pod CPU/memory
  - Restart count
  - HPA replica count over time

## Alert Rules (Initial)
- High error rate:
  - Condition: 5xx ratio > 2% for 5 minutes
  - Severity: high
- High latency:
  - Condition: P95 latency > 800ms for 10 minutes
  - Severity: medium
- Validation backlog growth:
  - Condition: backlog increasing for 15 minutes
  - Severity: high
- Pod instability:
  - Condition: restart count > 3 in 10 minutes
  - Severity: high
- DB connection saturation:
  - Condition: > 80% connections for 10 minutes
  - Severity: medium

## Tracing and Correlation
- Every request should have `X-Request-Id`.
- If absent, generate one at ingress and propagate downstream.
- Include the same ID in API logs and validation worker logs.

## SLO Suggestions (Course Project)
- API availability: 99.0%
- `POST /transactions` success rate: >= 99%
- `POST /transactions` P95 latency: < 500ms under baseline load
- Validation lag: 95% of received transactions processed within 60s

## Verification Checklist
- [ ] Logs contain required fields
- [ ] Metrics endpoint exposed (or collected by sidecar/agent)
- [ ] Dashboards created and screenshots captured
- [ ] Alerts tested with synthetic failures
- [ ] Request ID trace tested across all services
