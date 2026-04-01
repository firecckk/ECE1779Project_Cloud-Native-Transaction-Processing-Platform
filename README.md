# Cloud-Native Transaction Processing and Risk Analytics Platform

## Team Information

- **Team Number:** Team 27
- **Member 1:** Xiangyu Liu | 1006743179 | swift.liu@mail.utoronto.ca
- **Member 2:** Jingwei Liu | 1006058052 | klroll.liu@mail.utoronto.ca
- **Member 3:** Yilin Wang | 1007120937 | ilynn.wang@mail.utoronto.ca
- **Member 4:** Kun Cheng | 1004420824 | kun.cheng@mail.utoronto.ca

## Motivation

Our team chose this project to explore how cloud-native systems can support high-volume transaction processing in a realistic financial-style workflow. Modern transaction platforms must ingest large streams of events, validate data reliably, apply business and risk rules, and generate analytical reports without losing consistency or scalability. We wanted to build a project that combined distributed systems concepts with practical backend engineering, database design, containerization, and orchestration. The project is significant because it demonstrates how a modular architecture can separate ingestion, validation, analytics, and persistence while remaining deployable in a containerized environment.

## Objectives

The main objective of this project was to design and implement a cloud-native transaction processing and risk analytics platform that simulates realistic transaction lifecycles. Through this implementation, our team aimed to:

- accept high-volume transaction events through a dedicated ingestion interface
- validate and risk-score transactions using rule-based logic
- store transaction data persistently in PostgreSQL
- provide analytical reporting endpoints and a web dashboard
- deploy the system using containerized services
- demonstrate orchestration concepts such as scaling, persistence, and service separation using Kubernetes

## Technical Stack

Our project uses the following technologies:

- **Frontend:** HTML, CSS, JavaScript
- **Backend:** Node.js, Express
- **Database:** PostgreSQL
- **Containerization:** Docker, Docker Compose
- **Orchestration:** Kubernetes
- **Cloud-Native Configuration:** Kubernetes Deployments, Services, Horizontal Pod Autoscaler (HPA), PersistentVolumeClaim (PVC)
- **Testing / Local Verification:** curl, Docker logs, manual browser testing
- **Data Generation:** custom transaction generator script in Node.js

We chose Kubernetes as the orchestration approach because it provides a more realistic cloud-native deployment model than Swarm and supports service abstraction, auto-scaling, health probes, and persistent storage integration.

## Features

### 1. Transaction Ingestion

The platform accepts transaction events through a `POST /transactions` endpoint. The ingestion service validates the incoming schema, checks required fields such as `transaction_id`, `idempotency_key`, `amount`, and `event_timestamp`, and inserts valid transactions into PostgreSQL with initial status `RECEIVED`.

This feature fulfills the project requirement of handling streaming-style transaction intake and establishes the first step in the transaction lifecycle.

### 2. Validation and Risk Scoring

A validation component processes transactions in `RECEIVED` state and applies rule-based checks such as:

- high-value transaction detection
- duplicate transaction pattern detection
- frequency-based anomaly detection

Each transaction is assigned a risk score and updated to either `VALID` or `REJECTED`. This feature demonstrates business rule enforcement and asynchronous processing after ingestion.

### 3. Reporting Service

The reporting service exposes analytical endpoints including:

- daily transaction volume
- merchant ranking
- risk score distribution

These endpoints aggregate data directly from PostgreSQL and allow users to inspect transaction trends across time ranges. This fulfills the requirement for data analysis and reporting.

### 4. Web Dashboard

The frontend provides a browser-based interface that visualizes reporting data and allows users to inspect platform outputs more intuitively. It serves as the presentation layer of the system and makes the reporting functionality easier to demonstrate during evaluation.

### 5. Transaction Generator

To simulate high-throughput transaction streams, the project includes a transaction generator script that produces structured transaction payloads over a configurable time range. This allowed us to populate the system with realistic sample data and test ingestion and reporting workflows under load.

### 6. Containerized Deployment

All major services are containerized. Docker Compose supports local development, while Kubernetes manifests support cluster deployment. PostgreSQL is configured as a stateful component with persistent storage, while backend services are designed as stateless application services.

## User Guide

### Accessing the Application

After deployment, users can access:

- **Frontend Dashboard:** `http://localhost:3000` (local) or `http://209.38.3.66/` (live cloud)
- **Backend API:** `http://localhost:8080` (local) or `http://209.38.3.66/api/` (live cloud)

### Main Features and Usage

#### 1. Submit a Transaction

Users or the transaction generator send a request to:

```text
POST /transactions
```

Example payload:

```json
{
  "transaction_id": "550e8400-e29b-41d4-a716-446655440000",
  "idempotency_key": "demo-key-001",
  "event_timestamp": "2026-03-05T12:00:00Z",
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
}
```

