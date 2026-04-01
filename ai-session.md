# AI Interaction Record

This file documents representative AI-assisted interactions that influenced the project. These examples support the AI Assistance & Verification summary in `README.md`. The selected sessions are intended to show both the usefulness and the limitations of AI suggestions, as well as how the team verified and adapted them.

---

## Session 1: Mapping the System Architecture Into Project Structure

### Prompt (you sent to AI)

```text
We want this project to contain four services: ingestion service, validation & risk service, reporting service, and PostgreSQL. How should these be organized in the repository? Which parts belong to frontend, backend, and database?
```

### AI Response (trimmed)

```text
The frontend should contain the web UI, dashboard, charts, and API-calling code.
The backend should contain three services:
- ingestion-service
- validation-risk-service
- reporting-service
PostgreSQL should be kept as a separate database layer rather than being placed inside backend.
A reasonable structure is:

frontend/
backend/
  ingestion-service/
  validation-risk-service/
  reporting-service/
database/
k8s/
scripts/
```

### What Your Team Did With It

- The suggestion was useful because it clarified service boundaries and helped us separate stateless application services from the stateful database layer.
- However, the AI response assumed the repository was already fully split into independent backend services, which was not true at that point. Our actual backend was still a single Node.js app with multiple routes.
- We verified the repository state ourselves, then adopted the architectural separation as a design target while implementing ingestion and validation inside the existing backend first. This let us move forward without doing a premature refactor.

---

## Session 2: Designing the Transaction Generator Schema

### Prompt (you sent to AI)

```text
We want to build a transaction generator for streaming data. What should the structure of each transaction look like? Should it match the database schema exactly?
```

### AI Response (trimmed)

```text
The generator payload should not exactly match the full database row.
It should match the ingestion input schema instead.

Recommended payload:
- transaction_id
- idempotency_key
- event_timestamp
- sender_account
- receiver_account
- merchant_id
- amount
- currency
- transaction_type
- channel
- metadata

Do not include internal database-managed fields such as:
- id
- status
- risk_score
- reject_reason
- created_at
- validated_at
- version
```

### What Your Team Did With It

- This was useful because it helped us distinguish between external input data and internal storage state. That made the ingestion endpoint cleaner and more realistic.
- We agreed with the overall separation, but we did not copy the suggestion blindly. We adapted the field set to match our actual PostgreSQL schema and ingestion route implementation.
- We verified correctness by checking the generated payload against our database schema, request validation logic, and successful insertion into PostgreSQL through `POST /transactions`.

---

## Session 3: Auto-Scaling Strategy for Ingestion and Validation

### Prompt (you sent to AI)

```text
We want to demonstrate auto-scaling and high availability. Can ingestion and validation scale independently under high load? 
```

### AI Response (trimmed)

```text
Your current project has an HPA for the backend, but it scales a single backend Deployment rather than ingestion and validation independently.
To scale ingestion and validation separately, they should be split into separate Deployments with separate HPAs.
Validation is a good candidate for horizontal scaling because it already uses FOR UPDATE SKIP LOCKED when claiming RECEIVED transactions.
```

### What Your Team Did With It

- The most useful part was the explanation that our current HPA only scaled the monolithic backend Deployment, not the ingestion and validation services separately.
- The AI suggestion was directionally correct, but it assumed we had already completed the service split in Kubernetes. In our actual repository, the backend still grouped multiple routes together.
- We verified this by reviewing our Kubernetes manifests and backend implementation. We confirmed that `FOR UPDATE SKIP LOCKED` in the validation worker supported future horizontal scaling, and we documented separate ingestion/validation Deployments as a next-step improvement rather than claiming they were already fully implemented.

---

## Session 4: Debugging Frontend Access Through Docker Compose

### Prompt (you sent to AI)

```text
The frontend page at http://localhost:3000 is not opening. What should we check?
```

### AI Response (trimmed)

```text
Check whether the frontend container is running, whether port 3000 is published, and inspect frontend logs.
If the frontend service is not up, start it with Docker Compose and verify that localhost:3000 is being served.
```

### What Your Team Did With It

- This was useful as a debugging checklist because it pointed us toward container status, port binding, and service logs instead of guessing at frontend code issues.
- The AI response was generic and did not know the exact state of our local Docker environment, so it could not by itself identify the real cause.
- We verified the problem by checking `docker compose ps`, confirming that the frontend container was not running, then starting it and confirming that the UI was being served through container logs and browser access.

---
