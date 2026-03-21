#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
OVERLAY_PATH="${OVERLAY_PATH:-$REPO_ROOT/k8s/overlays/minikube}"
STOP_MINIKUBE="${STOP_MINIKUBE:-0}"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

echo "[local-cleanup] checking required tools"
require_command kubectl
require_command minikube

echo "[local-cleanup] deleting kubernetes resources from '$OVERLAY_PATH'"
kubectl delete -k "$OVERLAY_PATH" --ignore-not-found

if [[ "$STOP_MINIKUBE" == "1" ]]; then
  echo "[local-cleanup] stopping minikube profile '$MINIKUBE_PROFILE'"
  minikube stop -p "$MINIKUBE_PROFILE"
fi

echo "[local-cleanup] cleanup finished successfully"