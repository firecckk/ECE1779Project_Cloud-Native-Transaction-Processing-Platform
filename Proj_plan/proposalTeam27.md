# Cloud-Native Transaction Processing and Risk Analytics Platform

## 1. Motivation

Modern financial systems must process high volumes of transactions reliably, securely, and with real-time visibility. Even simplified transaction systems require ingestion, validation, state management, reporting, monitoring, and scalability — all of which are central topics in cloud computing.

This project aims to design and deploy a cloud-native transaction processing and risk analytics platform that simulates financial transaction workloads. While the system does not use real banking data, it models realistic transaction lifecycles including ingestion, validation, state transitions, risk scoring, and analytical reporting.

The project is worth pursuing because:

- Financial institutions require reliable, scalable transaction processing systems that can handle high-volume workloads without data loss.
- Real-time risk detection and fraud prevention are critical requirements in modern payment processing infrastructure.
- A modular, cloud-native architecture enables rapid adaptation to changing compliance requirements and business rules.
- The system provides a reusable foundation for building production-grade financial backends with built-in monitoring and observability.

### Target Users

- Developers interested in financial transaction processing workflows
- Banking backend teams evaluating scalable transaction workflows
- Data analysts.

### Existing Solutions

Generic event logging systems collect and store events but typically lack domain-specific transaction logic such as validation rules, lifecycle state transitions, and risk scoring mechanisms. Our project extends beyond generic event logging by implementing financial-style transaction validation and analytics.

---

## 2. Objectives and Key Features

### Project Objective

To build and deploy a scalable, containerized, cloud-native transaction processing platform that:

- Accepts transaction ingestion via REST API
- Validates and risk-scores transactions
- Persists state using PostgreSQL with persistent storage
- Provides analytical reporting endpoints
- Demonstrates orchestration, monitoring, and auto-scaling
- Implements at least two advanced cloud features (HPA and CI/CD pipeline).

---

## System Architecture

### Orchestration Approach: Kubernetes

We will use:

- **Minikube** for local Kubernetes development
- **DigitalOcean Kubernetes (DOKS)** for production deployment

Kubernetes enables:

- Deployments for stateless services
- Services for internal networking
- PersistentVolumeClaims for PostgreSQL
- Horizontal Pod Autoscaler (HPA)

---

### Containerized Components

The system consists of the following containers:

### 1. Ingestion Service
- Endpoint: `POST /transactions`
- Performs schema validation
- Inserts transactions into PostgreSQL
- Sets initial status to `RECEIVED`

//userID, money, ->SQL

### 2. Validation & Risk Service
- Polls for `RECEIVED` transactions
- Applies rule-based validation:
  - High-value transaction detection
  - Duplicate transaction detection
  - Frequency-based anomaly detection
- Computes a `risk_score`
- Updates transaction status to:
  - `VALID`
  - `REJECTED`

  //SQL-> check & varify/ do something

### 3. Reporting Service
- Provides analytical endpoints:
  - Daily transaction volume
  - Merchant ranking
  - Risk distribution
- Executes aggregation-heavy SQL queries
- Optimized for read-heavy workloads

//report: 交易量，数据可视化

### 4. PostgreSQL Database (Stateful)
- Stores transaction records
- Backed by Kubernetes PersistentVolumeClaim
- Ensures persistence across pod restarts




---

### Database Schema (Simplified)

**transactions table**

- id (UUID)
- timestamp
- sender_account
- receiver_account
- merchant_id
- amount
- currency
- transaction_type
- status (RECEIVED / VALID / REJECTED)
- risk_score
- reject_reason
- created_at
- validated_at

---

### Deployment Provider: DigitalOcean

We will deploy to:

- DigitalOcean Kubernetes (DOKS)
- DigitalOcean persistent volumes
- DigitalOcean monitoring dashboards

DigitalOcean was selected due to simplicity, Kubernetes compatibility, and integrated monitoring features.

---

## Monitoring and Observability

We will monitor:

- CPU usage per pod
- Memory usage per pod
- Pod restart counts
- Application logs
- Transaction ingestion throughput

