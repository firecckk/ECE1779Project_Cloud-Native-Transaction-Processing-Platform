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
