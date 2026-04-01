#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_DIR="$REPO_ROOT/k8s/overlays/doks"
TEMP_WORKDIR="$(mktemp -d)"
TEMP_K8S_ROOT="$TEMP_WORKDIR/k8s"
TEMP_OVERLAY_DIR="$TEMP_K8S_ROOT/overlays/doks"
DEPLOY_ENV_FILE="${DOKS_ENV_FILE:-$OVERLAY_DIR/deploy.env}"

NAMESPACE="${NAMESPACE:-transaction-platform}"
DOKS_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-}"
DOKR_REGISTRY_NAME="${DOKR_REGISTRY_NAME:-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCR_REPOSITORY_NAME="${DOCR_REPOSITORY_NAME:-transaction-platform}"

cleanup() {
  rm -rf "$TEMP_WORKDIR"
}

trap cleanup EXIT

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

require_env() {
  local env_name="$1"

  if [[ -z "${!env_name:-}" ]]; then
    echo "Missing required environment variable: $env_name" >&2
    exit 1
  fi
}

ensure_namespace() {
  echo "[doks-deploy] ensuring namespace '$NAMESPACE' exists"
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

wait_for_default_service_account() {
  local attempt=1

  while (( attempt <= 30 )); do
    if kubectl get serviceaccount default -n "$NAMESPACE" >/dev/null 2>&1; then
      return 0
    fi

    sleep 2
    ((attempt++))
  done

  echo "Timed out waiting for default service account in namespace '$NAMESPACE'" >&2
  return 1
}

ensure_registry_pull_secret() {
  local secret_name="registry-$DOKR_REGISTRY_NAME"

  wait_for_default_service_account

  echo "[doks-deploy] syncing registry pull secret '$secret_name' into namespace '$NAMESPACE'"
  doctl registry kubernetes-manifest "$DOKR_REGISTRY_NAME" \
    | sed "s/namespace: kube-system/namespace: $NAMESPACE/" \
    | kubectl apply -f -

  echo "[doks-deploy] attaching registry pull secret to default service account"
  kubectl patch serviceaccount default -n "$NAMESPACE" --type merge -p \
    "{\"imagePullSecrets\":[{\"name\":\"$secret_name\"}]}"
}

load_env_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  echo "[doks-deploy] loading deployment variables from '$file_path'"
  set -a
  # shellcheck disable=SC1090
  source "$file_path"
  set +a

  NAMESPACE="${NAMESPACE:-transaction-platform}"
  DOKS_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-}"
  DOKR_REGISTRY_NAME="${DOKR_REGISTRY_NAME:-}"
  IMAGE_TAG="${IMAGE_TAG:-latest}"
  DOCR_REPOSITORY_NAME="${DOCR_REPOSITORY_NAME:-transaction-platform}"
}

wait_for_load_balancer() {
  local endpoint=""
  local attempt=1

  while (( attempt <= 30 )); do
    endpoint="$(kubectl get svc transaction-frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

    if [[ -z "$endpoint" ]]; then
      endpoint="$(kubectl get svc transaction-frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    fi

    if [[ -n "$endpoint" ]]; then
      printf '%s\n' "$endpoint"
      return 0
    fi

    sleep 10
    ((attempt++))
  done

  echo "Timed out waiting for a LoadBalancer endpoint" >&2
  return 1
}

echo "[doks-deploy] checking required tools"
require_command doctl
require_command docker
require_command kubectl
require_command curl

load_env_file "$DEPLOY_ENV_FILE"

require_env DOKS_CLUSTER_NAME
require_env DOKR_REGISTRY_NAME

if [[ ! -f "$OVERLAY_DIR/config.env" ]]; then
  echo "Missing required file: $OVERLAY_DIR/config.env" >&2
  echo "Create it from $OVERLAY_DIR/config.env.example before running this script." >&2
  exit 1
fi

if [[ ! -f "$OVERLAY_DIR/secrets.env" ]]; then
  echo "Missing required file: $OVERLAY_DIR/secrets.env" >&2
  echo "Create it from $OVERLAY_DIR/secrets.env.example before running this script." >&2
  exit 1
fi

echo "[doks-deploy] saving kubeconfig for cluster '$DOKS_CLUSTER_NAME'"
if ! doctl kubernetes cluster kubeconfig save "$DOKS_CLUSTER_NAME"; then
  echo "[doks-deploy] cluster '$DOKS_CLUSTER_NAME' was not found" >&2
  echo "[doks-deploy] create it with ./scripts/doks-bootstrap.sh or update DOKS_CLUSTER_NAME to an existing cluster" >&2
  exit 1
