# ECE1779Project_Cloud-Native-Transaction-Processing-Platform
This project aims to design and deploy a cloud-native transaction processing and risk analytics platform that simulates financial transaction workloads. While the system does not use real banking data, it models realistic transaction lifecycles including ingestion, validation, state transitions, risk scoring, and analytical reporting.

## 🚀 Quick Start (New to the Project?)

**Start here:**  👉 [Proj_plan/manual/QUICK_START.md](Proj_plan/manual/QUICK_START.md)

This comprehensive guide includes:
- 📂 **Project structure** with file-by-file explanations
- 🔧 **Common modification points** (e.g., where to change validation rules)
- ⚡ **5-minute local setup** with Docker Compose
- 📊 **Sample API calls** for testing
- 🛠️ **Development workflows** (debugging, deploying, schema updates)
- ❓ **FAQ and troubleshooting**

## Project Status

The current implementation includes:

- PostgreSQL database schema and initialization scripts
- Node.js services for ingestion, validation, and reporting
- A lightweight frontend dashboard served by nginx
- Kubernetes manifests for a five-pod deployment with Minikube and DOKS

## Prerequisites

Install the following tools before running the project locally:

- Docker
- kubectl
- Minikube
- Git
- curl

Install `kubectl` and `minikube` using their official installation guides:

- Kubernetes CLI: https://kubernetes.io/docs/tasks/tools/
- Minikube: https://minikube.sigs.k8s.io/docs/start/

For Ubuntu-specific package installation and the full local setup flow, see [k8s/README.md](k8s/README.md).

## Local Deployment With Minikube

Detailed local deployment instructions are documented in [k8s/README.md](k8s/README.md).

## Useful Local Commands

Common inspection and cleanup commands are documented in [k8s/README.md](k8s/README.md).

## Transaction Generator

Use [scripts/README.md](scripts/README.md) for the local transaction generator that can emit sample payloads or send them to the ingestion API.

## Kubernetes Manifests

The Kubernetes files are organized as follows:

- `k8s/base`: shared manifests for PostgreSQL, ingestion, validation, reporting, frontend, config, and network policy
- `k8s/overlays/minikube`: local development overlay for Minikube
- `k8s/overlays/doks`: DigitalOcean Kubernetes overlay

More deployment details are documented in [k8s/README.md](k8s/README.md).

## Cloud Deployment

Cloud deployment instructions for DigitalOcean Kubernetes (DOKS) are documented in [k8s/DOKS.md](k8s/DOKS.md).

## GitHub CI/CD

The repository now includes GitHub Actions workflows under `.github/workflows/`:

- `ci.yml`: runs on pushes, pull requests, and manual dispatch. It installs backend dependencies, renders the Kubernetes overlays with `kubectl kustomize`, starts a temporary Minikube cluster, deploys the application with the existing `scripts/local-deploy.sh`, and verifies the frontend and reporting API with `scripts/local-verify.sh`.
- `deploy-doks.yml`: deploys to DigitalOcean Kubernetes after the `CI` workflow succeeds on `main`, or by manual dispatch.

### Required GitHub configuration

Add these repository or environment secrets before enabling DOKS deployment:

- `DIGITALOCEAN_ACCESS_TOKEN`: DigitalOcean API token used by `doctl`.
- `DOKS_CONFIG_ENV`: multiline content for `k8s/overlays/doks/config.env`.
- `DOKS_SECRETS_ENV`: multiline content for `k8s/overlays/doks/secrets.env`.

Add these repository or environment variables:

- `DOKS_CLUSTER_NAME`: target DOKS cluster name.
- `DOKR_REGISTRY_NAME`: DigitalOcean Container Registry name.
- `K8S_NAMESPACE`: optional override for the Kubernetes namespace. If omitted, the workflow uses `transaction-platform`.

Recommended rollout on GitHub:

1. Protect the `main` branch so deployment only happens after pull requests pass `CI`.
2. Use a GitHub Environment such as `production` and attach approval rules if you want a manual gate before `deploy-doks.yml` runs.
3. Store `DOKS_CONFIG_ENV` and `DOKS_SECRETS_ENV` as multiline secrets copied from the DOKS overlay examples, with production values substituted.

The deployment workflow tags images with the triggering commit SHA by default, which makes rollbacks and deployment traceability simpler.

Recommended split of responsibilities:

- CI: use Minikube as an ephemeral Kubernetes environment on the GitHub runner to validate the manifests, images, and smoke tests.
- CD: use DOKS as the real deployment target for persistent environments.

If you want to deploy to Minikube from GitHub Actions, use a self-hosted runner attached to the machine that actually runs the Minikube cluster. GitHub-hosted runners are ephemeral, so a Minikube deployment there only makes sense for CI validation, not as a persistent release environment.
