#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
NAMESPACE="${NAMESPACE:-transaction-platform}"
BACKEND_IMAGE="${BACKEND_IMAGE:-transaction-reporting-service:local}"
OVERLAY_PATH="${OVERLAY_PATH:-$REPO_ROOT/k8s/overlays/minikube}"

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

echo "[local-deploy] starting minikube profile '$MINIKUBE_PROFILE'"
minikube start -p "$MINIKUBE_PROFILE" --driver="$MINIKUBE_DRIVER"

echo "[local-deploy] building backend image '$BACKEND_IMAGE' inside minikube docker daemon"
eval "$(minikube -p "$MINIKUBE_PROFILE" docker-env --shell bash)"
docker build -t "$BACKEND_IMAGE" "$REPO_ROOT/backend"

echo "[local-deploy] applying kubernetes overlay '$OVERLAY_PATH'"
kubectl apply -k "$OVERLAY_PATH"

echo "[local-deploy] waiting for postgres rollout"
kubectl rollout status deployment/transaction-postgres -n "$NAMESPACE" --timeout=180s

echo "[local-deploy] waiting for backend rollout"
kubectl rollout status deployment/transaction-backend -n "$NAMESPACE" --timeout=180s

echo "[local-deploy] running smoke tests"
"$SCRIPT_DIR/local-verify.sh"

echo "[local-deploy] deployment finished successfully"