Alerts will be configured for:

- High CPU utilization
- Unexpected pod restarts
- High ingestion spikes

---

## Advanced Features

We will implement at least two advanced features:

### 1. Horizontal Pod Autoscaling (HPA)

- Auto-scale ingestion service based on CPU usage
- Demonstrate scaling behavior under synthetic load

### 2. CI/CD Pipeline (GitHub Actions)

- Automated Docker image builds
- Registry push
- Deployment to Kubernetes cluster

### Optional Enhancement (if time permits)

- Real-time metrics dashboard using WebSockets
- Automated PostgreSQL backup to object storage

---

## Scope and Feasibility

This project scope is carefully designed for our 4-member team. The architecture has three stateless services and one stateful database, giving each team member a clear component to develop independently. We avoid complex features like distributed consensus and machine learning, focusing instead on core transaction processing and cloud deployment. The validation rules are realistic but simple enough to implement quickly. Our modular design allows parallel development, and the REST and database interfaces are straightforward to integrate. With sufficient time allocated for local testing and cloud deployment, this project complexity matches our team capacity and timeline.

---

## 3. Tentative Plan

### Week 1
- Finalize architecture
- Define database schema
- Implement ingestion service
- Local Docker Compose environment

### Week 2
- Implement validation & risk service
- Implement reporting service
- Integration testing

### Week 3
- Set up Minikube
- Convert to Kubernetes Deployments
- Configure PersistentVolumeClaims
- Deploy to DigitalOcean Kubernetes
- Configure monitoring and alerts

### Week 4
- Implement Horizontal Pod Autoscaler
- Develop transaction load generator
- Implement CI/CD pipeline
- Final testing and documentation
- Demo preparation

---

## Team Responsibilities (4 Members)

To ensure balanced workload distribution:

### Yilin Wang – Ingestion & API Layer
- Design and implement ingestion service
- Define API schema
- Implement request validation
- Assist in HPA testing

### Xiangyu Liu – Validation & Risk Engine
- Implement rule-based validation logic
- Handle concurrency and transaction locking
- Design risk scoring mechanism
- Optimize update performance

### Jingwei Liu – Reporting & Database Optimization
- Design database schema
- Create indexes
- Implement aggregation queries
- Optimize reporting performance

### Kun Cheng – Infrastructure & DevOps
- Kubernetes configuration
- PersistentVolume setup
- Monitoring and alert configuration
- CI/CD pipeline implementation
- Cloud deployment coordination

All members will collaborate on integration testing and debugging.

---

## 4. Initial Independent Reasoning (Before Using AI)

### Architecture Choices

Before consulting AI tools, our team independently chose:

- DigitalOcean as deployment provider
- Kubernetes instead of Docker Swarm
- PostgreSQL with PersistentVolumeClaims

We selected Kubernetes because it better demonstrates orchestration and scaling concepts covered in the course. PostgreSQL was chosen for relational consistency and aggregation support.

---

### Anticipated Challenges

We anticipated the following challenges:

- Configuring PersistentVolumeClaims correctly
- Implementing Horizontal Pod Autoscaling
- Handling concurrent processing in the validation service
- Debugging Kubernetes networking and deployment issues

We expected infrastructure configuration to be more complex than application-level coding.

---

### Early Development Approach

Our initial strategy was:

1. Develop and test services locally using Docker Compose.
2. Validate inter-service communication.
3. Migrate to Kubernetes after core functionality is stable.
4. Implement advanced features incrementally.

Responsibilities were divided by service boundaries to allow parallel progress.

---

## 5. AI Assistance Disclosure

The following components were developed independently:

- Core idea of a transaction processing system
- Selection of Kubernetes and DigitalOcean
- Service decomposition

AI tools were used to:

- Improve structure and clarity of the proposal
- Refine technical wording

One AI-influenced suggestion was adding a synthetic transaction generator to demonstrate auto-scaling behavior. The team discussed scope trade-offs and agreed to limit its complexity to maintain feasibility.

---
