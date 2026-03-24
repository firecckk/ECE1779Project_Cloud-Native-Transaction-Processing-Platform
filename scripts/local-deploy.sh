#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
NAMESPACE="${NAMESPACE:-transaction-platform}"
BACKEND_IMAGE="${BACKEND_IMAGE:-transaction-reporting-service:local}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-transaction-frontend:local}"
OVERLAY_PATH="${OVERLAY_PATH:-$REPO_ROOT/k8s/overlays/minikube}"
SKIP_MINIKUBE_START="${SKIP_MINIKUBE_START:-0}"
SKIP_LOCAL_VERIFY="${SKIP_LOCAL_VERIFY:-0}"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

echo "[local-deploy] checking required tools"
require_command docker
require_command kubectl
require_command minikube
require_command curl

if [[ "$SKIP_MINIKUBE_START" != "1" ]]; then
  echo "[local-deploy] starting minikube profile '$MINIKUBE_PROFILE'"
  minikube start -p "$MINIKUBE_PROFILE" --driver="$MINIKUBE_DRIVER"
else
  echo "[local-deploy] reusing existing minikube profile '$MINIKUBE_PROFILE'"
fi

echo "[local-deploy] building backend image '$BACKEND_IMAGE' inside minikube"
(
  cd "$REPO_ROOT"
  minikube -p "$MINIKUBE_PROFILE" image build -t "$BACKEND_IMAGE" -f backend/Dockerfile .
)

echo "[local-deploy] building frontend image '$FRONTEND_IMAGE' inside minikube"
(
  cd "$REPO_ROOT/frontend"
  minikube -p "$MINIKUBE_PROFILE" image build -t "$FRONTEND_IMAGE" -f Dockerfile .
)

echo "[local-deploy] applying kubernetes overlay '$OVERLAY_PATH'"
kubectl apply -k "$OVERLAY_PATH"

echo "[local-deploy] waiting for postgres rollout"
kubectl rollout status deployment/transaction-postgres -n "$NAMESPACE" --timeout=180s

echo "[local-deploy] waiting for application rollouts"
kubectl rollout status deployment/transaction-ingestion -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/transaction-validation -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/transaction-reporting -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/transaction-frontend -n "$NAMESPACE" --timeout=180s

if [[ "$SKIP_LOCAL_VERIFY" != "1" ]]; then
  echo "[local-deploy] running smoke tests"
  "$SCRIPT_DIR/local-verify.sh"
else
  echo "[local-deploy] skipping smoke tests"
fi

echo "[local-deploy] deployment finished successfully"