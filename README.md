# ECE1779Project_Cloud-Native-Transaction-Processing-Platform
This project aims to design and deploy a cloud-native transaction processing and risk analytics platform that simulates financial transaction workloads. While the system does not use real banking data, it models realistic transaction lifecycles including ingestion, validation, state transitions, risk scoring, and analytical reporting.

## Project Status

The current implementation includes:

- PostgreSQL database schema and initialization scripts
- Node.js backend reporting service
- Kubernetes manifests for local deployment with Minikube

The frontend is still a placeholder and is not part of the Kubernetes deployment yet.

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

## Kubernetes Manifests

The Kubernetes files are organized as follows:

- `k8s/base`: shared manifests for PostgreSQL, backend, config, and network policy
- `k8s/overlays/minikube`: local development overlay for Minikube

More deployment details are documented in [k8s/README.md](k8s/README.md).

## Cloud Deployment

Cloud deployment instructions for DigitalOcean Kubernetes (DOKS) will be added here in a later phase.
