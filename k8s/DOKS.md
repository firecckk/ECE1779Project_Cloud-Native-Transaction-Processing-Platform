# DigitalOcean Kubernetes Deployment Guide

This guide explains how to deploy the transaction platform to DigitalOcean Kubernetes (DOKS).

## Scope

The current DOKS deployment includes:

- PostgreSQL running inside the cluster with DigitalOcean block storage
- Separate ingestion, validation, and reporting Pods built from the backend image
- Frontend exposed through a public `LoadBalancer`
- Config and secrets generated from local env files
- Reporting autoscaling through an HPA

## Prerequisites

Install and configure the following tools:

- `doctl`
- `kubectl`
- `docker`

Authenticate `doctl` before deployment:

```bash
doctl auth init
```

## One-Time Setup

### 1. Create a DOKS cluster

Example command:

```bash
doctl kubernetes cluster create transaction-platform \
  --region tor1 \
  --version latest \
  --size s-2vcpu-4gb \
  --count 2
```

### 2. Create a DigitalOcean Container Registry

Example command:

```bash
doctl registry create transaction-platform
```

### 3. Prepare overlay env files

Copy the example files:

```bash
cp k8s/overlays/doks/deploy.env.example k8s/overlays/doks/deploy.env
cp k8s/overlays/doks/config.env.example k8s/overlays/doks/config.env
cp k8s/overlays/doks/secrets.env.example k8s/overlays/doks/secrets.env
```

Edit the copied files before deploying.

File purpose:

- `deploy.env`: deployment variables used by `scripts/doks-deploy.sh`
- `config.env`: non-sensitive runtime config injected into Kubernetes ConfigMap
- `secrets.env`: sensitive values injected into Kubernetes Secret

## Deployment With Script

Recommended workflow: store deployment variables in `k8s/overlays/doks/deploy.env`.

Example file:

```bash
DOKS_CLUSTER_NAME=transaction-platform
DOKR_REGISTRY_NAME=transaction-platform
IMAGE_TAG=$(git rev-parse --short HEAD)
NAMESPACE=transaction-platform
```

If you prefer, you can still override them directly in the shell:

```bash
export DOKS_CLUSTER_NAME=transaction-platform
export DOKR_REGISTRY_NAME=transaction-platform
export IMAGE_TAG=$(git rev-parse --short HEAD)
```

Run the deployment script:

```bash
./scripts/doks-deploy.sh
```

After deployment, run the smoke-test helper:

```bash
./scripts/doks-verify.sh
```

To scale the current node pool:

```bash
./scripts/doks-scale-nodes.sh 2
```

To use a different deployment env file path:

```bash
DOKS_ENV_FILE=/path/to/custom.env ./scripts/doks-deploy.sh
```

The script will:

- load deployment variables from `deploy.env` if present
- fetch cluster credentials using `doctl`
- log Docker into DigitalOcean Container Registry
- build and push the backend and frontend images
- render the DOKS overlay with your registry name and image tag
- apply Kubernetes resources
- wait for rollouts
- print the public frontend endpoint

The verification helper will:

- discover the current `LoadBalancer` endpoint from Kubernetes, or use the URL you pass explicitly
- call `/health`
- call `/api/reports/merchant-ranking?limit=5`
- fail if either response is not valid for the deployed service

The node scaling helper will:

- load `DOKS_CLUSTER_NAME` and optional `DOKS_NODE_POOL_NAME` from `deploy.env`
- auto-select the first node pool if a pool name is not provided
- submit a `doctl kubernetes cluster node-pool update --count <N>` request

## Manual Deployment

If you prefer to deploy manually, use this flow.

### 1. Save the cluster kubeconfig

```bash
doctl kubernetes cluster kubeconfig save "$DOKS_CLUSTER_NAME"
```

### 2. Log in to the registry

```bash
doctl registry login
```

### 3. Build and push the application images

```bash
docker build -t registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-reporting-service:$IMAGE_TAG -f backend/Dockerfile .
docker push registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-reporting-service:$IMAGE_TAG
docker build -t registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-frontend:$IMAGE_TAG -f frontend/Dockerfile frontend
docker push registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-frontend:$IMAGE_TAG
```

### 4. Update the DOKS overlay image reference

Update `k8s/overlays/doks/kustomization.yaml` so it points to your registry and image tag.

### 5. Apply the overlay

```bash
kubectl apply -k k8s/overlays/doks
```

### 6. Wait for rollouts

```bash
kubectl rollout status deployment/transaction-postgres -n transaction-platform
kubectl rollout status deployment/transaction-ingestion -n transaction-platform
kubectl rollout status deployment/transaction-validation -n transaction-platform
kubectl rollout status deployment/transaction-reporting -n transaction-platform
kubectl rollout status deployment/transaction-frontend -n transaction-platform
```

### 7. Get the public frontend endpoint

```bash
kubectl get svc transaction-frontend -n transaction-platform
```

## Verification

Once the `LoadBalancer` IP or hostname appears, validate the API:

```bash
curl -s http://<load-balancer-ip-or-hostname>/health
curl -s "http://<load-balancer-ip-or-hostname>/api/reports/merchant-ranking?limit=5"
```

Equivalent scripted check:

```bash
./scripts/doks-verify.sh
./scripts/doks-verify.sh http://<load-balancer-ip-or-hostname>
```

## Overlay Files

The DOKS-specific manifests live in:

- `k8s/overlays/doks/`

This overlay:

- replaces the base ConfigMap and Secret with env-file driven values
- changes the frontend service type from `ClusterIP` to `LoadBalancer`
- changes the PostgreSQL PVC to use `do-block-storage`
- sets application image pull policy to `Always`
- adds an HPA for the reporting deployment

## Cleanup

Delete the deployment:

```bash
kubectl delete -k k8s/overlays/doks
```

Delete the cluster itself:

```bash
./scripts/doks-delete.sh
```

To keep associated load balancers and volumes, disable dangerous cleanup explicitly:

```bash
DELETE_ASSOCIATED_RESOURCES=0 ./scripts/doks-delete.sh
```

The pushed image in DOKR is not deleted automatically.