Expected behavior:

- valid payloads are stored in PostgreSQL
- status is set to `RECEIVED`
- invalid payloads return `400`
- duplicate requests return `409`

#### 2. Run Validation

When a new transaction is submitted via `POST /transactions`, the backend automatically triggers the Validation Worker in the background asynchronously, with no manual action required.

However, for special scenarios, validation can also be triggered manually through the validation endpoint:

```text
POST /validation/run-once
```

This processes a batch of `RECEIVED` transactions and updates them to `VALID` or `REJECTED` based on the implemented rules.

#### 3. View Reports

Users can query the reporting endpoints:

```text
GET /reports/daily-volume
GET /reports/merchant-ranking
GET /reports/risk-distribution
```

These endpoints support time-range filtering and are used by the frontend dashboard.

#### 4. Use the Web Dashboard

Users open the frontend in a browser and view charts or summaries for transaction volume, merchant activity, and risk distribution. The frontend acts as the user-facing interface to the reporting service.

### Screenshots

![Transaction Console 1](./img/transaction%20console%201.jpg)
![Transaction Console 2](./img/transaction%20console%202.jpg)

## Development Guide

### Prerequisites

Install the following tools:

- Docker
- Docker Compose
- Node.js
- npm
- Git
- curl
- kubectl
- Minikube (for local Kubernetes testing)

### Local Minikube Deployment Procedure

#### 1. Required Tools

The following tools must be installed before deployment:

- `git`
- `docker`
- `kubectl`
- `minikube`
- `curl`

The local environment can be checked with:

```bash
git --version
docker --version
kubectl version --client
minikube version
docker ps
```

If `docker ps` fails, Docker permissions must be fixed before continuing.

#### 2. Clone the Repository

```bash
git clone https://github.com/firecckk/ECE1779Project_Cloud-Native-Transaction-Processing-Platform.git
cd ECE1779Project_Cloud-Native-Transaction-Processing-Platform
```

#### 3. Local Deployment

The recommended deployment method is the repository's automated local deployment script:

```bash
./scripts/local-deploy.sh
```

The script performs the following actions:

1. Start the Minikube cluster.
2. Build the backend and frontend images inside Minikube.
3. Apply the `k8s/overlays/minikube` configuration.
4. Wait for all 5 services to finish rollout.
5. Run the built-in smoke test.

The deployment is considered successful when the script ends with:

```bash
[local-deploy] deployment finished successfully
```

#### 4. Verify the Deployment

##### 4.1 Check Pods

```bash
kubectl get pods -n transaction-platform
```

The following five Pods should be present and in the `Running` state:

- `transaction-postgres`
- `transaction-ingestion`
- `transaction-validation`
- `transaction-reporting`
- `transaction-frontend`

##### 4.2 Get the Frontend URL

```bash
FRONTEND_URL=$(minikube service transaction-frontend -n transaction-platform --url)
echo "$FRONTEND_URL"
```

##### 4.3 Health Check

```bash
curl -i "$FRONTEND_URL/health"
```

The expected response is:

```json
{"status":"ok"}
```

##### 4.4 Check the Reporting API

```bash
curl -s "$FRONTEND_URL/api/reports/merchant-ranking?limit=5"
```

The expected result is valid JSON containing a `rows` field. An empty array is acceptable.

##### 4.5 Run the Built-In Verification Script

```bash
./scripts/local-verify.sh
```

The verification is successful when the script ends with:

```bash
[local-verify] verification finished successfully
```

#### 5. Minimal Demonstration Commands

```bash
git clone https://github.com/firecckk/ECE1779Project_Cloud-Native-Transaction-Processing-Platform.git
cd ECE1779Project_Cloud-Native-Transaction-Processing-Platform
./scripts/local-deploy.sh
kubectl get pods -n transaction-platform
FRONTEND_URL=$(minikube service transaction-frontend -n transaction-platform --url)
curl -i "$FRONTEND_URL/health"
curl -s "$FRONTEND_URL/api/reports/merchant-ranking?limit=5"
```

This command sequence is sufficient to demonstrate that the project can be deployed locally and that the frontend and reporting API are reachable.

#### 6. Basic Troubleshooting

If any Pod does not start correctly, run:

```bash
kubectl get pods -n transaction-platform
kubectl describe pod <pod-name> -n transaction-platform
kubectl logs deployment/transaction-postgres -n transaction-platform
kubectl logs deployment/transaction-ingestion -n transaction-platform
kubectl logs deployment/transaction-validation -n transaction-platform
kubectl logs deployment/transaction-reporting -n transaction-platform
kubectl logs deployment/transaction-frontend -n transaction-platform
```

