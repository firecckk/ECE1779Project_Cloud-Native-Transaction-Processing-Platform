# Team Division Plan (4 Members)

## Objective
Define a practical 4-person work split based on current project docs:
- `openapi.yaml`
- `schema.sql`
- `state-machine.md`
- `security.md`
- `observability.md`
- `runbook.md`

## Role Assignment

### 1. Member A - API and Ingestion Owner
**Primary docs:** `openapi.yaml`  
**Scope:** Ingestion service and API contract enforcement

**Responsibilities**
- Finalize `POST /transactions` and `GET /transactions/{transaction_id}` request/response formats.
- Implement request validation and standardized error responses.
- Implement idempotency using `Idempotency-Key`.
- Implement `X-Request-Id` propagation.

**Deliverables**
- Stable ingestion API implementation.
- API unit tests and integration tests.
- Updated API examples in `openapi.yaml`.

**Acceptance criteria**
- Duplicate retries do not create duplicate records.
- Error codes/messages follow contract.

---

### 2. Member B - Validation and Risk Owner
**Primary docs:** `state-machine.md`  
**Scope:** Validation worker and state transition logic

**Responsibilities**
- Implement allowed transitions: `RECEIVED -> VALID/REJECTED`.
- Implement baseline risk rules:
  - High amount rule
  - Duplicate pattern rule
  - Frequency anomaly rule
- Add concurrency-safe processing (e.g., `FOR UPDATE SKIP LOCKED` pattern).
- Write reason codes and risk score updates.

**Deliverables**
- Worker process for batch polling and status updates.
- Rule engine module with tests.
- Status audit writing logic.

**Acceptance criteria**
- A transaction is processed exactly once.
- `risk_score` and `reject_reason` are consistent and testable.

---

### 3. Member C - Data and Reporting Owner
**Primary docs:** `schema.sql`  
**Scope:** PostgreSQL schema, indexes, and reporting API queries

**Responsibilities**
- Finalize schema and indexes.
- Maintain migration scripts and initialization flow.
- Implement reporting endpoints:
  - Daily volume
  - Merchant ranking
  - Risk distribution
- Tune SQL for query performance.

**Deliverables**
- Production-ready schema script and migration notes.
- Reporting service endpoints with test data.
- SQL performance check notes (`EXPLAIN` results).

**Acceptance criteria**
- Reporting APIs return correct aggregates.
- Core queries are index-backed and stable.

---

### 4. Member D - Platform, Security, and Operations Owner
**Primary docs:** `security.md`, `observability.md`, `runbook.md`  
**Scope:** Kubernetes deployment, CI/CD, security controls, and ops readiness

**Responsibilities**
- Build deployment manifests and environment configuration.
- Configure Secrets, RBAC, and network restrictions.
- Set up HPA and verify scaling behavior.
- Implement CI/CD pipeline (build, push, deploy, smoke test).
- Build dashboard/alerts and document incident handling.

**Deliverables**
- Deployable K8s stack.
- CI/CD workflow with rollback path.
- Monitoring dashboards and alert rules.
- Completed operational runbook.

**Acceptance criteria**
- One-command or one-pipeline deployment works end-to-end.
- Rollback path is validated.
- Basic alerts fire under synthetic failure.

## Collaboration Rules
- Contract-first: update docs before changing implementation.
- No breaking API/schema changes without team agreement.
- Daily 15-minute sync focused on blockers and interface changes.
- Use consistent naming for fields, statuses, and reason codes.

## Suggested Timeline (1 Week)

### Day 1-2
- A + C freeze API and schema contracts.
- B scaffolds rule engine and state transition module.
- D prepares K8s namespace, secrets strategy, and CI skeleton.

### Day 3-4
- A completes ingestion implementation and tests.
- B completes validation worker with concurrency controls.
- C completes reporting endpoints and query tuning.
- D deploys staging stack and observability baseline.

### Day 5
- End-to-end integration and bug fixing.
- Load test for HPA demonstration.
- Rollback drill following `runbook.md`.
- Demo script and final verification.

## Done Definition
- All required endpoints are functional and tested.
- State transitions are correct and auditable.
- Deployment is repeatable with documented rollback.
- Security and observability baselines are in place.
