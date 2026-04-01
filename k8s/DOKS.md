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

Recommended path: use the bootstrap helper under `scripts/` to create the infrastructure and generate a consistent local deployment configuration.

```bash
./scripts/doks-bootstrap.sh
```

If you also want to sync the required GitHub Actions repository variables and secrets automatically, run:

```bash
SYNC_GITHUB_CD=1 \
GITHUB_REPOSITORY=<owner>/<repo> \
DIGITALOCEAN_ACCESS_TOKEN=<your-do-token> \
./scripts/doks-bootstrap.sh
```

The bootstrap script will:

- create a DOKS cluster if it does not already exist
- create a DigitalOcean Container Registry if it does not already exist
- write `k8s/overlays/doks/deploy.env` with canonical values
- create `config.env` and `secrets.env` from examples if missing
- save kubeconfig for the cluster
- optionally sync the GitHub CD secrets and variables

You can still do the setup manually if you prefer.

### 1. Create a DOKS cluster

Example command:

```bash
doctl kubernetes cluster create transaction-platform \
  --region tor1 \
  --version latest \
  --node-pool "name=transaction-platform-default-pool;size=s-1vcpu-2gb;count=1;auto-scale=true;min-nodes=1;max-nodes=3"
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
DOKS_REGION=tor1
DOKS_NODE_SIZE=s-1vcpu-2gb
DOKS_NODE_COUNT=1
DOKS_NODE_POOL_NAME=transaction-platform-default-pool
DOKS_AUTO_SCALE=true
DOKS_MIN_NODES=1
DOKS_MAX_NODES=3
DOKS_K8S_VERSION=latest
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
- install a registry pull secret in the target namespace so Pods can pull private DOCR images
- build and push the backend and frontend images
- publish both images into a single DOCR repository using different tags so the workflow works with registries limited to one repository
- render the DOKS overlay with your registry name and image tag
- apply Kubernetes resources
- wait for rollouts
- print the public frontend endpoint

For GitHub Actions CD, configure these repository or environment secrets:

- `DIGITALOCEAN_ACCESS_TOKEN`
- `DOKS_CONFIG_ENV`
- `DOKS_SECRETS_ENV`

Configure these repository or environment variables:

- `DOKS_CLUSTER_NAME`
- `DOKR_REGISTRY_NAME`
- `K8S_NAMESPACE`

The verification helper will:

- discover the current `LoadBalancer` endpoint from Kubernetes, or use the URL you pass explicitly
- call `/health`
- call `/api/reports/merchant-ranking?limit=5`
- fail if either response is not valid for the deployed service

To expose ingestion publicly as a separate endpoint on DOKS, add a `LoadBalancer` patch for the `transaction-ingestion` Service in the DOKS overlay. After redeploying, retrieve the endpoint with:

```bash
kubectl get svc transaction-ingestion -n transaction-platform
```

Once an external IP or hostname is assigned, ingest transactions directly with:

```bash
node scripts/transaction-generator.js --mode http --count 100 --rate 20 --url http://<ingestion-load-balancer>:8081/transactions
```

Or validate the ingestion endpoint with a single request:

```bash
curl -X POST http://<ingestion-load-balancer>:8081/transactions \
  -H "content-type: application/json" \
  -d '{
    "transaction_id":"11111111-1111-4111-8111-111111111111",
    "idempotency_key":"test-key-1",
    "event_timestamp":"2026-03-31T23:59:59Z",
    "sender_account":"acct_1001",
    "receiver_account":"acct_2002",
    "merchant_id":"merchant_01",
    "amount":123.45,
    "currency":"USD",
    "transaction_type":"PAYMENT",
    "channel":"API",
    "metadata":{}
  }'
```

This endpoint is unauthenticated by default, so treat it as a temporary demo or test ingress unless you also add access controls.

The node scaling helper will:

- load `DOKS_CLUSTER_NAME` and optional `DOKS_NODE_POOL_NAME` from `deploy.env`
- auto-select the first node pool if a pool name is not provided
- submit a `doctl kubernetes cluster node-pool update --count <N>` request

Default DOKS node-pool sizing in this repository is now:

- initial node count: `1`
- autoscaling enabled: `true`
- minimum nodes: `1`
- maximum nodes: `3`

This keeps the base cloud cost lower while still allowing the cluster to scale up under load.

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
docker build -t registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-platform:backend-$IMAGE_TAG -f backend/Dockerfile .
docker push registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-platform:backend-$IMAGE_TAG
docker build -t registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-platform:frontend-$IMAGE_TAG -f frontend/Dockerfile frontend
docker push registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-platform:frontend-$IMAGE_TAG
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
