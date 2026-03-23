# Kubernetes Deployment Guide

This directory contains Kubernetes manifests for the transaction platform.

For a file-by-file explanation of the manifests in this directory, see [FILES.md](FILES.md).

For DigitalOcean Kubernetes deployment instructions, see [DOKS.md](DOKS.md).

## Layout

- `base/`: reusable manifests for PostgreSQL, ingestion, validation, reporting, frontend, shared config, and network policy.
- `overlays/minikube/`: local development overlay for Minikube.
- `overlays/doks/`: DigitalOcean Kubernetes overlay with cloud-specific patches.

## Current Scope

The Kubernetes deployment currently includes:

- PostgreSQL with schema initialization from `database/schema.sql`
- Ingestion service (`transaction-ingestion`)
- Validation worker service (`transaction-validation`)
- Reporting service (`transaction-reporting`)
- Frontend service (`transaction-frontend`)

This maps to five Pods in the cluster: ingestion, validation, reporting, database, and frontend.

## Prerequisites

- Minikube
- kubectl
- Docker

## Quick Start With Scripts

For a one-command local deployment flow, use the helper scripts under `scripts/`:

```bash
./scripts/local-deploy.sh
./scripts/local-verify.sh
./scripts/local-cleanup.sh
```

If you want `local-cleanup.sh` to also stop the Minikube cluster, run:

```bash
STOP_MINIKUBE=1 ./scripts/local-cleanup.sh
```

## Local Minikube Deployment

The manual deployment steps are kept below for transparency and debugging.

### 1. Start Minikube

```bash
minikube start
```

### 2. Build the application images inside the Minikube Docker daemon

```bash
eval "$(minikube docker-env)"
docker build -t transaction-reporting-service:local -f backend/Dockerfile .
docker build -t transaction-frontend:local -f frontend/Dockerfile frontend
```

### 3. Apply the Minikube overlay

```bash
kubectl apply -k k8s/overlays/minikube
```

### 4. Wait for the deployment to become ready

```bash
kubectl get pods -n transaction-platform -w
```

### 5. Access the frontend entrypoint

Use the NodePort exposed by the Minikube overlay:

```bash
minikube service transaction-frontend -n transaction-platform --url
```

Example checks:

```bash
curl -s "$(minikube service transaction-frontend -n transaction-platform --url)/health"
curl -s "$(minikube service transaction-frontend -n transaction-platform --url)/api/reports/merchant-ranking?limit=5"
```

The frontend proxies `/api/*` requests to the internal reporting service, so browsers only need the frontend endpoint.

## Useful Commands

Inspect resources:

```bash
kubectl get all -n transaction-platform
kubectl get pvc -n transaction-platform
kubectl get networkpolicy -n transaction-platform
```

Check logs:

```bash
kubectl logs deployment/transaction-ingestion -n transaction-platform
kubectl logs deployment/transaction-validation -n transaction-platform
kubectl logs deployment/transaction-reporting -n transaction-platform
kubectl logs deployment/transaction-frontend -n transaction-platform
kubectl logs deployment/transaction-postgres -n transaction-platform
```

Open a PostgreSQL shell:

```bash
kubectl exec -it deployment/transaction-postgres -n transaction-platform -- \
  psql -U transaction_user -d transaction_platform
```

## Cleanup

```bash
kubectl delete -k k8s/overlays/minikube
```

## Next Step for DigitalOcean

DigitalOcean Kubernetes deployment assets now live in `overlays/doks/`.

Use [DOKS.md](DOKS.md) for the cloud deployment flow.