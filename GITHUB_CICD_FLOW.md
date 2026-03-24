# GitHub CI/CD Flow

This document summarizes the GitHub-based CI/CD pipeline for the cloud-native transaction platform. It is written as a presentation-friendly reference that can be reused in demos, reports, and slides.

## Goal

The CI/CD design solves two different problems:

- Continuous Integration: validate every code change in a temporary Kubernetes environment before merging.
- Continuous Deployment: deploy approved code to a persistent cloud Kubernetes cluster.

The project uses two different Kubernetes targets on purpose:

- Minikube for CI validation on GitHub Actions runners.
- DigitalOcean Kubernetes (DOKS) for real deployment.

## Why This Design

This split keeps the pipeline both fast and realistic:

- Minikube gives us a disposable Kubernetes cluster for automated testing.
- DOKS provides a production-like managed cluster for deployment.
- The same Kubernetes manifests under `k8s/` are reused across local development, CI validation, and cloud deployment.

This means the team is not validating one environment and deploying to a completely different stack.

## High-Level Pipeline

```text
Developer push / pull request
        |
        v
GitHub Actions CI
  - install dependencies
  - start Minikube
  - configure kubectl context
  - validate Kubernetes manifests
  - build backend/frontend images inside Minikube
  - deploy with Minikube overlay
  - run smoke tests
        |
        v
Merge to main
        |
        v
GitHub Actions CD
  - prepare DOKS secrets/config
  - build tagged images
  - push images to DigitalOcean Container Registry
  - apply DOKS overlay
  - verify deployment
        |
        v
Live application on DOKS
```

## CI Workflow

The CI workflow lives in `.github/workflows/ci.yml`.

### Trigger conditions

CI runs on:

- push events affecting application, Kubernetes, script, or workflow files
- pull requests affecting the same areas
- manual workflow dispatch

### CI execution steps

1. Check out the repository.
2. Install backend dependencies.
3. Run a lightweight module-load check for the backend application.
4. Install `kubectl`.
5. Start a temporary Minikube cluster in the GitHub runner.
6. Configure `kubectl` so it explicitly targets the Minikube cluster.
7. Render the Minikube and DOKS Kubernetes overlays with `kubectl kustomize`.
8. Build the backend image inside Minikube.
9. Build the frontend image inside Minikube.
10. Deploy the platform using the Minikube overlay.
11. Wait for PostgreSQL, ingestion, validation, reporting, and frontend rollouts.
12. Run smoke tests against the frontend endpoint and reporting API.
13. Collect Kubernetes diagnostics if any step fails.
14. Clean up the temporary Minikube environment.

### Why Minikube is used in CI

GitHub-hosted runners are ephemeral machines. That makes them a good fit for temporary integration environments:

- the cluster starts fresh for each run
- no state is shared across builds
- failures are easier to reproduce from the workflow logs

Minikube is used here as a test environment, not as a long-lived deployment environment.

## CD Workflow

The CD workflow lives in `.github/workflows/deploy-doks.yml`.

### Trigger conditions

CD runs when:

- the `CI` workflow succeeds for `main`
- a maintainer manually triggers deployment

### CD execution steps

1. Check out the commit that passed CI.
2. Derive the image tag from the triggering commit SHA, unless a manual tag is provided.
3. Install `doctl` for DigitalOcean access.
4. Install `kubectl`.
5. Materialize `config.env` and `secrets.env` for the DOKS overlay from GitHub Secrets.
6. Build backend and frontend images.
7. Push both images to DigitalOcean Container Registry.
8. Apply the DOKS Kubernetes overlay.
9. Wait for all required deployments to roll out.
10. Verify the public frontend and reporting endpoint with a smoke test.

## Kubernetes Resource Path

The repository uses a base-and-overlay structure:

- `k8s/base`: shared manifests for database, services, deployments, and network policy
- `k8s/overlays/minikube`: local and CI overlay
- `k8s/overlays/doks`: cloud deployment overlay

This structure gives the project one reusable Kubernetes definition with small environment-specific customizations.

## Supporting Scripts

The workflows intentionally reuse the same scripts used by local development:

- `scripts/local-deploy.sh`: builds images in Minikube, deploys the Minikube overlay, and optionally runs smoke tests
- `scripts/local-verify.sh`: verifies the frontend and reporting API in Minikube
- `scripts/local-cleanup.sh`: removes local Kubernetes resources
- `scripts/doks-deploy.sh`: builds, pushes, and deploys to DOKS
- `scripts/doks-verify.sh`: verifies the DOKS deployment

This is important because it reduces drift between local workflows and GitHub automation.

## Required GitHub Configuration

### Repository or environment secrets

- `DIGITALOCEAN_ACCESS_TOKEN`
- `DOKS_CONFIG_ENV`
- `DOKS_SECRETS_ENV`

### Repository or environment variables

- `DOKS_CLUSTER_NAME`
- `DOKR_REGISTRY_NAME`
- `K8S_NAMESPACE` (optional)

## What CI Validates

The CI pipeline validates more than syntax:

- Node.js application modules load successfully
- Kubernetes manifests render correctly
- Minikube cluster is reachable through `kubectl`
- Docker images build successfully inside the cluster environment
- all five platform components roll out successfully
- the frontend health endpoint responds correctly
- the reporting API responds correctly

This makes CI a real integration test, not only a lint or YAML check.

## What CD Delivers

The CD pipeline produces a traceable cloud deployment:

- images are tagged by commit SHA
- deployments are tied to a passing CI run
- environment-specific configuration is injected from GitHub secrets
- the cloud deployment is verified after rollout

This gives the team deployment traceability and a cleaner rollback story.

## Suggested Presentation Summary

For a presentation, the deployment story can be summarized in four sentences:

1. Every pull request is validated in a temporary Minikube Kubernetes cluster on GitHub Actions.
2. The pipeline builds the same backend and frontend images used by the platform and deploys them with the Minikube overlay.
3. After CI passes and code reaches `main`, GitHub Actions deploys the same application to DigitalOcean Kubernetes.
4. The deployment is verified automatically, which gives the team a complete CI/CD path from code commit to cloud release.

## Suggested Slide Bullets

If you want concise PPT bullets, these usually work well:

- GitHub Actions orchestrates both CI and CD.
- CI uses Minikube as an ephemeral Kubernetes test environment.
- CD uses DOKS as the persistent managed Kubernetes environment.
- Shared Kubernetes manifests reduce environment drift.
- Smoke tests verify both service health and reporting API behavior.
- Commit-SHA image tags improve deployment traceability.

## Demo Talking Points

If you are presenting the workflow live, emphasize these points:

- We moved away from the old `docker-compose` path and standardized on Kubernetes.
- CI now validates the real deployment model instead of a separate local-only stack.
- Local development, CI validation, and cloud deployment all share the same Kubernetes resource structure.
- The final pipeline is practical because it was verified locally and then adapted to GitHub Actions.