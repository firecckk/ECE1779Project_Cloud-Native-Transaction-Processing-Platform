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
  Entry point for the shared resource set. It lists the base manifests and generates shared ConfigMaps and Secrets used by the PostgreSQL and application deployments.

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

- `base/ingestion-deployment.yaml`
  Runs the ingestion Node.js service and exposes `/transactions` plus `/health`.

- `base/ingestion-service.yaml`
  Exposes the ingestion service inside the cluster on port `8080`.

- `base/validation-deployment.yaml`
  Runs the validation worker process and validation endpoints in a dedicated Pod.

- `base/validation-service.yaml`
  Exposes the validation service internally on port `8080`.

- `base/reporting-deployment.yaml`
  Runs the reporting Node.js service and exposes `/reports` plus `/health`.

- `base/reporting-service.yaml`
  Exposes the reporting service inside the cluster on port `8080`.

- `base/frontend-deployment.yaml`
  Runs the nginx-based frontend and proxies `/api/*` traffic to the reporting service.

- `base/frontend-service.yaml`
  Exposes the frontend service inside the cluster on port `3000`.

- `base/network-policy.yaml`
  Restricts PostgreSQL ingress so only the ingestion, validation, and reporting Pods can connect to the database over TCP port `5432`.

## overlays/minikube/

The `overlays/minikube/` directory contains environment-specific changes for local development on Minikube.

- `overlays/minikube/kustomization.yaml`
  References the shared `base/` manifests and customizes them for Minikube. It also rewrites the backend and frontend image tags to locally built images.

- `overlays/minikube/frontend-service-patch.yaml`
  Patches the frontend service from `ClusterIP` to `NodePort` so it can be reached from outside the cluster during local development.

## overlays/doks/

The `overlays/doks/` directory contains DigitalOcean Kubernetes specific configuration.

- `overlays/doks/kustomization.yaml`
  Entry point for the DOKS overlay. It replaces local config and secret generation with env-file based values, points the backend and frontend images to DigitalOcean Container Registry, and applies cloud-specific patches.

- `overlays/doks/frontend-service-patch.yaml`
  Changes the frontend service to `LoadBalancer` so DigitalOcean can provision a public load balancer.

- `overlays/doks/postgres-pvc-patch.yaml`
  Changes the PostgreSQL persistent volume to use the `do-block-storage` storage class and a larger disk size for cloud usage.

- `overlays/doks/reporting-deployment-patch.yaml`
  Adjusts the reporting deployment for cloud usage by increasing replicas, setting `imagePullPolicy: Always`, and tuning resource requests and limits.

- `overlays/doks/ingestion-deployment-patch.yaml`
  Sets the ingestion deployment image pull policy to `Always` for cloud rollout consistency.

- `overlays/doks/validation-deployment-patch.yaml`
  Sets the validation deployment image pull policy to `Always` for cloud rollout consistency.

- `overlays/doks/frontend-deployment-patch.yaml`
  Sets the frontend deployment image pull policy to `Always` for cloud rollout consistency.

- `overlays/doks/hpa.yaml`
  Adds a HorizontalPodAutoscaler for the reporting deployment.

- `overlays/doks/config.env.example`
  Example non-sensitive configuration file. Copy it to `config.env` before deploying to DOKS.

- `overlays/doks/secrets.env.example`
  Example secrets file. Copy it to `secrets.env`, replace the placeholder values, and keep the real file out of git.

- `overlays/doks/deploy.env.example`
  Example deployment variable file for `scripts/doks-deploy.sh`. Copy it to `deploy.env` to avoid manually exporting the cluster name, registry name, image tag, and namespace on every deploy.

## Related Files Outside k8s/

- `database/schema.sql`
  Source schema for the project database design. Keep it aligned with `base/schema.sql` when schema changes are made.

- `backend/Dockerfile`
  Container image definition shared by the ingestion, validation, and reporting services.
  Build it from repository root context so shared code under `shared/` is included.

- `frontend/Dockerfile`
  Container image definition for the nginx-based frontend used by the Kubernetes deployment.

- `docker-compose.yml`
  Separate local container orchestration option. It is not used by the Kubernetes manifests, but it serves a similar purpose for Docker-based local development.

- `scripts/doks-deploy.sh`
  Helper script that can load deployment variables from `deploy.env`, logs in to DOKS and DOKR, builds and pushes the backend and frontend images, and applies the DOKS overlay.