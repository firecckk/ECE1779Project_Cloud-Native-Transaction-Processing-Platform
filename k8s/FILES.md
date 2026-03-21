# Kubernetes File Guide

This document briefly explains the purpose of each file under `k8s/`.

## Top Level Files

- `README.md`
  Main deployment guide for local Minikube usage. It explains prerequisites, deployment steps, validation commands, and cleanup.

- `FILES.md`
  This file. It is intended as a quick reference for what each manifest does.

## base/

The `base/` directory contains shared Kubernetes resources that describe the core application stack. These files are meant to be reusable across different environments.

- `base/kustomization.yaml`
  Entry point for the shared resource set. It lists the base manifests and generates shared ConfigMaps and Secrets used by the PostgreSQL and backend deployments.

- `base/schema.sql`
  Local copy of the database initialization schema used by Kustomize when generating the ConfigMap mounted into the PostgreSQL container. It exists inside `k8s/base` so `kubectl apply -k` works without path-restriction errors.

- `base/namespace.yaml`
  Creates the `transaction-platform` namespace so the application resources are grouped under a dedicated namespace.

- `base/postgres-pvc.yaml`
  Defines the persistent volume claim for PostgreSQL data storage so database data can survive pod restarts.

- `base/postgres-deployment.yaml`
  Runs the PostgreSQL container, injects database settings from ConfigMap and Secret, mounts persistent storage, and loads the initialization schema.

- `base/postgres-service.yaml`
  Exposes PostgreSQL internally inside the cluster with a stable service name that other pods can use.

- `base/backend-deployment.yaml`
  Runs the Node.js reporting service, injects runtime environment variables, and defines readiness and liveness probes for `/health`.

- `base/backend-service.yaml`
  Exposes the backend service inside the cluster on port `8080`.

- `base/network-policy.yaml`
  Restricts PostgreSQL ingress so only the backend pod can connect to the database over TCP port `5432`.

## overlays/minikube/

The `overlays/minikube/` directory contains environment-specific changes for local development on Minikube.

- `overlays/minikube/kustomization.yaml`
  References the shared `base/` manifests and customizes them for Minikube. It also rewrites the backend image tag to the locally built image.

- `overlays/minikube/backend-service-patch.yaml`
  Patches the backend service from `ClusterIP` to `NodePort` so it can be reached from outside the cluster during local development.

## Related Files Outside k8s/

- `database/schema.sql`
  Source schema for the project database design. Keep it aligned with `base/schema.sql` when schema changes are made.

- `backend/Dockerfile`
  Container image definition for the backend service used by the Kubernetes deployment.

- `docker-compose.yml`
  Separate local container orchestration option. It is not used by the Kubernetes manifests, but it serves a similar purpose for Docker-based local development.