If the frontend URL is not available, run:

```bash
kubectl get svc -n transaction-platform
minikube service list -p minikube
```

#### 7. Cleanup

To remove the local deployment, run:

```bash
./scripts/local-cleanup.sh
```

To remove the deployment and stop Minikube, run:

```bash
STOP_MINIKUBE=1 ./scripts/local-cleanup.sh
```

### Local Development with Docker Compose (main branch)

Start all services:

```bash
docker compose up -d --build
```

Check container status:

```bash
docker compose ps
```

### Database and Storage

PostgreSQL is used as the persistent storage layer. In local development, persistence is provided through Docker volumes. In Kubernetes deployment, persistence is provided through a PersistentVolumeClaim mounted to the PostgreSQL data directory.

### Local Testing

Health check:

```bash
curl http://localhost:8080/health
```

Insert a transaction:

```bash
curl -X POST http://localhost:8080/transactions \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

Run validation (if needed):

```bash
curl -X POST http://localhost:8080/validation/run-once \
  -H "Content-Type: application/json" \
  -d '{"limit": 20}'
```

Query reports:

```bash
curl "http://localhost:8080/reports/daily-volume?from=2026-03-01&to=2026-03-22"
```

Generate transactions locally:

```bash
node ./scripts/transaction-generator.js --mode http --count 10 --rate 30 --url http://localhost:8080/transactions --start-date 2026-03-31T00:00:00Z --end-date 2026-04-01T23:59:59Z
```

Generate transactions to cloud:

```text
Change http://localhost:8080/transactions to http://ingestionUrl:8081/transactions
```

## Deployment Information

- **Live URL:** http://209.38.3.66/
- **Frontend URL:** http://209.38.3.66/
- **Backend URL:** Backend APIs are proxied through the frontend at http://209.38.3.66/api/

Our project supports both local deployment through Docker Compose and orchestrated deployment through Kubernetes manifests. Kubernetes resources are provided for backend services, PostgreSQL, networking, configuration, and horizontal pod auto-scaling.

## Video Demo

Add your final video URL here. The video must be accessible to the instructor and TAs.

- **Video URL:** `ADD_VIDEO_URL_HERE`

## AI Assistance & Verification (Summary)

AI tools were used as a development aid in selected parts of the project, especially for concept explanation, debugging support, and Kubernetes and Docker configuration guidance. However, all generated suggestions were reviewed critically by the team before being adopted.

One limitation we observed was that AI-generated suggestions could sometimes be structurally reasonable but not fully aligned with the current repository layout or deployment state. For example, suggestions about splitting backend services or auto-scaling assumptions required manual verification against the actual implementation and Kubernetes manifests. Additional details and concrete examples are documented in `ai-session.md`.

Correctness was verified through technical means rather than relying on AI output directly. We validated behavior by running the application locally, checking API responses, inspecting logs, confirming database inserts and updates in PostgreSQL, reviewing Docker Compose and Kubernetes resource states, and manually verifying frontend behavior in the browser.

## Individual Contributions

- **Xiangyu Liu:** Contributed to the overall system architecture design and implemented the transaction ingestion workflow, including request validation, database insertion, and the transaction generator for simulating input data.
- **Jingwei Liu:** Implemented validation and risk scoring rules, transaction state transitions, and audit updates.
- **Yilin Wang:** Contributed to the database architecture design and implemented the analytical reporting workflow, including SQL aggregation queries, core analytics APIs, and the frontend dashboard for data visualization.
- **Kun Cheng:** Implemented the Minikube and DOKS deployment scripts and built the GitHub CI/CD pipeline for automated application deployment.
- **Shared Work:** Docker Compose setup, Kubernetes manifests, debugging, testing, documentation, and final integration.

## Lessons Learned and Concluding Remarks

This project gave our team practical experience in designing a cloud-native system with multiple responsibilities separated across ingestion, validation, reporting, persistence, and presentation. We learned that even a simplified transaction platform requires careful thinking about schema validation, state management, idempotency, database indexing, and service boundaries.

We also learned the difference between stateless application services and stateful infrastructure components, especially when preparing the system for Kubernetes deployment. Auto-scaling is straightforward for stateless services, but persistent services such as PostgreSQL require different deployment strategies centered around stable storage.

Overall, the project helped us connect course concepts such as containerization, orchestration, persistence, and scalability with a realistic engineering workflow. If given more time, we would further enhance validation rules, improve automated testing, and strengthen observability and production-style deployment practices.

## Additional Deployment Artifacts

Add screenshots or links here for the following if they are part of the final submission:

- DigitalOcean Kubernetes clustering
- Deployment visualization script
- Deployment verification script
- DigitalOcean monitoring
