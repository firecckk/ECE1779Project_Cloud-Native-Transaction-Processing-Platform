# security.md

## Purpose
Security baseline for authentication, encryption, secrets handling, and data masking.

## Threat Model (Simple)
- Unauthorized API access
- Data leakage in transit or logs
- Secret exposure in code/repository
- SQL injection and malformed payload attacks
- Excessive request bursts (abuse / accidental load)

## Authentication and Authorization
- External APIs use `Authorization: Bearer <JWT>`.
- Each service should validate token signature and expiry.
- Optional short-term alternative for demo: static API key per environment.
- Apply least privilege:
  - Ingestion service DB user: insert + select minimal columns.
  - Validation service DB user: select + update status/risk fields.
  - Reporting service DB user: read-only.

## Transport Encryption
- Public endpoint must be HTTPS only (TLS 1.2+).
- Disable plain HTTP at ingress in production.
- Service-to-DB connection should require SSL/TLS where supported.

## Secret Management
- Never hardcode secrets in source files or Docker images.
- Store credentials in Kubernetes Secrets.
- Mount secrets via environment variables or files.
- Rotate DB password and JWT signing key periodically.
- Restrict secret read access using RBAC.

## Data Protection
- Data in transit: TLS.
- Data at rest: use encrypted volumes from cloud provider.
- Sensitive fields:
  - Account identifiers should be masked in logs.
  - Example mask: `ACCT_*****9001`.
- Avoid storing unnecessary PII in metadata.

## Input Validation and Injection Defense
- Enforce JSON schema validation in ingestion service.
- Use parameterized SQL statements only.
- Reject invalid currency/amount formats early.
- Enforce request size limit (e.g., 256 KB).

## Rate Limiting and Abuse Protection
- Add ingress or API-gateway rate limit.
- Suggested initial policy:
  - 100 requests/minute per client token.
  - Burst up to 20.
- Return `429 RATE_LIMITED` with retry hint.

## Logging and Privacy
- Never log raw tokens, passwords, or full account identifiers.
- Include `request_id` for traceability.
- Keep security-relevant logs:
  - Auth failures
  - Permission denied events
  - Repeated invalid payload attempts

## Network Security (Kubernetes)
- Use NetworkPolicy to restrict PostgreSQL access to required pods only.
- Keep database service internal (ClusterIP), no public exposure.
- Separate namespace for this project if possible.

## Security Checklist Before First Production Demo
- [ ] HTTPS certificate configured and valid
- [ ] Secrets stored in Kubernetes Secret
- [ ] No secrets committed to git
- [ ] DB users split by role (ingestion/validation/reporting)
- [ ] Input validation enabled on ingestion endpoint
- [ ] SQL queries are parameterized
- [ ] Logs verified for masking/redaction
- [ ] Rate limiting enabled
- [ ] Basic dependency vulnerability scan executed

## Incident Response (Mini Runbook)
- If secret leaked:
  - Rotate secret immediately
  - Redeploy affected services
  - Invalidate old tokens/keys
- If suspicious traffic spike:
  - Tighten rate limit
  - Scale ingestion service
  - Inspect logs by `request_id` and source