fi

ensure_namespace

echo "[doks-deploy] logging into DigitalOcean Container Registry"
doctl registry login --expiry-seconds 1200

ensure_registry_pull_secret

BACKEND_IMAGE_TAG="backend-$IMAGE_TAG"
FRONTEND_IMAGE_TAG="frontend-$IMAGE_TAG"
BACKEND_IMAGE="registry.digitalocean.com/$DOKR_REGISTRY_NAME/$DOCR_REPOSITORY_NAME:$BACKEND_IMAGE_TAG"
FRONTEND_IMAGE="registry.digitalocean.com/$DOKR_REGISTRY_NAME/$DOCR_REPOSITORY_NAME:$FRONTEND_IMAGE_TAG"

echo "[doks-deploy] building backend image '$BACKEND_IMAGE'"
docker build -t "$BACKEND_IMAGE" -f "$REPO_ROOT/backend/Dockerfile" "$REPO_ROOT"

echo "[doks-deploy] pushing backend image '$BACKEND_IMAGE'"
docker push "$BACKEND_IMAGE"

echo "[doks-deploy] building frontend image '$FRONTEND_IMAGE'"
docker build -t "$FRONTEND_IMAGE" -f "$REPO_ROOT/frontend/Dockerfile" "$REPO_ROOT/frontend"

echo "[doks-deploy] pushing frontend image '$FRONTEND_IMAGE'"
docker push "$FRONTEND_IMAGE"

echo "[doks-deploy] preparing temporary DOKS overlay"
mkdir -p "$TEMP_K8S_ROOT/overlays"
cp -R "$REPO_ROOT/k8s/base" "$TEMP_K8S_ROOT/base"
cp -R "$OVERLAY_DIR" "$TEMP_OVERLAY_DIR"
sed -i "s|registry.digitalocean.com/REPLACE_WITH_DOKR_REGISTRY/transaction-reporting-service|registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-reporting-service|" "$TEMP_OVERLAY_DIR/kustomization.yaml"
sed -i "s|registry.digitalocean.com/REPLACE_WITH_DOKR_REGISTRY/transaction-frontend|registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-frontend|" "$TEMP_OVERLAY_DIR/kustomization.yaml"
sed -i "s|registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-reporting-service|registry.digitalocean.com/$DOKR_REGISTRY_NAME/$DOCR_REPOSITORY_NAME|" "$TEMP_OVERLAY_DIR/kustomization.yaml"
sed -i "s|registry.digitalocean.com/$DOKR_REGISTRY_NAME/transaction-frontend|registry.digitalocean.com/$DOKR_REGISTRY_NAME/$DOCR_REPOSITORY_NAME|" "$TEMP_OVERLAY_DIR/kustomization.yaml"

echo "[doks-deploy] applying kubernetes overlay"
kubectl apply -k "$TEMP_OVERLAY_DIR"

echo "[doks-deploy] setting deployment images explicitly"
kubectl set image deployment/transaction-ingestion -n "$NAMESPACE" ingestion="$BACKEND_IMAGE"
kubectl set image deployment/transaction-validation -n "$NAMESPACE" validation="$BACKEND_IMAGE"
kubectl set image deployment/transaction-reporting -n "$NAMESPACE" reporting="$BACKEND_IMAGE"
kubectl set image deployment/transaction-frontend -n "$NAMESPACE" frontend="$FRONTEND_IMAGE"

echo "[doks-deploy] waiting for postgres rollout"
kubectl rollout status deployment/transaction-postgres -n "$NAMESPACE" --timeout=300s

echo "[doks-deploy] waiting for application rollouts"
kubectl rollout status deployment/transaction-ingestion -n "$NAMESPACE" --timeout=300s
kubectl rollout status deployment/transaction-validation -n "$NAMESPACE" --timeout=300s
kubectl rollout status deployment/transaction-reporting -n "$NAMESPACE" --timeout=300s
kubectl rollout status deployment/transaction-frontend -n "$NAMESPACE" --timeout=300s

echo "[doks-deploy] waiting for load balancer endpoint"
LOAD_BALANCER_ENDPOINT="$(wait_for_load_balancer)"

echo "[doks-deploy] frontend endpoint: http://$LOAD_BALANCER_ENDPOINT"
echo "[doks-deploy] health check: http://$LOAD_BALANCER_ENDPOINT/health"